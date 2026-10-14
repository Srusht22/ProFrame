import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/accounts/accounts.dart';
import '../../../infrastructure/cloud/backend.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import '../../theme/app_theme.dart';
import '../appearance_button.dart';
import '../language_button.dart';

/// A screen of the accounts: the house band across the top with the
/// language and the appearance, and its content in a column no wider than
/// reads well.
class AccountScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floating;
  final bool scroll;

  const AccountScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floating,
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
          child: child,
        ),
      ),
    );
    return Scaffold(
      backgroundColor: palette.shell,
      appBar: AppBar(
        backgroundColor: palette.band,
        foregroundColor: palette.onBand,
        title: Text(title, maxLines: 2),
        actions: [
          ...actions,
          LanguageButton(colour: palette.onBand),
          AppearanceButton(colour: palette.onBand),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: floating,
      body: SafeArea(child: scroll ? SingleChildScrollView(child: body) : body),
    );
  }
}

/// The house mark over a sign-in form: the green band and the cream name.
class AuthHeading extends StatelessWidget {
  final String heading;
  final String? lead;

  const AuthHeading({super.key, required this.heading, this.lead});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: text.headlineSmall?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (lead != null) ...[
          const SizedBox(height: 6),
          Text(lead!, style: text.bodyMedium?.copyWith(color: palette.muted)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// A card a form stands on.
class FormCard extends StatelessWidget {
  final List<Widget> children;
  const FormCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: context.palette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: context.palette.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// What went wrong, in the theme's error colour, under a form.
class FormProblem extends StatelessWidget {
  final String? message;
  const FormProblem(this.message, {super.key});

  static const problemKey = ValueKey('form-problem');

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              m,
              key: problemKey,
              style: TextStyle(color: error),
            ),
          ),
        ],
      ),
    );
  }
}

/// A primary button that shows it is working, and takes no second press
/// meanwhile.
class BusyButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.arrow_forward),
    label: Text(label),
  );
}

/// A label on a coloured ground, saying a state in words and by its mark —
/// never by colour alone.
class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color colour;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.colour,
  });

  factory StatusChip.request(BuildContext context, RequestStatus status) {
    final l = context.l10n;
    final palette = context.palette;
    return switch (status) {
      RequestStatus.pending => StatusChip(
        label: l.clStatusPending,
        icon: Icons.hourglass_top,
        colour: AppTheme.selection,
      ),
      RequestStatus.approved => StatusChip(
        label: l.clStatusApproved,
        icon: Icons.check_circle_outline,
        colour: palette.primary,
      ),
      RequestStatus.rejected => StatusChip(
        label: l.clStatusRejected,
        icon: Icons.cancel_outlined,
        colour: Theme.of(context).colorScheme.error,
      ),
      RequestStatus.cancelled => StatusChip(
        label: l.clStatusCancelled,
        icon: Icons.block,
        colour: palette.muted,
      ),
      RequestStatus.failed => StatusChip(
        label: l.clStatusFailed,
        icon: Icons.report_problem_outlined,
        colour: Theme.of(context).colorScheme.error,
      ),
    };
  }

  factory StatusChip.account(BuildContext context, AccountStatus status) =>
      status == AccountStatus.active
      ? StatusChip(
          label: context.l10n.clWorkerActive,
          icon: Icons.check_circle_outline,
          colour: context.palette.primary,
        )
      : StatusChip(
          label: context.l10n.clWorkerSuspended,
          icon: Icons.pause_circle_outline,
          colour: context.palette.muted,
        );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: colour.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: colour.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colour),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
      ],
    ),
  );
}

/// What a request is, in words.
String requestKindIn(AppLocalizations l, RequestKind kind) => switch (kind) {
  RequestKind.newDesign => l.clKindNewDesign,
  RequestKind.newCustomerDesign => l.clKindNewCustomer,
  RequestKind.designChange => l.clKindChange,
};

/// A date and time, as a card writes them.
String whenIn(AppLocalizations l, DateTime? at) {
  if (at == null) return '';
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.day} ${shortMonth(l, t.month)} ${t.year}, '
      '${two(t.hour)}:${two(t.minute)}';
}

/// What an error from the backend says, in the screen's language.
String problemOf(BuildContext context, Object error) => switch (error) {
  final BackendError e => e.messageIn(context.words),
  _ => userMessageOf(context, error),
};

/// A screen only an owner may open. Anybody else — a worker who reached it
/// by any route — is told so, and shown nothing of it. The backend refuses
/// them whatever this shows.
class OwnerOnly extends ConsumerWidget {
  final Widget child;
  const OwnerOnly({super.key, required this.child});

  static const refusedKey = ValueKey('owner-only-refused');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudModeProvider)) return child;
    final account = ref.watch(sessionProvider).value;
    if (account != null && account.isOwner && account.isActive) return child;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.clOwnerOnly,
            key: refusedKey,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
