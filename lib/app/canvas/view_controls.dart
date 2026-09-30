import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Closer, further, the whole thing, and — where a view has one — the view
/// it was first shown from: the same four buttons, in the same place, on the
/// drawing, the technical drawing and the model.
///
/// Each view had its own: a column with a fit on the drawing, a column with
/// no fit at the top of the technical drawing, and a row with both on the
/// model. Three answers to one question is three things to learn, so there
/// is one, a row along the foot of the view, in its right-hand corner — the
/// band the model is framed clear of.
///
/// It is laid over a view, never inside the view's own pointer handling: a
/// press on a button is a press on the button and nothing else, so it can
/// never also pick, put down or draw on what is under it.
class ViewControls extends StatelessWidget {
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  /// The view it was first shown from, where the view has one.
  final VoidCallback? onReset;

  /// What the fit button says it does.
  final String fitTooltip;

  const ViewControls({
    super.key,
    required this.onIn,
    required this.onOut,
    required this.onFit,
    this.onReset,
    this.fitTooltip = 'Fit to the view',
  });

  static const fitKey = ValueKey('view-fit');
  static const resetKey = ValueKey('view-reset');
  static const inKey = ValueKey('view-zoom-in');
  static const outKey = ValueKey('view-zoom-out');

  @override
  Widget build(BuildContext context) {
    final colour = context.palette.primary;
    Widget button(Key key, IconData icon, String tip, VoidCallback onTap) =>
        IconButton(
          key: key,
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          tooltip: tip,
          color: colour,
          visualDensity: VisualDensity.compact,
        );
    return Material(
      color: context.palette.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(inKey, Icons.add, 'Zoom in', onIn),
            button(outKey, Icons.remove, 'Zoom out', onOut),
            button(fitKey, Icons.fit_screen_outlined, fitTooltip, onFit),
            if (onReset case final reset?)
              button(
                resetKey,
                Icons.restart_alt_rounded,
                'Reset the view',
                reset,
              ),
          ],
        ),
      ),
    );
  }
}
