import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/recognition/geometry_feedback.dart';
import '../../domain/recognition/geometry_validation.dart';
import '../l10n/l10n.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What is wrong with an angled design's geometry, said under the drawing.
///
/// An Angled / Asymmetrical design is never squared, so its geometry is
/// checked instead (`GeometryValidation`). The check used to be made on
/// every reading and put away unseen; this is where the user hears of it.
///
/// - **Said, never mended.** Nothing here changes the design: it names the
///   part that needs attention and, on **Show me**, lights that part up on
///   the drawing for a moment — the same passing highlight the questions
///   under the drawing use, never a colour written into the design.
/// - **Always about the geometry on the screen.** It reads
///   [WorkspaceState.geometryFeedback], worked out from the design as it
///   now is, so a problem put right is gone from here the moment the
///   design that had it is.
/// - **Not a gate.** Nothing waits on it, it asks nothing, and it folds down
///   to one line so the drawing keeps its room.
class GeometryCheckPanel extends ConsumerStatefulWidget {
  final ValueChanged<Set<String>>? onHighlight;

  const GeometryCheckPanel({super.key, this.onHighlight});

  static const panelKey = ValueKey('geometry-check');
  static const toggleKey = ValueKey('geometry-check-toggle');
  static ValueKey<String> showKey(int i) => ValueKey('geometry-check-show-$i');

  @override
  ConsumerState<GeometryCheckPanel> createState() => _GeometryCheckState();
}

class _GeometryCheckState extends ConsumerState<GeometryCheckPanel> {
  bool _open = false;

  /// The notice whose part is lit on the drawing, if any.
  int? _shown;

  void _show(int i, GeometryNotice notice) {
    final again = _shown == i;
    setState(() => _shown = again ? null : i);
    widget.onHighlight?.call(again ? const {} : notice.showIds);
    // The model is not where a part is pointed out: the drawings are.
    final controller = ref.read(workspaceProvider.notifier);
    if (!again && ref.read(workspaceProvider).view == WorkspaceView.model) {
      controller.showView(WorkspaceView.plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = ref.watch(
      workspaceProvider.select((s) => s.geometryFeedback),
    );
    // A new design is checked afresh: whatever was lit belonged to the
    // check before it.
    ref.listen(workspaceProvider.select((s) => s.geometryFeedback), (
      before,
      now,
    ) {
      if (_shown != null) {
        setState(() => _shown = null);
        widget.onHighlight?.call(const {});
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: feedback.isEmpty
          ? const SizedBox.shrink(key: ValueKey('valid'))
          : AnimatedSize(
              key: const ValueKey('problems'),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _panel(context, feedback),
            ),
    );
  }

  Widget _panel(BuildContext context, GeometryFeedback feedback) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final count = feedback.notices.length;
    return Container(
      key: GeometryCheckPanel.panelKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.notice,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: GeometryCheckPanel.toggleKey,
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _SeverityIcon(error: feedback.hasErrors, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.titleIn(context.words),
                          style: text.titleSmall?.copyWith(
                            color: palette.onNotice,
                          ),
                        ),
                        if (!_open)
                          Text(
                            count == 1
                                ? feedback.notices.single.messageIn(
                                    context.words,
                                  )
                                : context.l10n.gcMore(
                                    feedback.notices.first.messageIn(
                                      context.words,
                                    ),
                                    count - 1,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: palette.onNotice.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _counted(context.l10n, feedback),
                    style: text.labelSmall?.copyWith(
                      color: palette.onNotice.withValues(alpha: 0.8),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_more : Icons.expand_less,
                    color: palette.onNotice,
                    semanticLabel: _open
                        ? context.l10n.gcFewerDetails
                        : context.l10n.gcMoreDetails,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 2, 8, 6),
              child: Text(
                feedback.summaryIn(context.words),
                style: text.bodySmall?.copyWith(
                  color: palette.onNotice.withValues(alpha: 0.85),
                ),
              ),
            ),
            // Never more than a third of the screen, so the drawing the
            // problems are about stays in view above them.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 3,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (i, notice) in feedback.notices.indexed)
                      _NoticeRow(
                        notice: notice,
                        showKey: GeometryCheckPanel.showKey(i),
                        shown: _shown == i,
                        onShow: notice.showIds.isEmpty
                            ? null
                            : () => _show(i, notice),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _counted(AppLocalizations l, GeometryFeedback feedback) => [
    if (feedback.errors > 0) l.gcErrors(feedback.errors),
    if (feedback.warnings > 0) l.gcWarnings(feedback.warnings),
  ].join(' · ');
}

class _NoticeRow extends StatelessWidget {
  final GeometryNotice notice;
  final Key showKey;
  final bool shown;
  final VoidCallback? onShow;

  const _NoticeRow({
    required this.notice,
    required this.showKey,
    required this.shown,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: 6, right: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SeverityIcon(error: notice.isError, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.severity == GeometryProblemSeverity.error
                      ? context.l10n.gcError
                      : context.l10n.gcWarning,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.muted),
                ),
                Text(
                  notice.messageIn(context.words),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (onShow != null)
            TextButton.icon(
              key: showKey,
              onPressed: onShow,
              icon: Icon(
                shown
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
              ),
              label: Text(
                shown ? context.l10n.actHide : context.l10n.actShowMe,
              ),
            ),
        ],
      ),
    );
  }
}

class _SeverityIcon extends StatelessWidget {
  final bool error;
  final double size;

  const _SeverityIcon({required this.error, required this.size});

  @override
  Widget build(BuildContext context) => Icon(
    error ? Icons.error_outline : Icons.warning_amber_rounded,
    size: size,
    color: error
        ? Theme.of(context).colorScheme.error
        : context.palette.onNotice,
    semanticLabel: error ? context.l10n.gcError : context.l10n.gcWarning,
  );
}
