// Phase 36 on the real application: signing in, up and out, the owner's
// workers and assignments, a worker's requests and proposals, and the
// approval center — against the backend's contract held in memory
// (`fake_backend.dart`).
//
// What is secure is not tested here. A stand-in in memory cannot prove a
// rule kept: that is `test/backend/backend_security_test.dart`, against
// PostgreSQL. These hold that the screens ask the backend and show what it
// answers — and that the device keeps nothing of one account for the next.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/proposal_bar.dart';
import 'package:proframe/app/screens/accounts/account_ui.dart';
import 'package:proframe/app/screens/accounts/approvals_screen.dart';
import 'package:proframe/app/screens/accounts/auth_screens.dart';
import 'package:proframe/app/screens/accounts/cloud_header.dart';
import 'package:proframe/app/screens/accounts/labour_home_screen.dart';
import 'package:proframe/app/screens/accounts/workers_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/factory_defaults_screen.dart';
import 'package:proframe/app/screens/language_button.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/cloud.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/accounts/accounts.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/cloud/device_data.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

final _at = DateTime(2026, 10, 13, 9);

Map<String, Object?> adam([String id = 'customer-adam']) => Customer(
  id: id,
  name: 'Adam',
  phone: '0750 123 4567',
  createdAt: _at,
  updatedAt: _at,
).toJson();

Map<String, Object?> frontDoor({
  String id = 'design-front',
  String customer = 'customer-adam',
  String name = 'Front door',
}) => Design.empty(
  id: id,
  kind: DesignKind.door,
  name: name,
  customer: 'Adam',
  customerId: customer,
  now: _at,
  measured: const {},
).toJson();

/// A backend with Soran's factory — Adam and his front door — and Ali, a
/// worker in it.
({FakeBackend backend, String owner, String worker}) factory() {
  final backend = FakeBackend();
  final owner = backend.addOwner('soran@x.test', 'owner-pass');
  final worker = backend.addWorker(owner, 'ali@x.test', 'worker-pass');
  backend.seed(owner, adam(), frontDoor());
  return (backend: backend, owner: owner, worker: worker);
}

Future<ProviderContainer> openApp(
  WidgetTester tester,
  FakeBackend? backend, {
  Size size = const Size(1280, 860),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      if (backend != null) backendProvider.overrideWithValue(backend),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(SignInScreen.emailKey), email);
  await tester.enterText(find.byKey(SignInScreen.passwordKey), password);
  await tester.tap(find.byKey(SignInScreen.submitKey));
  await tester.pumpAndSettle();
}

Future<void> signOut(WidgetTester tester) async {
  await tester.tap(find.byKey(CloudAccountButton.buttonKey).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(CloudAccountButton.signOutKey));
  await tester.pumpAndSettle();
}

Future<Set<String>> recordKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getKeys().where(DeviceData.isRecord).toSet();
}

Future<void> push(
  WidgetTester tester,
  ProviderContainer c,
  Widget screen,
) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('signing in, up and out', () {
    testWidgets('without a backend the app opens on the customers as before', (
      tester,
    ) async {
      await openApp(tester, null);
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('signed out, it opens on signing in; a wrong password is '
        'refused in words, and nothing is shown of the factory', (
      tester,
    ) async {
      final f = factory();
      await openApp(tester, f.backend);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(CustomersScreen), findsNothing);
      await signIn(tester, 'soran@x.test', 'wrong');
      expect(
        find.text('That email and password do not match an account.'),
        findsOneWidget,
      );
      expect(find.byType(CustomersScreen), findsNothing);
      await signIn(tester, 'not-an-address', 'x');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('an owner signs in to their own customers, brought down from '
        'the backend; signing out clears all of it from the device', (
      tester,
    ) async {
      final f = factory();
      final c = await openApp(tester, f.backend);
      await signIn(tester, 'soran@x.test', 'owner-pass');
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(find.text('Adam'), findsWidgets);
      expect(find.byKey(ApprovalsButton.buttonKey), findsOneWidget);
      expect(c.read(sessionProvider).value!.role, AccountRole.owner);
      expect(
        await recordKeys(),
        containsAll([
          '${CustomerStore.customerKeyPrefix}customer-adam',
          '${DesignStore.designKeyPrefix}design-front',
        ]),
      );
      expect(await DeviceData.cacheOf(), f.owner);

      await signOut(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(await recordKeys(), isEmpty);
      expect(await DeviceData.cacheOf(), isNull);
      expect(f.backend.current, isNull);
    });

    testWidgets('a session that expires goes back to signing in, and shows '
        'nothing more of the factory', (tester) async {
      final f = factory();
      f.backend.kept = f.owner;
      await openApp(tester, f.backend);
      expect(find.byType(CustomersScreen), findsOneWidget);
      f.backend.expire();
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(CustomersScreen), findsNothing);
      // Another account signing in finds none of the first one's records.
      await signIn(tester, 'ali@x.test', 'worker-pass');
      expect(find.byType(LabourHomeScreen), findsOneWidget);
      expect(await recordKeys(), isEmpty);
    });

    testWidgets('a session kept on the device is restored', (tester) async {
      final f = factory();
      f.backend.kept = f.owner;
      await openApp(tester, f.backend);
      expect(find.byType(CustomersScreen), findsOneWidget);
    });

    testWidgets('an owner signs up, and confirms the address first; the role '
        'is the backend\'s, never chosen on the screen', (tester) async {
      final backend = FakeBackend()..confirmEmail = true;
      await openApp(tester, backend);
      await tester.tap(find.byKey(SignInScreen.signUpKey));
      await tester.pumpAndSettle();
      // Nothing on the form says what the account is.
      expect(find.text('Worker'), findsNothing);
      await tester.enterText(
        find.byKey(SignUpScreen.factoryKey),
        'Hawre doors',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-account-name')),
        'Hawre',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-account-email')),
        'hawre@x.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-account-password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-account-again')),
        'short',
      );
      await tester.tap(find.byKey(SignUpScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text('At least 8 characters.'), findsWidgets);
      expect(backend.accounts, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('new-account-password')),
        'long-enough',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-account-again')),
        'long-enough',
      );
      await tester.tap(find.byKey(SignUpScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('confirm-email-sent')), findsOneWidget);
      expect(backend.accounts.values.single.role, AccountRole.owner);
      expect(backend.current, isNull);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await signIn(tester, 'hawre@x.test', 'long-enough');
      expect(
        find.text(
          'Confirm your email address first — open the link we sent you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a worker joins by an invitation; a wrong code is refused', (
      tester,
    ) async {
      final f = factory();
      f.backend.current = f.owner;
      final code = (await f.backend.invite(
        name: 'Sara',
        email: 'sara@x.test',
      )).code;
      f.backend.current = null;
      await openApp(tester, f.backend);
      await tester.tap(find.byKey(SignInScreen.joinKey));
      await tester.pumpAndSettle();
      Future<void> fill(String withCode) async {
        await tester.enterText(find.byKey(JoinScreen.codeKey), withCode);
        await tester.enterText(
          find.byKey(const ValueKey('new-account-name')),
          'Sara',
        );
        await tester.enterText(
          find.byKey(const ValueKey('new-account-email')),
          'sara@x.test',
        );
        for (final k in ['new-account-password', 'new-account-again']) {
          await tester.enterText(find.byKey(ValueKey(k)), 'sara-pass');
        }
        await tester.tap(find.byKey(JoinScreen.submitKey));
        await tester.pumpAndSettle();
      }

      await fill('guessed');
      expect(
        find.textContaining('That invitation code is not valid'),
        findsOneWidget,
      );
      await fill(code);
      expect(find.byType(LabourHomeScreen), findsOneWidget);
      expect(find.byType(CustomersScreen), findsNothing);
    });

    testWidgets('password recovery goes through the provider and says nothing '
        'about whether the address has an account', (tester) async {
      final f = factory();
      await openApp(tester, f.backend);
      await tester.tap(find.byKey(SignInScreen.forgotKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(RecoverScreen.emailKey),
        'nobody@x.test',
      );
      await tester.tap(find.byKey(RecoverScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.byKey(RecoverScreen.sentKey), findsOneWidget);
      expect(f.backend.recovered, ['nobody@x.test']);
    });

    testWidgets('a suspended worker is refused at signing in', (tester) async {
      final f = factory();
      f.backend.current = f.owner;
      await f.backend.setWorkerActive(f.worker, active: false);
      f.backend.current = null;
      await openApp(tester, f.backend);
      await signIn(tester, 'ali@x.test', 'worker-pass');
      expect(
        find.text('This account is suspended. Ask your factory owner.'),
        findsOneWidget,
      );
      expect(find.byType(LabourHomeScreen), findsNothing);
      expect(f.backend.current, isNull);
    });
  });

  group('the owner\'s workers', () {
    testWidgets('inviting shows the code once; three places, and the button '
        'is off when they are taken; suspending asks first', (tester) async {
      final f = factory();
      f.backend.kept = f.owner;
      final c = await openApp(tester, f.backend);
      await push(tester, c, const WorkersScreen());
      expect(find.text('1 of 3 worker places used'), findsOneWidget);
      for (final name in ['Sara', 'Rawa']) {
        await tester.tap(find.byKey(WorkersScreen.inviteKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(InviteDialog.nameKey), name);
        await tester.enterText(
          find.byKey(InviteDialog.emailKey),
          '${name.toLowerCase()}@x.test',
        );
        await tester.tap(find.byKey(InviteDialog.submitKey));
        await tester.pumpAndSettle();
        expect(find.byKey(InviteDialog.codeKey), findsOneWidget);
        expect(find.text('This code is not shown again.'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      }
      expect(find.text('3 of 3 worker places used'), findsOneWidget);
      final invite = tester.widget<FloatingActionButton>(
        find.byKey(WorkersScreen.inviteKey),
      );
      expect(invite.onPressed, isNull);
      // No password anywhere on the screen.
      expect(find.textContaining('worker-pass'), findsNothing);

      await tester.tap(find.byKey(WorkersScreen.toggleKey(f.worker)));
      await tester.pumpAndSettle();
      expect(find.text('Suspend Ali?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suspend-confirm')));
      await tester.pumpAndSettle();
      expect(f.backend.accounts[f.worker]!.status, AccountStatus.suspended);
      expect(find.text('2 of 3 worker places used'), findsOneWidget);
    });

    testWidgets('a design is given to a worker and taken away; a new worker '
        'sees none', (tester) async {
      final f = factory();
      f.backend.kept = f.owner;
      final c = await openApp(tester, f.backend);
      await push(tester, c, WorkerScreen(workerId: f.worker));
      expect(find.byKey(WorkerScreen.noneKey), findsOneWidget);
      await tester.tap(find.byKey(WorkerScreen.assignKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AssignDialog.optionKey('design-front')));
      await tester.pumpAndSettle();
      expect(f.backend.assigned.single.design, 'design-front');
      expect(find.text('Front door'), findsOneWidget);
      await tester.tap(find.byKey(WorkerScreen.removeKey('design-front')));
      await tester.pumpAndSettle();
      expect(f.backend.assigned, isEmpty);
      expect(find.byKey(WorkerScreen.noneKey), findsOneWidget);
    });
  });

  group('a worker', () {
    Future<ProviderContainer> asWorker(
      WidgetTester tester,
      ({FakeBackend backend, String owner, String worker}) f, {
      Size size = const Size(1280, 860),
    }) async {
      f.backend.current = f.owner;
      await f.backend.assign('design-front', f.worker);
      f.backend.current = null;
      f.backend.kept = f.worker;
      return openApp(tester, f.backend, size: size);
    }

    testWidgets('sees only the designs assigned, and nothing of the owner\'s', (
      tester,
    ) async {
      final f = factory();
      f.backend.seed(
        f.owner,
        adam('customer-sara'),
        frontDoor(
          id: 'design-other',
          customer: 'customer-sara',
          name: 'Garage door',
        ),
      );
      await asWorker(tester, f);
      expect(find.byType(LabourHomeScreen), findsOneWidget);
      expect(find.text('Front door'), findsOneWidget);
      expect(find.text('Garage door'), findsNothing);
      expect(find.byKey(ApprovalsButton.buttonKey), findsNothing);
      // Nothing of the factory is kept on a worker's device.
      expect(await recordKeys(), isEmpty);
    });

    testWidgets('is refused every owner screen, even pushed directly', (
      tester,
    ) async {
      final f = factory();
      final c = await asWorker(tester, f);
      for (final screen in <Widget>[
        const WorkersScreen(),
        const ApprovalsScreen(),
        const FactoryDefaultsScreen(),
        WorkerScreen(workerId: f.worker),
      ]) {
        await push(tester, c, screen);
        expect(find.byKey(OwnerOnly.refusedKey), findsOneWidget);
        expect(find.byKey(WorkersScreen.inviteKey), findsNothing);
        Navigator.of(tester.element(find.byKey(OwnerOnly.refusedKey))).pop();
        await tester.pumpAndSettle();
      }
      // And the backend refuses the calls whatever is on the screen.
      expect(() => f.backend.workers(), throwsA(isA<Object>()));
    });

    testWidgets('asks for a new design: a request, never a design, until the '
        'owner approves it — once', (tester) async {
      final f = factory();
      await asWorker(tester, f);
      await tester.tap(find.byKey(LabourHomeScreen.newDesignKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NewDesignRequestScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text('Choose the customer.'), findsOneWidget);
      await tester.tap(find.byKey(NewDesignRequestScreen.customerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adam').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(NewDesignRequestScreen.nameKey),
        'Kitchen window',
      );
      await tester.tap(find.byKey(CategoryChoice.chipKey(DesignKind.window)));
      await tester.enterText(
        find.byKey(NewDesignRequestScreen.descriptionKey),
        'Over the sink',
      );
      await tester.tap(find.byKey(NewDesignRequestScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text('Request sent to the owner.'), findsOneWidget);
      final request = f.backend.asked.single;
      expect(request.kind, RequestKind.newDesign);
      expect(request.status, RequestStatus.pending);
      expect(f.backend.designs.values.single.length, 1);

      // The owner approves it, without giving access.
      await signOut(tester);
      await signIn(tester, 'soran@x.test', 'owner-pass');
      await tester.tap(find.byKey(ApprovalsButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text('Pending (1)'), findsOneWidget);
      await tester.tap(find.byKey(RequestTile.tileKey(request.id)));
      await tester.pumpAndSettle();
      expect(find.text('Kitchen window'), findsWidgets);
      expect(find.text('Over the sink'), findsOneWidget);
      final assign = tester.widget<CheckboxListTile>(
        find.byKey(RequestScreen.assignKey),
      );
      expect(assign.value, isFalse);
      await tester.tap(find.byKey(RequestScreen.approveKey));
      await tester.pumpAndSettle();
      expect(find.text('Approved.'), findsOneWidget);
      expect(f.backend.approvals, 1);
      final made = f.backend.designs.values.single.keys.toSet()
        ..remove('design-front');
      expect(made, hasLength(1));
      expect(f.backend.assigned.where((a) => a.design == made.single), isEmpty);
      // It is on the owner's device too, as Adam's.
      final kept = await DesignStore().load(made.single);
      expect(kept!.name, 'Kitchen window');
      expect(kept.kind, DesignKind.window);
      expect(kept.customerId, 'customer-adam');
    });

    testWidgets('asks for a new customer; the owner is warned of a likely '
        'duplicate, and rejecting makes nothing', (tester) async {
      final f = factory();
      await asWorker(tester, f);
      await tester.tap(find.byKey(LabourHomeScreen.newCustomerKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(NewCustomerRequestScreen.customerNameKey),
        'Adam',
      );
      await tester.enterText(
        find.byKey(NewCustomerRequestScreen.phoneKey),
        '0750 123 4567',
      );
      await tester.enterText(
        find.byKey(NewDesignRequestScreen.nameKey),
        'Gate',
      );
      await tester.ensureVisible(
        find.byKey(CategoryChoice.chipKey(DesignKind.door)),
      );
      await tester.tap(find.byKey(CategoryChoice.chipKey(DesignKind.door)));
      await tester.ensureVisible(
        find.byKey(NewCustomerRequestScreen.submitKey),
      );
      await tester.tap(find.byKey(NewCustomerRequestScreen.submitKey));
      await tester.pumpAndSettle();
      final request = f.backend.asked.single;
      expect(request.kind, RequestKind.newCustomerDesign);

      await signOut(tester);
      await signIn(tester, 'soran@x.test', 'owner-pass');
      await tester.tap(find.byKey(ApprovalsButton.buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RequestTile.tileKey(request.id)));
      await tester.pumpAndSettle();
      expect(find.byKey(RequestScreen.duplicateKey), findsOneWidget);
      await tester.enterText(find.byKey(RequestScreen.noteKey), 'Same Adam');
      await tester.tap(find.byKey(RequestScreen.rejectKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reject-confirm')));
      await tester.pumpAndSettle();
      expect(f.backend.asked.single.status, RequestStatus.rejected);
      expect(f.backend.asked.single.decisionNote, 'Same Adam');
      expect(f.backend.customers.values.single.length, 1);
      expect(f.backend.designs.values.single.length, 1);
    });

    testWidgets('proposes a change: looking needs no permission, changing '
        'begins with Propose, and the design is not touched until the owner '
        'approves — then it is, once', (tester) async {
      final f = factory();
      final c = await asWorker(tester, f);
      await tester.tap(find.byKey(LabourHomeScreen.openKey('design-front')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(find.byKey(ProposalBar.proposeKey), findsOneWidget);
      final controller = c.read(workspaceProvider.notifier);
      final before = c.read(workspaceProvider).design.depthMm;
      // Looking only: a change is refused.
      controller.setDepth(before + 20);
      expect(c.read(workspaceProvider).design.depthMm, before);

      await tester.tap(find.byKey(ProposalBar.proposeKey));
      await tester.pumpAndSettle();
      controller.setDepth(before + 20);
      expect(c.read(workspaceProvider).design.depthMm, before + 20);
      await controller.save();
      expect(await recordKeys(), isEmpty, reason: 'nothing kept on the device');
      expect(f.backend.design(f.owner, 'design-front')!['depthMm'], before);

      await tester.tap(find.byKey(ProposalBar.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProposalBar.sendKey));
      await tester.pumpAndSettle();
      expect(find.text('Say what you changed.'), findsOneWidget);
      await tester.enterText(
        find.byKey(ProposalBar.describeKey),
        'Deeper frame',
      );
      await tester.tap(find.byKey(ProposalBar.sendKey));
      await tester.pumpAndSettle();
      expect(find.byType(LabourHomeScreen), findsOneWidget);
      final request = f.backend.asked.single;
      expect(request.kind, RequestKind.designChange);
      expect(request.baseRevision, 1);
      expect(request.proposed!['depthMm'], before + 20);
      expect(f.backend.design(f.owner, 'design-front')!['depthMm'], before);

      await signOut(tester);
      await signIn(tester, 'soran@x.test', 'owner-pass');
      await tester.tap(find.byKey(ApprovalsButton.buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RequestTile.tileKey(request.id)));
      await tester.pumpAndSettle();
      expect(find.byKey(RequestScreen.compareKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(RequestScreen.approveKey));
      await tester.tap(find.byKey(RequestScreen.approveKey));
      await tester.pumpAndSettle();
      expect(
        f.backend.design(f.owner, 'design-front')!['depthMm'],
        before + 20,
      );
      expect(f.backend.revisionOf(f.owner, 'design-front'), 2);
      expect(f.backend.approvals, 1);
      final onDevice = await DesignStore().load('design-front');
      expect(onDevice!.depthMm, before + 20);
      expect(onDevice.name, 'Front door');
    });

    testWidgets('a design taken away cannot be opened by its id', (
      tester,
    ) async {
      final f = factory();
      final c = await asWorker(tester, f);
      f.backend.current = f.owner;
      await f.backend.unassign('design-front', f.worker);
      f.backend.current = f.worker;
      await tester.tap(find.byKey(LabourHomeScreen.openKey('design-front')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsNothing);
      expect(find.text('That design is not assigned to you.'), findsOneWidget);
      expect(c.read(proposalProvider), isNull);
    });
  });

  group('what was on the device before accounts', () {
    Future<void> seedLocal() async {
      final store = DesignStore();
      final design = Design.fromJson(
        frontDoor(id: 'design-local', name: 'Old door'),
      );
      SharedPreferences.setMockInitialValues({
        '${DesignStore.designKeyPrefix}design-local': jsonEncode(
          design.toJson(),
        ),
        'proframe.language': 'en',
      });
      expect(await store.count(), 0);
    }

    testWidgets('an owner chooses to keep it aside: nothing is deleted, '
        'nothing is sent', (tester) async {
      await seedLocal();
      final f = factory();
      await openApp(tester, f.backend);
      await signIn(tester, 'soran@x.test', 'owner-pass');
      expect(find.byType(UnclaimedDataScreen), findsOneWidget);
      await tester.tap(find.byKey(UnclaimedDataScreen.keepKey));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith(DeviceData.archivePrefix)),
        hasLength(1),
      );
      expect(f.backend.design(f.owner, 'design-local'), isNull);
      // Signing out clears the cache and keeps the archive and the device's
      // own settings.
      await signOut(tester);
      expect(
        prefs.getKeys().where((k) => k.startsWith(DeviceData.archivePrefix)),
        hasLength(1),
      );
      expect(prefs.getString('proframe.language'), 'en');
    });

    testWidgets('a worker signing in moves it aside, never uploads it', (
      tester,
    ) async {
      await seedLocal();
      final f = factory();
      await openApp(tester, f.backend);
      await signIn(tester, 'ali@x.test', 'worker-pass');
      expect(find.byType(LabourHomeScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(await recordKeys(), isEmpty);
      expect(
        prefs.getKeys().where((k) => k.startsWith(DeviceData.archivePrefix)),
        hasLength(1),
      );
    });
  });

  group('in Central Kurdish, right to left', () {
    for (final size in const [Size(360, 740), Size(1280, 860)]) {
      testWidgets('signing in and a worker\'s home fit at ${size.width}', (
        tester,
      ) async {
        final f = factory();
        final c = await openApp(tester, f.backend, size: size);
        await tester.tap(find.byKey(LanguageButton.buttonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('کوردی (سۆرانی)'));
        await tester.pumpAndSettle();
        expect(
          Directionality.of(tester.element(find.byType(SignInScreen))),
          TextDirection.rtl,
        );
        expect(find.text('چوونەژوورەوە'), findsWidgets);
        expect(tester.takeException(), isNull);
        await signIn(tester, 'ali@x.test', 'worker-pass');
        expect(find.byType(LabourHomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final r in tester.allRenderObjects.whereType<RenderFlex>()) {
          expect(r.toStringShort(), isNot(contains('OVERFLOWING')));
        }
        expect(c.read(sessionProvider).value!.role, AccountRole.labour);
      });
    }
  });
}
