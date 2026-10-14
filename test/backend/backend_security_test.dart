// The backend's rules, held where they are kept: on a real PostgreSQL with
// the migration applied, called as an owner, a labour account, somebody of
// another factory and nobody — the way Supabase's API calls it, as the
// `authenticated` or `anon` role with the signed session's subject. Every
// refusal here is the database's, not the application's.
//
// The services Supabase runs in front of the database (Auth and the REST
// API) are not part of this: sign-up is the Auth service's insert into
// `auth.users`, done here as it does it, and the API is the role and the
// session it sets.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'local_postgres.dart';

late LocalPostgres pg;
late String db;

String q(String s) => "'${s.replaceAll("'", "''")}'";
String j(Object o) => '${q(jsonEncode(o))}::jsonb';

Future<String> run(String sql, {String? as}) => pg.sql(db, sql, as: as);

Matcher refusedWith(String text) =>
    throwsA(isA<PgError>().having((e) => e.message, 'message', contains(text)));

/// Somebody signing up, as the Auth service records it.
Future<String> signUp(String email, Map<String, Object?> meta) => run(
  'insert into auth.users (email, raw_user_meta_data) '
  'values (${q(email)}, ${j(meta)}) returning id',
);

class Shop {
  final String owner;
  final String customer;
  final String design;
  Shop(this.owner, this.customer, this.design);
}

Map<String, Object?> designJson(
  String id,
  String customer, {
  String name = 'Front door',
  String category = 'door',
  Object? extra,
}) => {
  'id': id,
  'name': name,
  'category': category,
  'customerId': customer,
  'createdAt': '2026-10-13T08:00:00.000',
  'updatedAt': '2026-10-13T08:00:00.000',
  'depthMm': 70,
  'pricing': {'discount': 'owner only'},
  'sketch': {'strokes': <Object?>[]},
  'dividers': <Object?>[],
  ...?extra as Map<String, Object?>?,
};

/// A factory with an owner, one customer and one design.
Future<Shop> shop(String tag) async {
  final owner = await signUp('$tag@owner.test', {
    'name': 'Owner $tag',
    'factory_name': 'Factory $tag',
  });
  await run(
    "select owner_put_customer('customer-$tag', "
    "${j({'id': 'customer-$tag', 'name': 'Adam $tag', 'phone': '0750'})}, null)",
    as: owner,
  );
  await run(
    "select owner_put_design('design-$tag', "
    "${j(designJson('design-$tag', 'customer-$tag'))}, null)",
    as: owner,
  );
  return Shop(owner, 'customer-$tag', 'design-$tag');
}

/// A labour account joining [shop] by an invitation.
Future<String> worker(Shop shop, String email, {String name = 'Ali'}) async {
  final code = await invite(shop, email, name: name);
  return signUp(email, {'name': name, 'invite_code': code});
}

Future<String> invite(Shop shop, String email, {String name = 'Ali'}) => run(
  'select code from invite_worker(${q(name)}, ${q(email)})',
  as: shop.owner,
);

Future<String> requestNewDesign(String by, String customer) => run(
  "select submit_new_design_request(${q(customer)}, 'Kitchen window', "
  "'window', 'For the kitchen', gen_random_uuid())",
  as: by,
);

void main() {
  setUpAll(() async {
    final started = await LocalPostgres.start();
    if (started != null) pg = started;
  });
  tearDownAll(() async {
    if (LocalPostgres.unavailable == null) await pg.stop();
  });
  setUp(() async {
    if (LocalPostgres.unavailable != null) {
      markTestSkipped(LocalPostgres.unavailable!);
      return;
    }
    db = await pg.database();
  });

  void check(String name, Future<void> Function() body) => test(name, () async {
    if (LocalPostgres.unavailable != null) return;
    await body();
  });

  group('sign-up and sign-in', () {
    check(
      'an owner signing up is given a factory and the owner role',
      () async {
        final owner = await signUp('o@x.test', {
          'name': 'Soran',
          'factory_name': 'Soran workshop',
        });
        final me = await run(
          'select role, name, factory_name, status '
          'from my_account()',
          as: owner,
        );
        expect(me, 'owner|Soran|Soran workshop|active');
      },
    );

    check('a role the client sends is never read', () async {
      final a = await shop('a');
      final code = await invite(a, 'w@x.test');
      final w = await signUp('w@x.test', {
        'name': 'Ali',
        'invite_code': code,
        'role': 'owner',
      });
      expect(await run('select role from my_account()', as: w), 'labour');
      final o = await signUp('o2@x.test', {'name': 'B', 'role': 'labour'});
      expect(await run('select role from my_account()', as: o), 'owner');
    });

    check('an invitation code is for its address, once, unexpired', () async {
      final a = await shop('a');
      final code = await invite(a, 'w@x.test');
      await expectLater(
        signUp('other@x.test', {'name': 'X', 'invite_code': code}),
        refusedWith('PF:invite_invalid'),
      );
      await expectLater(
        signUp('w2@x.test', {'name': 'X', 'invite_code': 'guessed'}),
        refusedWith('PF:invite_invalid'),
      );
      await signUp('w@x.test', {'name': 'Ali', 'invite_code': code});
      await expectLater(
        signUp('w3@x.test', {'name': 'X', 'invite_code': code}),
        refusedWith('PF:invite_invalid'),
      );
      final expired = await invite(a, 'late@x.test');
      await run(
        "update worker_invites set expires_at = now() - interval '1 s' "
        "where email = 'late@x.test'",
      );
      await expectLater(
        signUp('late@x.test', {'name': 'L', 'invite_code': expired}),
        refusedWith('PF:invite_invalid'),
      );
      // A refused sign-up made no account and no factory.
      expect(await run('select count(*) from accounts'), '2');
      expect(await run('select count(*) from factories'), '1');
    });

    check('a name is required, and one address is one account', () async {
      await expectLater(
        signUp('n@x.test', {'name': ' '}),
        refusedWith('PF:name_required'),
      );
      await signUp('n@x.test', {'name': 'N'});
      await expectLater(
        signUp('n@x.test', {'name': 'N'}),
        refusedWith('duplicate key'),
      );
    });

    check('the invitation code is kept only as its hash', () async {
      final a = await shop('a');
      final code = await invite(a, 'w@x.test');
      final kept = await run('select code_hash from worker_invites');
      expect(kept, isNot(contains(code)));
      expect(kept.length, 64);
    });

    check('nobody signed in can read or call nothing', () async {
      await shop('a');
      for (final table in [
        'factories',
        'accounts',
        'customers',
        'designs',
        'requests',
        'notifications',
        'factory_documents',
        'design_assignments',
        'worker_invites',
      ]) {
        await expectLater(
          run('select * from $table', as: 'anon'),
          refusedWith('permission denied'),
        );
      }
      await expectLater(
        run("select invite_worker('x', 'x@x.test')", as: 'anon'),
        refusedWith('permission denied'),
      );
      await expectLater(
        run('select * from my_account()', as: 'anon'),
        refusedWith('permission denied'),
      );
    });

    check('a session with no account can do nothing', () async {
      final stranger = await run(
        'insert into auth.users (email, raw_user_meta_data) '
        "values ('s@x.test', '{\"name\":\"S\"}') returning id",
      );
      await run('delete from accounts where user_id = ${q(stranger)}');
      await run('delete from audit_events');
      await run('delete from factories where owner_id = ${q(stranger)}');
      await expectLater(
        run("select invite_worker('x', 'x@x.test')", as: stranger),
        refusedWith('PF:no_account'),
      );
      expect(await run('select count(*) from designs', as: stranger), '0');
    });
  });

  group('the owner\'s workers', () {
    check('three active workers at most; the fourth is refused', () async {
      final a = await shop('a');
      for (var i = 1; i <= 3; i++) {
        await worker(a, 'w$i@x.test', name: 'W$i');
      }
      await expectLater(invite(a, 'w4@x.test'), refusedWith('PF:worker_limit'));
      final listed = await run(
        'select count(*) from factory_workers()',
        as: a.owner,
      );
      expect(listed, '3');
    });

    check('invitations held open count against the three', () async {
      final a = await shop('a');
      await worker(a, 'w1@x.test');
      await invite(a, 'w2@x.test');
      await invite(a, 'w3@x.test');
      await expectLater(invite(a, 'w4@x.test'), refusedWith('PF:worker_limit'));
      final id = await run(
        "select id from worker_invites where email = 'w3@x.test'",
      );
      await run('select revoke_invite(${q(id)})', as: a.owner);
      await invite(a, 'w4@x.test');
    });

    check('eight invitations at once take exactly the three seats', () async {
      final a = await shop('a');
      final tries = await Future.wait([
        for (var i = 0; i < 8; i++)
          invite(a, 'c$i@x.test').then(
            (_) => true,
            onError: (Object e) {
              expect(e, isA<PgError>());
              expect((e as PgError).message, contains('PF:worker_limit'));
              return false;
            },
          ),
      ]);
      expect(tries.where((ok) => ok), hasLength(3));
      expect(
        await run("select count(*) from worker_invites where status = 'open'"),
        '3',
      );
    });

    check('two sign-ups and a reactivation at once still keep three', () async {
      final a = await shop('a');
      final w1 = await worker(a, 'w1@x.test');
      await run("select set_worker_status(${q(w1)}, 'suspended')", as: a.owner);
      final c2 = await invite(a, 'w2@x.test');
      final c3 = await invite(a, 'w3@x.test');
      await worker(a, 'w4@x.test');
      final results = await Future.wait([
        signUp('w2@x.test', {
          'name': 'W2',
          'invite_code': c2,
        }).then((_) => true, onError: (Object _) => false),
        signUp('w3@x.test', {
          'name': 'W3',
          'invite_code': c3,
        }).then((_) => true, onError: (Object _) => false),
        run(
          "select set_worker_status(${q(w1)}, 'active')",
          as: a.owner,
        ).then((_) => true, onError: (Object _) => false),
      ]);
      expect(results.take(2), everyElement(isTrue));
      expect(results.last, isFalse);
      expect(
        await run(
          "select count(*) from accounts where role = 'labour' "
          "and status = 'active'",
        ),
        '3',
      );
    });

    check('suspending revokes access at once and deletes nothing', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await requestNewDesign(w, 'customer-a');
      await run("select set_worker_status(${q(w)}, 'suspended')", as: a.owner);
      await expectLater(
        run('select * from my_assigned_designs()', as: w),
        refusedWith('PF:suspended'),
      );
      await expectLater(
        requestNewDesign(w, 'customer-a'),
        refusedWith('PF:suspended'),
      );
      expect(await run('select count(*) from requests', as: w), '0');
      expect(await run('select status from my_account()', as: w), 'suspended');
      // Everything is still there, and comes back with the seat.
      expect(await run('select count(*) from designs'), '1');
      expect(await run('select count(*) from customers'), '1');
      expect(await run('select count(*) from requests'), '1');
      await run("select set_worker_status(${q(w)}, 'active')", as: a.owner);
      expect(
        await run('select id from my_assigned_designs()', as: w),
        'design-a',
      );
    });

    check('a seat freed is reused, and the history stays', () async {
      final a = await shop('a');
      final ws = [for (var i = 1; i <= 3; i++) await worker(a, 'w$i@x.test')];
      await run(
        "select set_worker_status(${q(ws.first)}, 'suspended')",
        as: a.owner,
      );
      await worker(a, 'w4@x.test');
      expect(
        await run("select count(*) from accounts where role = 'labour'"),
        '4',
      );
      expect(
        await run(
          'select count(*) from audit_events '
          "where action = 'worker.suspended'",
        ),
        '1',
      );
      await expectLater(
        run("select set_worker_status(${q(ws.first)}, 'active')", as: a.owner),
        refusedWith('PF:worker_limit'),
      );
    });

    check(
      'labour cannot manage workers, promote itself or move factory',
      () async {
        final a = await shop('a');
        final w = await worker(a, 'w@x.test');
        await expectLater(
          invite(Shop(w, '', ''), 'x@x.test'),
          refusedWith('PF:not_owner'),
        );
        await expectLater(
          run("select set_worker_status(${q(w)}, 'active')", as: w),
          refusedWith('PF:not_owner'),
        );
        await expectLater(
          run("update accounts set role = 'owner'", as: w),
          refusedWith('permission denied'),
        );
        final b = await shop('b');
        final other = await run(
          'select id from factories where owner_id = ${q(b.owner)}',
        );
        await expectLater(
          run('update accounts set factory_id = ${q(other)}', as: w),
          refusedWith('permission denied'),
        );
        await expectLater(
          run(
            'insert into accounts (user_id, factory_id, role, name, login) '
            "values (${q(w)}, ${q(other)}, 'owner', 'x', 'x')",
            as: w,
          ),
          refusedWith('permission denied'),
        );
        await expectLater(
          run('select * from factory_workers()', as: w),
          refusedWith('PF:not_owner'),
        );
        // It sees its own account and no other.
        expect(await run('select count(*) from accounts', as: w), '1');
      },
    );
  });

  group('design assignments', () {
    check('a new worker sees no design until one is assigned', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      expect(
        await run('select count(*) from my_assigned_designs()', as: w),
        '0',
      );
      await expectLater(
        run("select * from assigned_design('design-a')", as: w),
        refusedWith('PF:not_assigned'),
      );
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      expect(
        await run(
          'select id, customer_name, revision '
          'from my_assigned_designs()',
          as: w,
        ),
        'design-a|Adam a|1',
      );
    });

    check('labour sees what is drawn and not what it costs', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final data = await run(
        "select data from assigned_design('design-a')",
        as: w,
      );
      final read = jsonDecode(data) as Map<String, Object?>;
      expect(read, isNot(contains('pricing')));
      expect(read['customerId'], 'customer-a');
      final customers = await run('select * from my_customers()', as: w);
      expect(customers, 'customer-a|Adam a');
      // Never the tables themselves.
      expect(await run('select count(*) from designs', as: w), '0');
      expect(await run('select count(*) from customers', as: w), '0');
      expect(await run('select count(*) from design_revisions', as: w), '0');
      expect(await run('select count(*) from factory_documents', as: w), '0');
    });

    check('an unassigned design cannot be opened by its id', () async {
      final a = await shop('a');
      await run(
        "select owner_put_design('design-a2', "
        "${j(designJson('design-a2', 'customer-a'))}, null)",
        as: a.owner,
      );
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await expectLater(
        run("select * from assigned_design('design-a2')", as: w),
        refusedWith('PF:not_assigned'),
      );
      expect(
        await run('select id from my_assigned_designs()', as: w),
        'design-a',
      );
    });

    check('assigned once, removed at once, design data untouched', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final before = await run('select data, revision from designs');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      expect(
        await run(
          'select count(*) from design_assignments '
          "where status = 'active'",
        ),
        '1',
      );
      await run("select unassign_design('design-a', ${q(w)})", as: a.owner);
      await expectLater(
        run("select * from assigned_design('design-a')", as: w),
        refusedWith('PF:not_assigned'),
      );
      expect(
        await run('select count(*) from my_assigned_designs()', as: w),
        '0',
      );
      expect(await run('select data, revision from designs'), before);
      // The assignment's history is kept.
      expect(await run('select count(*) from design_assignments'), '1');
    });

    check('a worker cannot assign designs to itself or to others', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final w2 = await worker(a, 'w2@x.test', name: 'Sara');
      await expectLater(
        run("select assign_design('design-a', ${q(w)})", as: w),
        refusedWith('PF:not_owner'),
      );
      await expectLater(
        run("select assign_design('design-a', ${q(w2)})", as: w),
        refusedWith('PF:not_owner'),
      );
      await expectLater(
        run(
          'insert into design_assignments (factory_id, design_id, worker_id, '
          "assigned_by) select factory_id, 'design-a', ${q(w)}, ${q(w)} "
          'from accounts where user_id = ${q(w)}',
          as: w,
        ),
        refusedWith('permission denied'),
      );
    });
  });

  group('labour cannot write the canonical records', () {
    check('no direct insert, update or delete on any table', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      for (final sql in [
        "update designs set name = 'x'",
        'delete from designs',
        'insert into designs (factory_id, id, customer_id, data) '
            "select factory_id, 'x', 'customer-a', '{}' from accounts",
        "update customers set name = 'x'",
        'insert into requests (factory_id, kind, requested_by, client_key, payload) '
            "select factory_id, 'new_design', user_id, gen_random_uuid(), '{}' "
            'from accounts',
        "update requests set status = 'approved'",
        'insert into notifications (factory_id, recipient, kind) '
            "select factory_id, user_id, 'x' from accounts",
        'insert into factory_documents (factory_id, key, value) '
            "select factory_id, 'proframe.pricelist.v2', '{}' from accounts",
      ]) {
        await expectLater(
          run(sql, as: w),
          refusedWith('permission denied'),
          reason: sql,
        );
      }
    });

    check('the owner\'s functions refuse labour', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      for (final sql in [
        "select owner_put_design('design-a', "
            "${j(designJson('design-a', 'customer-a', name: 'Mine'))}, 1)",
        "select owner_put_design('design-new', "
            "${j(designJson('design-new', 'customer-a'))}, null)",
        "select owner_put_customer('customer-new', "
            "${j({'id': 'customer-new', 'name': 'X'})}, null)",
        "select owner_delete_design('design-a')",
        "select owner_put_document('proframe.pricelist.v2', '{}', null)",
      ]) {
        await expectLater(
          run(sql, as: w),
          refusedWith('PF:not_owner'),
          reason: sql,
        );
      }
      expect(await run('select name, revision from designs'), 'Front door|1');
    });
  });

  group('request: a new design for an existing customer', () {
    check('submitting makes a request and no design', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await requestNewDesign(w, 'customer-a');
      expect(await run('select count(*) from designs'), '1');
      expect(
        await run('select kind, status, customer_id from requests'),
        'new_design|pending|customer-a',
      );
      expect(
        await run(
          'select count(*) from notifications '
          "where recipient = ${q(a.owner)} and kind = 'request_submitted'",
        ),
        '1',
      );
    });

    check('only a customer in the worker\'s scope may be named', () async {
      final a = await shop('a');
      await run(
        "select owner_put_customer('customer-other', "
        "${j({'id': 'customer-other', 'name': 'Sara'})}, null)",
        as: a.owner,
      );
      final w = await worker(a, 'w@x.test');
      await expectLater(
        requestNewDesign(w, 'customer-a'),
        refusedWith('PF:customer_out_of_scope'),
      );
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await expectLater(
        requestNewDesign(w, 'customer-other'),
        refusedWith('PF:customer_out_of_scope'),
      );
      expect(await run('select count(*) from my_customers()', as: w), '1');
    });

    check('a category must be a real one, and a name given', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      await expectLater(
        run(
          "select submit_new_design_request('customer-a', 'X', 'circular', "
          "'', gen_random_uuid())",
          as: w,
        ),
        refusedWith('PF:invalid'),
      );
      await expectLater(
        run(
          "select submit_new_design_request('customer-a', ' ', 'door', "
          "'', gen_random_uuid())",
          as: w,
        ),
        refusedWith('PF:name_required'),
      );
    });

    check('a submission retried is one request', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      const key = "'11111111-1111-1111-1111-111111111111'";
      final first = await run(
        "select submit_new_design_request('customer-a', "
        "'K', 'window', '', $key)",
        as: w,
      );
      final again = await run(
        "select submit_new_design_request('customer-a', "
        "'K', 'window', '', $key)",
        as: w,
      );
      expect(again, first);
      expect(await run('select count(*) from requests'), '1');
    });

    check('approved: the design made once, retried or raced', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final r = await requestNewDesign(w, 'customer-a');
      final made = j(
        designJson(
          'design-k',
          'customer-a',
          name: 'Kitchen window',
          category: 'window',
        ),
      );
      final raced = await Future.wait([
        for (var i = 0; i < 4; i++)
          run(
            'select design_id from approve_new_design_request(${q(r)}, '
            "${i == 0 ? made : j(designJson('design-k$i', 'customer-a', category: 'window'))}"
            ", false, 'ok')",
            as: a.owner,
          ),
      ]);
      expect(raced.toSet(), hasLength(1));
      expect(
        await run("select count(*) from designs where id like 'design-k%'"),
        '1',
      );
      final again = await run(
        'select design_id from approve_new_design_request('
        "${q(r)}, ${j(designJson('design-z', 'customer-a', category: 'window'))}, "
        "false, '')",
        as: a.owner,
      );
      expect(again, raced.first);
      expect(
        await run('select status, result_design_id from requests'),
        'approved|${raced.first}',
      );
      // Not assigned unless the owner said so; the worker is told.
      expect(
        await run('select count(*) from my_assigned_designs()', as: w),
        '1',
      );
      expect(
        await run(
          'select kind from notifications where recipient = ${q(w)} '
          "and kind like 'request_%'",
          as: w,
        ),
        'request_approved',
      );
    });

    check('approved with access: the design is assigned to the worker', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final r = await requestNewDesign(w, 'customer-a');
      await run(
        'select * from approve_new_design_request(${q(r)}, '
        "${j(designJson('design-k', 'customer-a', category: 'window'))}, true, '')",
        as: a.owner,
      );
      expect(
        await run('select count(*) from my_assigned_designs()', as: w),
        '2',
      );
    });

    check('a design that is not what was asked for is refused', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final r = await requestNewDesign(w, 'customer-a');
      for (final wrong in [
        designJson('design-k', 'customer-other', category: 'window'),
        designJson('design-k', 'customer-a', category: 'door'),
        designJson('design-a', 'customer-a', category: 'window'),
      ]) {
        await expectLater(
          run(
            'select * from approve_new_design_request(${q(r)}, ${j(wrong)}, '
            "false, '')",
            as: a.owner,
          ),
          refusedWith('PF:'),
        );
      }
      expect(await run('select status from requests'), 'pending');
      expect(await run('select count(*) from designs'), '1');
    });

    check(
      'rejected: nothing is made, and it cannot then be approved',
      () async {
        final a = await shop('a');
        final w = await worker(a, 'w@x.test');
        await run("select assign_design('design-a', ${q(w)})", as: a.owner);
        final r = await requestNewDesign(w, 'customer-a');
        await run("select reject_request(${q(r)}, 'Not now')", as: a.owner);
        expect(
          await run('select status, decision_note from requests'),
          'rejected|Not now',
        );
        await expectLater(
          run(
            'select * from approve_new_design_request(${q(r)}, '
            "${j(designJson('design-k', 'customer-a', category: 'window'))}, "
            "false, '')",
            as: a.owner,
          ),
          refusedWith('PF:already_decided'),
        );
        expect(await run('select count(*) from designs'), '1');
        expect(
          await run(
            'select kind from notifications where recipient = ${q(w)} '
            "and kind like 'request_%'",
            as: w,
          ),
          'request_rejected',
        );
      },
    );

    check('labour cannot decide, and nobody approves their own', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final r = await requestNewDesign(w, 'customer-a');
      await expectLater(
        run(
          'select * from approve_new_design_request(${q(r)}, '
          "${j(designJson('design-k', 'customer-a', category: 'window'))}, "
          "true, '')",
          as: w,
        ),
        refusedWith('PF:not_owner'),
      );
      await expectLater(
        run("select reject_request(${q(r)}, '')", as: w),
        refusedWith('PF:not_owner'),
      );
      // An owner submitting a request of their own is refused outright.
      await expectLater(
        requestNewDesign(a.owner, 'customer-a'),
        refusedWith('PF:not_labour'),
      );
    });

    check('a worker may cancel only their own pending request', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final w2 = await worker(a, 'w2@x.test', name: 'Sara');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      final r = await requestNewDesign(w, 'customer-a');
      await expectLater(
        run('select cancel_request(${q(r)})', as: w2),
        refusedWith('PF:not_pending'),
      );
      await run('select cancel_request(${q(r)})', as: w);
      expect(await run('select status from requests'), 'cancelled');
      // And sees nobody else's requests or notifications.
      expect(await run('select count(*) from requests', as: w2), '0');
      expect(await run('select count(*) from notifications', as: w2), '0');
    });
  });

  group('request: a new customer and design', () {
    Future<String> submit(String w) => run(
      "select submit_new_customer_request(${j({'name': 'Adam', 'phone': '0750 123 4567', 'address': 'Erbil', 'notes': ''})}, 'Basement door', 'door', 'New job', gen_random_uuid())",
      as: w,
    );

    check('submitting makes no customer and no design', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await submit(w);
      expect(await run('select count(*) from customers'), '1');
      expect(await run('select count(*) from designs'), '1');
      expect(
        await run("select payload->'customer'->>'phone' from requests"),
        '0750 123 4567',
      );
    });

    check('approved: the customer and the design together, once', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final r = await submit(w);
      String approve(String c, String d) =>
          'select design_id, customer_id from approve_new_customer_request('
          "${q(r)}, ${j({'id': c, 'name': 'Adam'})}, "
          "${j(designJson(d, c, name: 'Basement door'))}, false, '')";
      final first = await run(approve('customer-n', 'design-n'), as: a.owner);
      final again = await run(approve('customer-m', 'design-m'), as: a.owner);
      expect(first, 'design-n|customer-n');
      expect(again, first);
      expect(await run('select count(*) from customers'), '2');
      expect(await run('select count(*) from designs'), '2');
    });

    check('a design that cannot go in takes the customer back out', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final r = await submit(w);
      // The design names the existing design's id: refused, and the
      // customer that would have been made with it is not.
      await expectLater(
        run(
          'select * from approve_new_customer_request(${q(r)}, '
          "${j({'id': 'customer-n', 'name': 'Adam'})}, "
          "${j(designJson('design-a', 'customer-n'))}, false, '')",
          as: a.owner,
        ),
        refusedWith('PF:invalid'),
      );
      expect(await run('select count(*) from customers'), '1');
      expect(await run('select status from requests'), 'pending');
    });

    check('rejected: nothing is inserted', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      final r = await submit(w);
      await run(
        "select reject_request(${q(r)}, 'Duplicate of Adam a')",
        as: a.owner,
      );
      expect(await run('select count(*) from customers'), '1');
      expect(await run('select count(*) from designs'), '1');
    });
  });

  group('request: a change to an assigned design', () {
    Future<String> propose(
      String w, {
      int base = 1,
      String name = 'Hacked',
    }) => run(
      "select submit_change_request('design-a', $base, ${j(designJson('design-a', 'customer-a', name: name, extra: {
        'depthMm': 90,
        'pricing': {'discount': 'all of it'},
        'customerId': 'customer-a',
      }))}, 'Deeper frame', gen_random_uuid())",
      as: w,
    );

    Future<String> assigned(Shop a) async {
      final w = await worker(a, 'w@x.test');
      await run("select assign_design('design-a', ${q(w)})", as: a.owner);
      return w;
    }

    check('submitting leaves the design exactly as it was', () async {
      final a = await shop('a');
      final w = await assigned(a);
      final before = await run('select data, revision from designs');
      await propose(w);
      expect(await run('select data, revision from designs'), before);
      expect(
        await run(
          "select base_revision, payload->'design'->>'depthMm' "
          'from requests',
        ),
        '1|90',
      );
      expect(
        await run("select payload->'design' ? 'pricing' from requests"),
        'f',
      );
    });

    check('only an assigned design can be proposed for', () async {
      final a = await shop('a');
      final w = await worker(a, 'w@x.test');
      await expectLater(propose(w), refusedWith('PF:not_assigned'));
    });

    check('approved: applied once, the rest of the design kept', () async {
      final a = await shop('a');
      final w = await assigned(a);
      final r = await propose(w);
      final applied = await run(
        'select revision from approve_change_request('
        "${q(r)}, 'Fine')",
        as: a.owner,
      );
      expect(applied, '2');
      final data = jsonDecode(await run('select data from designs')) as Map;
      expect(data['depthMm'], 90);
      expect(data['name'], 'Front door', reason: 'the name is the owner\'s');
      expect(data['pricing'], {'discount': 'owner only'});
      expect(await run('select revision from designs'), '2');
      // Again: the same answer, nothing applied twice.
      expect(
        await run(
          "select revision from approve_change_request(${q(r)}, '')",
          as: a.owner,
        ),
        '2',
      );
      expect(await run('select revision from designs'), '2');
      // The history holds both versions, the second from the request.
      expect(
        await run(
          'select revision, source from design_revisions '
          'order by revision',
        ),
        '1|owner\n2|request',
      );
      expect(
        await run("select request_base(${q(r)})->>'depthMm'", as: a.owner),
        '70',
      );
    });

    check('a design changed since the proposal is a conflict', () async {
      final a = await shop('a');
      final w = await assigned(a);
      final r = await propose(w);
      await run(
        "select owner_put_design('design-a', "
        "${j(designJson('design-a', 'customer-a', name: 'Renamed'))}, 1)",
        as: a.owner,
      );
      await expectLater(
        run("select * from approve_change_request(${q(r)}, '')", as: a.owner),
        refusedWith('PF:conflict'),
      );
      expect(
        await run("select data->>'depthMm', revision from designs"),
        '70|2',
      );
      expect(await run('select status from requests'), 'pending');
    });

    check('rejected: the design unchanged, and the decision audited', () async {
      final a = await shop('a');
      final w = await assigned(a);
      final before = await run('select data, revision from designs');
      final r = await propose(w);
      await run("select reject_request(${q(r)}, 'Keep 70')", as: a.owner);
      expect(await run('select data, revision from designs'), before);
      expect(
        await run(
          'select count(*) from audit_events '
          "where action = 'request.rejected'",
        ),
        '1',
      );
    });

    check('the owner\'s own saves are held to the revision they had', () async {
      final a = await shop('a');
      await expectLater(
        run(
          "select owner_put_design('design-a', "
          "${j(designJson('design-a', 'customer-a', name: 'Stale'))}, 7)",
          as: a.owner,
        ),
        refusedWith('PF:conflict'),
      );
    });
  });

  group('one factory never sees another', () {
    check('reads of another factory find nothing', () async {
      final a = await shop('a');
      final b = await shop('b');
      final wa = await worker(a, 'wa@x.test');
      await run("select assign_design('design-a', ${q(wa)})", as: a.owner);
      await requestNewDesign(wa, 'customer-a');
      await run(
        "select owner_put_document('proframe.pricelist.v2', '{}', null)",
        as: a.owner,
      );
      for (final table in [
        'customers',
        'designs',
        'requests',
        'factory_documents',
        'design_assignments',
        'design_revisions',
        'notifications',
        'audit_events',
      ]) {
        final seen = await run(
          'select count(*) from $table where factory_id <> '
          '(select factory_id from accounts where user_id = ${q(b.owner)})',
          as: b.owner,
        );
        expect(seen, '0', reason: table);
      }
      expect(await run('select count(*) from accounts', as: b.owner), '1');
      expect(await run('select count(*) from factories', as: b.owner), '1');
      expect(
        await run('select count(*) from factory_workers()', as: b.owner),
        '0',
      );
    });

    check('writes to another factory are refused or stay in their own', () async {
      final a = await shop('a');
      final b = await shop('b');
      final wa = await worker(a, 'wa@x.test');
      final r = await requestNewDesign(
        await run(
          "select assign_design('design-a', ${q(wa)})",
          as: a.owner,
        ).then((_) => wa),
        'customer-a',
      );
      final before = await run(
        'select data, revision from designs '
        "where id = 'design-a'",
      );
      for (final sql in [
        "select reject_request(${q(r)}, '')",
        'select * from approve_new_design_request(${q(r)}, '
            "${j(designJson('design-x', 'customer-a', category: 'window'))}, false, '')",
        "select assign_design('design-a', ${q(wa)})",
        "select set_worker_status(${q(wa)}, 'suspended')",
        'select * from request_base(${q(r)})',
      ]) {
        await expectLater(
          run(sql, as: b.owner),
          refusedWith('PF:not_found'),
          reason: sql,
        );
      }
      // Writing a record with another factory's id writes the caller's own.
      await expectLater(
        run(
          "select owner_put_design('design-a', "
          "${j(designJson('design-a', 'customer-a'))}, null)",
          as: b.owner,
        ),
        refusedWith('PF:customer_missing'),
      );
      expect(
        await run("select data, revision from designs where id = 'design-a'"),
        before,
      );
      expect(await run('select status from requests'), 'pending');
      expect(
        await run('select status from accounts where user_id = ${q(wa)}'),
        'active',
      );
    });

    check('a worker of one factory sees nothing of another', () async {
      final a = await shop('a');
      final b = await shop('b');
      final wa = await worker(a, 'wa@x.test');
      await expectLater(
        run("select * from assigned_design('design-b')", as: wa),
        refusedWith('PF:not_assigned'),
      );
      await expectLater(
        run(
          "select submit_change_request('design-b', 1, "
          "${j(designJson('design-b', 'customer-b'))}, '', gen_random_uuid())",
          as: wa,
        ),
        refusedWith('PF:not_assigned'),
      );
      await expectLater(
        requestNewDesign(wa, 'customer-b'),
        refusedWith('PF:customer_out_of_scope'),
      );
      // Even an owner of B cannot hand B's design to A's worker.
      await expectLater(
        run("select assign_design('design-b', ${q(wa)})", as: b.owner),
        refusedWith('PF:not_found'),
      );
    });
  });
}
