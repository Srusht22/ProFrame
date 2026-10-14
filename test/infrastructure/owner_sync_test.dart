// What an owner's device sends to the backend and brings down from it, and
// what the device keeps of anybody once there are accounts.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/accounts/accounts.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/cloud/device_data.dart';
import 'package:proframe/infrastructure/cloud/owner_sync.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/owner_access_store.dart';
import 'package:proframe/infrastructure/staff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/fake_backend.dart';

final _at = DateTime(2026, 10, 13);

Customer adam() =>
    Customer(id: 'customer-adam', name: 'Adam', createdAt: _at, updatedAt: _at);

Design door({String name = 'Front door', double depth = 70}) => Design.empty(
  id: 'design-front',
  kind: DesignKind.door,
  name: name,
  customerId: 'customer-adam',
  now: _at,
  measured: const {},
).copyWith(depthMm: depth);

void main() {
  late FakeBackend backend;
  late String owner;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    owner = backend.addOwner('o@x.test', 'pw');
    backend.current = owner;
    await DeviceData.claimFor(owner);
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('the owner\'s records are sent, customers before their designs, and '
      'the indexes, PIN and local staff list are not', () async {
    await CustomerStore().save(adam(), by: WorkshopRole.owner);
    await DesignStore().save(door(), by: WorkshopRole.owner);
    final p = await prefs();
    await p.setString(OwnerAccessStore.key, 'pin-hash');
    await p.setString(StaffStore.key, '[]');
    await p.setString('proframe.pricelist.v2', '{"x":1}');
    await p.setString('proframe.language', 'ckb');
    await OwnerSync(backend).push();
    final f = backend.accounts[owner]!.factoryId;
    expect(backend.customers[f]!.keys, ['customer-adam']);
    expect(backend.designs[f]!.keys, ['design-front']);
    expect(backend.documents[f]!.keys, ['proframe.pricelist.v2']);
  });

  test('a record is sent again only when it changed, with the revision it '
      'was based on', () async {
    await CustomerStore().save(adam(), by: WorkshopRole.owner);
    await DesignStore().save(door(), by: WorkshopRole.owner);
    final sync = OwnerSync(backend);
    await sync.push();
    await sync.push();
    expect(backend.revisionOf(owner, 'design-front'), 1);
    await DesignStore().save(door(depth: 90), by: WorkshopRole.owner);
    await sync.push();
    expect(backend.revisionOf(owner, 'design-front'), 2);
    expect(backend.design(owner, 'design-front')!['depthMm'], 90);
  });

  test('changed in both places: the backend\'s is taken and the device\'s '
      'kept beside it — neither lost', () async {
    await CustomerStore().save(adam(), by: WorkshopRole.owner);
    await DesignStore().save(door(), by: WorkshopRole.owner);
    final sync = OwnerSync(backend);
    await sync.push();
    // Another device moves the backend on.
    await backend.putDesign(
      'design-front',
      jsonEncode(door(name: 'Theirs').toJson()),
      1,
    );
    await DesignStore().save(door(name: 'Mine'), by: WorkshopRole.owner);
    await sync.pull();
    // The device's version was refused as a conflict, not written over.
    expect(
      sync.unsent['${DesignStore.designKeyPrefix}design-front'],
      'conflict',
    );
    expect((await DesignStore().load('design-front'))!.name, 'Theirs');
    final kept = (await prefs()).getKeys().where(
      (k) => k.startsWith(DeviceData.keptLocalPrefix),
    );
    expect(kept, hasLength(1));
    expect((await prefs()).getString(kept.single), contains('Mine'));
  });

  test('pulling brings down what the device does not have, listed', () async {
    backend.seed(owner, adam().toJson(), door().toJson());
    await OwnerSync(backend).pull();
    expect((await DesignStore().load('design-front'))!.name, 'Front door');
    expect((await DesignStore().page()).total, 1);
    expect((await CustomerStore().page()).total, 1);
  });

  test('a design deleted on the device is deleted on the backend', () async {
    await CustomerStore().save(adam(), by: WorkshopRole.owner);
    await DesignStore().save(door(), by: WorkshopRole.owner);
    final sync = OwnerSync(backend);
    await sync.push();
    await DesignStore().remove('design-front', by: WorkshopRole.owner);
    await sync.push();
    expect(backend.design(owner, 'design-front'), isNull);
  });

  test('a worker\'s device sends nothing the backend keeps', () async {
    final worker = backend.addWorker(owner, 'w@x.test', 'pw');
    backend.current = worker;
    await CustomerStore().save(adam(), by: WorkshopRole.owner);
    final sync = OwnerSync(backend);
    await sync.push();
    expect(sync.unsent.values.toSet(), {'not_owner'});
    expect(backend.customers, isEmpty);
  });

  group('the device', () {
    test('records from before accounts are archived, never deleted', () async {
      SharedPreferences.setMockInitialValues({
        'proframe.design.v2.old': '{"id":"old"}',
        'proframe.language': 'ckb',
      });
      expect(await DeviceData.hasUnclaimed(), isTrue);
      expect(await DeviceData.archive(now: _at), 1);
      final p = await prefs();
      expect(p.getString('proframe.design.v2.old'), isNull);
      expect(
        p.getString(
          '${DeviceData.archivePrefix}${_at.toUtc().toIso8601String()}'
          '.proframe.design.v2.old',
        ),
        '{"id":"old"}',
      );
      expect(p.getString('proframe.language'), 'ckb');
      expect(await DeviceData.archives(), [_at.toUtc().toIso8601String()]);
      expect(
        await DeviceData.bringBack(_at.toUtc().toIso8601String(), 'u'),
        isTrue,
      );
      expect(p.getString('proframe.design.v2.old'), '{"id":"old"}');
    });

    test('clearing a cache clears only the records it cached', () async {
      final p = await prefs();
      await p.setString('proframe.design.v2.x', '{}');
      await p.setString('proframe.language', 'ckb');
      await p.setString(
        '${DeviceData.archivePrefix}a.proframe.design.v2.y',
        '{}',
      );
      await p.setString(
        '${DeviceData.keptLocalPrefix}a.proframe.design.v2.z',
        '{}',
      );
      await DeviceData.clearCache();
      expect(p.getKeys(), {
        'proframe.language',
        '${DeviceData.archivePrefix}a.proframe.design.v2.y',
        '${DeviceData.keptLocalPrefix}a.proframe.design.v2.z',
      });
    });

    test('records nobody claimed are never cleared as a cache', () async {
      await (await prefs()).remove(DeviceData.markerKey);
      await (await prefs()).setString('proframe.design.v2.x', '{}');
      await DeviceData.clearCache();
      expect((await prefs()).getString('proframe.design.v2.x'), '{}');
    });
  });

  group('what an account may do on the device', () {
    Account account(
      AccountRole role, {
      AccountStatus status = AccountStatus.active,
    }) => Account(
      userId: 'u',
      factoryId: 'f',
      factoryName: 'F',
      role: role,
      name: 'N',
      login: 'n@x',
      status: status,
    );

    test('an owner everything; a worker only to look; suspended nothing', () {
      for (final c in Capability.values) {
        expect(account(AccountRole.owner).can(c), isTrue);
        expect(
          account(AccountRole.labour).can(c),
          c == Capability.designsView,
          reason: c.key,
        );
        expect(
          account(AccountRole.owner, status: AccountStatus.suspended).can(c),
          isFalse,
        );
      }
    });

    test('a role the backend does not name is no account', () {
      expect(
        Account.fromJson({'role': 'admin', 'user_id': 'u', 'factory_id': 'f'}),
        isNull,
      );
    });
  });
}
