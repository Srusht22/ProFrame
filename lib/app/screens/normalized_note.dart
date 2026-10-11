import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// The quiet word that a reading put a standard design right: *Geometry
/// normalized for standard design.*
///
/// **Said, never asked.** Squaring a jamb drawn a few degrees out, standing
/// a lean up or trimming a corner drawn past is cleaning (see *Where the
/// line falls*), so it happens without a question; this only says it did,
/// so a line that moved under the user's pen is not a surprise. A small
/// pill at the head of the view, over the work and clear of every control,
/// that comes in, stands for a moment and goes on its own. It takes no tap
/// — everything under it works as it does without it — and nothing waits
/// on it.
///
/// **Only when something a person could see was put right.** It comes up
/// when [WorkspaceState.normalizedNotice] counts a new reading that moved a
/// line of a standard design by more than the hand can place one
/// (`Interpretation.noticeablyCorrected`) — never for the shake taken out
/// of every hand-drawn line, never for the same strokes twice, and never in
/// an angled design, whose slopes are meant and are not corrected.
class NormalizedNote extends ConsumerStatefulWidget {
  const NormalizedNote({super.key});

  /// What it says — the user's own words.
  static const message = 'Geometry normalized for standard design.';

  /// How long it stands, coming and going included.
  static const duration = Duration(milliseconds: 3200);

  @override
  ConsumerState<NormalizedNote> createState() => _NormalizedNoteState();
}

class _NormalizedNoteState extends ConsumerState<NormalizedNote>
    with SingleTickerProviderStateMixin {
  // Preserved: left to the controller, a device asking for less motion
  // squeezes the whole thing to a flicker, and the note would never be
  // read. It is shown still instead (see [build]).
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: NormalizedNote.duration,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// A reading has said it, and the work is not yet in view to show it on.
  bool _pending = false;

  /// Starts what is waiting once the work is in view, and puts back to
  /// wait what something has come up over.
  void _settle(bool inView) {
    if (!mounted) return;
    if (!inView) {
      if (_clock.isAnimating) {
        _clock.stop();
        _clock.value = 0;
        _pending = true;
      }
    } else if (_pending) {
      _pending = false;
      _clock.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workspaceProvider.select((s) => s.normalizedNotice), (
      before,
      now,
    ) {
      if (now > (before ?? 0)) setState(() => _pending = true);
    });
    // **Shown on the work, never behind something over it.** A reading
    // usually brings something up straight away — the sizes, which fill a
    // phone, or an alert — and a note played out behind it would never be
    // seen. So it is only shown while the workspace is the route in front
    // and no alert is up: held back until then, and put back to wait if
    // something comes up over it while it stands. It is said once the user
    // is back at the drawing it is about.
    final inFront = ModalRoute.of(context)?.isCurrent ?? true;
    final alert = ref.watch(
      workspaceProvider.select((s) => s.waitingOnAnAlert),
    );
    final inView = inFront && !alert;
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle(inView));
    final palette = context.palette;
    final still = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) {
          final t = _clock.value;
          if (!_clock.isAnimating || t <= 0 || t >= 1) {
            return const SizedBox.shrink();
          }
          // In over the first tenth, out over the last fifth; still, it
          // is simply there for the time and then not.
          final shown = still
              ? 1.0
              : t < 0.1
              ? Curves.easeOut.transform(t / 0.1)
              : t > 0.8
              ? 1 - Curves.easeIn.transform((t - 0.8) / 0.2)
              : 1.0;
          return Opacity(
            opacity: shown,
            child: Transform.translate(
              offset: Offset(0, still ? 0 : (1 - shown) * -6),
              child: child,
            ),
          );
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              key: const ValueKey('normalized-note'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: palette.raised.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.hairline),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 15, color: palette.primary),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      context.l10n.normalizedMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
