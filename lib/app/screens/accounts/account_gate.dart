import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import '../customers_screen.dart';
import 'account_ui.dart';
import 'auth_screens.dart';
import 'labour_home_screen.dart';

/// Where the application goes once its mark has played.
///
/// Without a backend it is the customers, on one device, as it always was.
/// With one, it is whoever the backend says is signed in: nobody — the
/// sign-in; an owner — their customers; a worker — their own home, which
/// holds nothing of the owner's. Which of these is never chosen here: it is
/// the account the backend answered with.
class AccountGate extends ConsumerWidget {
  const AccountGate({super.key});

  static const loadingKey = ValueKey('account-gate-loading');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudModeProvider)) return const CustomersScreen();
    final l = context.l10n;
    if (ref.watch(recoveryProvider)) return const NewPasswordScreen();
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return Scaffold(
        key: loadingKey,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.clSigningIn),
            ],
          ),
        ),
      );
    }
    if (session.hasError) {
      return SignInScreen(notice: problemOf(context, session.error!));
    }
    final account = session.value;
    if (account == null) return const SignInScreen();
    if (!account.isActive) {
      return _Suspended(name: account.name);
    }
    if (account.isOwner) {
      return ref.watch(unclaimedDataProvider)
          ? const UnclaimedDataScreen()
          : const CustomersScreen();
    }
    return const LabourHomeScreen();
  }
}

class _Suspended extends ConsumerWidget {
  final String name;
  const _Suspended({required this.name});

  static const signOutKey = ValueKey('suspended-sign-out');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.appTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
            heading: l.clSuspendedTitle,
            lead: l.clSuspendedBody(name),
          ),
          FilledButton.icon(
            key: signOutKey,
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l.clSignOut),
          ),
        ],
      ),
    );
  }
}
