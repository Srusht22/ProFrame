import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/model/design_completion.dart';
import '../../domain/model/new_design_setup.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/text/names.dart';
import '../l10n/l10n.dart';
import '../state/access.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customer_screen.dart';
import 'design_name_screen.dart';

/// What to do after a design is completed.
enum AfterCompletion {
  /// Begin another design for the same customer.
  newDesign,

  /// Stay with the design just completed.
  view,

  /// Go to the customer's page.
  backToCustomer,
}

/// The strip under the drawing that says whether the design is a draft or
/// completed, and holds **Complete!**.
///
/// It is part of the drawing's own workspace, under the work in every view,
/// so finishing a design is where designing it is. Pressing **Complete!**
/// asks the workspace to read, check, complete and save the design
/// ([WorkspaceController.complete]); only once that has really been saved
/// is it said to be done, with **New Design** — for the same customer — the
/// first thing offered next.
class CompleteBar extends ConsumerStatefulWidget {
  final bool narrow;

  const CompleteBar({super.key, this.narrow = false});

  static const barKey = ValueKey('complete-bar');
  static const buttonKey = ValueKey('complete-button');
  static const stateKey = ValueKey('complete-state');

  /// The words on the button.
  static const label = 'Complete!';

  @override
  ConsumerState<CompleteBar> createState() => _CompleteBarState();
}

class _CompleteBarState extends ConsumerState<CompleteBar> {
  /// From the first press until what it shows is put away.
  bool _busy = false;

  /// While the design is being read, checked and saved.
  bool _saving = false;

  /// Busy from the first press until what it shows is put away: a second
  /// press — however quickly it follows, even before the answer is drawn —
  /// completes nothing again and opens nothing twice.
  Future<void> _complete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _completeOnce();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeOnce() async {
    final controller = ref.read(workspaceProvider.notifier);
    setState(() => _saving = true);
    final Completion outcome;
    try {
      outcome = await controller.complete();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    switch (outcome.result) {
      case CompletionResult.busy:
        return;
      case CompletionResult.incomplete:
        await showDialog<void>(
          context: context,
          builder: (_) => NotCompleteDialog(outcome: outcome),
        );
      case CompletionResult.failed:
        await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            key: CompletedDialog.failedKey,
            title: Text(context.l10n.notCompleted),
            content: Text(outcome.message ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: Text(context.l10n.fwOk),
              ),
            ],
          ),
        );
      case CompletionResult.completed:
        final next = await showDialog<AfterCompletion>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CompletedDialog(design: outcome.design!),
        );
        if (!mounted || next == null) return;
        _go(next, outcome.design!);
    }
  }

  /// Where the user goes from a completed design: never back through the
  /// customers to begin another.
  void _go(AfterCompletion next, Design design) {
    final navigator = Navigator.of(context);
    final owner = design.customerId;
    switch (next) {
      case AfterCompletion.view:
        return;
      case AfterCompletion.newDesign:
        // The same customer, asked only the new design's name and then its
        // category; the design just completed is kept as it is, and the
        // way back from the new one is the customer's page.
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DesignNameScreen(
              setup: NewDesignSetup(
                customerId: owner,
                customer: design.customer,
              ),
            ),
          ),
        );
      case AfterCompletion.backToCustomer:
        if (owner == null) {
          navigator.popUntil((r) => r.isFirst);
          return;
        }
        var found = false;
        navigator.popUntil((r) {
          if (r.settings.name == CustomerScreen.routeName(owner)) found = true;
          return found || r.isFirst;
        });
        if (!found) navigator.push(CustomerScreen.route(owner));
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = ref.watch(workspaceProvider.select((s) => s.design));
    if (design.isUnsupported) return const SizedBox.shrink();
    final completed = DesignCompletion.isCompleted(design);
    final may = ref.offers(Capability.designsEdit);
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Material(
      key: CompleteBar.barKey,
      color: p.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.narrow ? 10 : 16,
          vertical: 6,
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.verified_outlined : Icons.edit_note,
              size: 18,
              color: completed ? p.primary : p.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                completed
                    ? context.l10n.completedAndSaved
                    : widget.narrow
                    ? context.l10n.stageDraft
                    : context.l10n.draftHint,
                key: CompleteBar.stateKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: completed ? p.primary : p.muted,
                  fontWeight: completed ? FontWeight.w600 : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: CompleteBar.buttonKey,
              onPressed: _busy || !may ? null : _complete,
              style: FilledButton.styleFrom(
                backgroundColor: p.band,
                foregroundColor: AppTheme.accent,
                visualDensity: VisualDensity.compact,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(context.l10n.completeButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a design is not complete yet, each thing still to do said.
class NotCompleteDialog extends StatelessWidget {
  final Completion outcome;

  const NotCompleteDialog({super.key, required this.outcome});

  static const dialogKey = ValueKey('not-complete-dialog');

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: dialogKey,
    title: Text(context.l10n.notCompleteYet),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(outcome.message ?? ''),
          const SizedBox(height: 8),
          for (final m in outcome.missing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.l10n.bulleted(m)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.fwOk),
      ),
    ],
  );
}

/// The design just completed and saved: which one, and what to do next —
/// **New Design** first.
class CompletedDialog extends ConsumerStatefulWidget {
  final Design design;

  const CompletedDialog({super.key, required this.design});

  static const dialogKey = ValueKey('completed-dialog');
  static const failedKey = ValueKey('completion-failed-dialog');
  static const nameKey = ValueKey('completed-design-name');
  static const newDesignKey = ValueKey('completed-new-design');
  static const viewKey = ValueKey('completed-view');
  static const backKey = ValueKey('completed-back-to-customer');

  static const success = 'Design completed and saved successfully.';

  @override
  ConsumerState<CompletedDialog> createState() => _CompletedDialogState();
}

class _CompletedDialogState extends ConsumerState<CompletedDialog> {
  /// Set by the first choice, so a second press of the same button — or of
  /// another — does nothing.
  bool _chosen = false;

  void _choose(AfterCompletion next) {
    if (_chosen) return;
    _chosen = true;
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.design;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final owner = d.customerId;
    final customer = owner == null
        ? d.customer
        : ref.watch(customerNameProvider(owner)).value ?? d.customer;
    final may = ref.offers(Capability.designsCreate);
    return AlertDialog(
      key: CompletedDialog.dialogKey,
      icon: Icon(Icons.check_circle, color: p.primary, size: 36),
      title: Text(context.l10n.completedSuccess, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            d.shownNameIn(context.words),
            key: CompletedDialog.nameKey,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            [
              d.kind.labelIn(context.words),
              if (customer != null && customer.isNotEmpty)
                context.l10n.forCustomer(customer),
              context.l10n.openingsCount(d.openings.length),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: p.muted),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        FilledButton.icon(
          key: CompletedDialog.newDesignKey,
          autofocus: true,
          onPressed: owner == null || !may
              ? null
              : () => _choose(AfterCompletion.newDesign),
          style: FilledButton.styleFrom(
            backgroundColor: p.band,
            foregroundColor: AppTheme.accent,
          ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.newDesign),
        ),
        TextButton(
          key: CompletedDialog.viewKey,
          onPressed: () => _choose(AfterCompletion.view),
          child: Text(context.l10n.viewCompletedDesign),
        ),
        TextButton(
          key: CompletedDialog.backKey,
          onPressed: () => _choose(AfterCompletion.backToCustomer),
          child: Text(context.l10n.backToCustomer),
        ),
      ],
    );
  }
}
