import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../screens/accounts/account_ui.dart';
import '../state/cloud.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// Under the drawing, for a worker with an assigned design open: looking at
/// it, or proposing a change to it.
///
/// **A proposal never changes the design.** It is drawn here, in the
/// workspace, and sent as a request with the whole proposed design and the
/// revision it was drawn from. Nothing is kept on the device, and the
/// backend refuses a worker any write to the design itself; the owner
/// approves or rejects it.
class ProposalBar extends ConsumerStatefulWidget {
  final bool narrow;
  const ProposalBar({super.key, this.narrow = false});

  static const proposeKey = ValueKey('proposal-propose');
  static const submitKey = ValueKey('proposal-submit');
  static const discardKey = ValueKey('proposal-discard');
  static const describeKey = ValueKey('proposal-describe');
  static const sendKey = ValueKey('proposal-send');

  @override
  ConsumerState<ProposalBar> createState() => _ProposalBarState();
}

class _ProposalBarState extends ConsumerState<ProposalBar> {
  bool _busy = false;
  final _key = newClientKey();

  void _discard() {
    final p = ref.read(proposalProvider);
    if (p == null) return;
    ref.read(proposalProvider.notifier).discard();
    final original = p.original;
    if (original != null) {
      ref.read(workspaceProvider.notifier).openDesign(original);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final p = ref.read(proposalProvider);
    if (p == null) return;
    final description = await showDialog<String>(
      context: context,
      builder: (_) => const _Describe(),
    );
    if (description == null || !mounted) return;
    final controller = ref.read(workspaceProvider.notifier);
    if (ref.read(workspaceProvider).needsReading) controller.readDrawing();
    final proposed = ref.read(workspaceProvider).design.toJson();
    setState(() => _busy = true);
    try {
      await ref
          .read(backendProvider)!
          .requestChange(
            designId: p.designId,
            baseRevision: p.revision,
            proposed: proposed,
            description: description,
            clientKey: _key,
          );
      ref.read(cloudRevisionProvider.notifier).changed();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.clChangeSent)));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problemOf(context, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(proposalProvider);
    if (p == null) return const SizedBox.shrink();
    final l = context.l10n;
    final palette = context.palette;
    final active = p.active;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.notice,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.edit_note : Icons.lock_outline,
                  color: palette.onNotice,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    active ? l.clProposing : l.clViewingAssigned,
                    style: TextStyle(color: palette.onNotice),
                  ),
                ),
              ],
            ),
          ),
          if (!active)
            FilledButton.icon(
              key: ProposalBar.proposeKey,
              onPressed: () => ref.read(proposalProvider.notifier).begin(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.accent,
              ),
              icon: const Icon(Icons.edit),
              label: Text(l.clProposeChange),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: ProposalBar.discardKey,
                  onPressed: _busy ? null : _discard,
                  child: Text(l.clDiscard),
                ),
                FilledButton.icon(
                  key: ProposalBar.submitKey,
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.accent,
                  ),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(l.clSubmitForApproval),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Describe extends StatefulWidget {
  const _Describe();

  @override
  State<_Describe> createState() => _DescribeState();
}

class _DescribeState extends State<_Describe> {
  final _text = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.clSubmitForApproval),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: ProposalBar.describeKey,
          controller: _text,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.clWhatChanged,
            errorText: _problem,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actCancel),
        ),
        FilledButton(
          key: ProposalBar.sendKey,
          onPressed: () {
            if (_text.text.trim().isEmpty) {
              setState(() => _problem = l.clWhatChangedNeeded);
              return;
            }
            Navigator.of(context).pop(_text.text.trim());
          },
          child: Text(l.clSendRequest),
        ),
      ],
    );
  }
}
