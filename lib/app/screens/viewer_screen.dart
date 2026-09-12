import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/layout/responsive.dart';
import '../../core/units/length_unit.dart';
import '../../domain/design_document.dart';
import '../../domain/panel.dart';
import '../../domain/product/profile_system.dart';
import '../rendering/animated_design_view.dart';
import '../rendering/design_renderer.dart';
import '../rendering/isometric_renderer.dart';
import '../state/design_controller.dart';
import '../state/viewer_controller.dart';
import '../widgets/notice.dart';

/// The 2.5D preview.
///
/// Reads the same [DesignDocument] the canvas edits, so going back and forth
/// is lossless however many times it is done (spec Phase 3, item 4) — there is
/// nothing to convert, because there is only ever one model.
class ViewerScreen extends ConsumerWidget {
  /// Returns to the canvas.
  final VoidCallback onBack;

  /// Which renderer draws the design. Injected so a real 3D engine can be
  /// swapped in without this screen changing (spec Phase 3, item 1).
  final DesignRenderer renderer;

  const ViewerScreen({
    required this.onBack,
    this.renderer = const IsometricRenderer(),
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = ref.watch(designControllerProvider).design;
    final viewer = ref.watch(viewerControllerProvider);
    final profile = GenericProfiles.byId(design.profile.id) ??
        GenericProfiles.defaultFor(design.material);

    return ResponsiveBuilder(
      builder: (context, size) {
        final sideBySide = size.widthClass.hasRoomForSidePanel &&
            (size.isLandscape || size.widthClass.isExpanded);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to edit',
              onPressed: onBack,
            ),
            title: Text(renderer.label),
            actions: [
              if (viewer.openPanels.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_fullscreen),
                  tooltip: 'Close every panel',
                  onPressed:
                      ref.read(viewerControllerProvider.notifier).closeAll,
                ),
              IconButton(
                icon: const Icon(Icons.center_focus_strong),
                tooltip: 'Fit the view',
                onPressed:
                    ref.read(viewerControllerProvider.notifier).resetView,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _SummaryStrip(design: design),
                Expanded(
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _Viewer(
                                renderer: renderer,
                                design: design,
                                profile: profile,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: AppSizing.propertiesPanelWidth,
                              child: _SidePanel(design: design),
                            ),
                          ],
                        )
                      : _Viewer(
                          renderer: renderer,
                          design: design,
                          profile: profile,
                        ),
                ),
                _ViewerFooter(design: design),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The drawing surface, with pinch to zoom and drag to pan.
class _Viewer extends ConsumerStatefulWidget {
  final DesignRenderer renderer;
  final DesignDocument design;
  final ProfileSystem profile;

  const _Viewer({
    required this.renderer,
    required this.design,
    required this.profile,
  });

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer> {
  double _zoomAtGestureStart = 1;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerControllerProvider);
    final controller = ref.read(viewerControllerProvider.notifier);

    return ColoredBox(
      color: AppColors.cream,
      child: GestureDetector(
        // One recogniser for both: a scale gesture with a single pointer is a
        // pan, which is how pinch and drag coexist without fighting.
        onScaleStart: (_) => _zoomAtGestureStart = viewer.zoom,
        onScaleUpdate: (details) {
          if (details.pointerCount > 1) {
            controller.setZoom(_zoomAtGestureStart * details.scale);
          }
          if (details.focalPointDelta != Offset.zero) {
            controller.panBy(details.focalPointDelta);
          }
        },
        child: AnimatedDesignView(
          renderer: widget.renderer,
          design: widget.design,
          profile: widget.profile,
          finish: Color(widget.design.finish.argb),
          openPanels: viewer.openPanels,
          zoom: viewer.zoom,
          pan: viewer.pan,
          onPanelTapped: (panelId) => _handleTap(context, panelId),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String panelId) {
    final panel = widget.design.panelById(panelId);
    if (panel == null) return;

    // A note is the more specific thing to want, so it wins over opening.
    if (panel.hasNote) {
      _showNote(context, panel);
      return;
    }
    if (panel.behaviour.isOpening) {
      ref.read(viewerControllerProvider.notifier).toggle(panelId);
      return;
    }
    // A fixed panel does not move. Saying so is better than a dead tap.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This panel is ${panel.behaviour.code} — fixed, so it does not open.',
        ),
      ),
    );
  }

  void _showNote(BuildContext context, Panel panel) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${panel.widthMm.round()} × ${panel.heightMm.round()} mm '
                  '· ${panel.behaviour.code}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Notice(title: 'Note', message: panel.note),
                if (panel.behaviour.isOpening) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Open this panel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref
                          .read(viewerControllerProvider.notifier)
                          .toggle(panel.id);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Dimensions, material, colour and the design note (spec Phase 3, item 4).
class _SummaryStrip extends StatelessWidget {
  final DesignDocument design;

  const _SummaryStrip({required this.design});

  @override
  Widget build(BuildContext context) {
    const unit = LengthUnit.centimetre;
    final width = design.overallWidth;
    final height = design.overallHeight;
    final size = width == null || height == null
        ? 'Not measured'
        : '${unit.format(width.millimetres)} × '
            '${unit.format(height.millimetres)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Each chip is capped by the room actually available, so a long
          // finish name or a translated label cannot push the strip off the
          // side of a phone.
          final cap = constraints.maxWidth;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(icon: Icons.straighten, text: size, maxWidth: cap),
              // Its own chip rather than a suffix on the size: appended, it
              // made the one string long enough to overflow, and it is the
              // half that must not be the half that gets clipped
              // (spec section 2).
              if (!design.hasConfirmedSize)
                _Chip(
                  icon: Icons.help_outline,
                  text: 'Not confirmed',
                  maxWidth: cap,
                ),
              _Chip(
                icon: Icons.layers_outlined,
                text: design.material.label,
                maxWidth: cap,
              ),
              _Chip(
                icon: Icons.palette_outlined,
                text: design.finish.name,
                maxWidth: cap,
              ),
              // Handing is meaningless without it, so it is permanently on
              // screen here too (spec Phase 3, item 2).
              _Chip(
                icon: Icons.visibility_outlined,
                text: design.viewedFrom.label,
                maxWidth: cap,
              ),
              if (design.hasDesignNote) _NoteChip(note: design.designNote),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final double maxWidth;

  const _Chip({
    required this.icon,
    required this.text,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.mutedText),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}

class _NoteChip extends StatelessWidget {
  final String note;

  const _NoteChip({required this.note});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        icon: const Icon(Icons.sticky_note_2, size: 18),
        label: const Text('Design note'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          backgroundColor: AppColors.surface,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Notice(title: 'Design note', message: note),
            ),
          ),
        ),
      );
}

/// What sits beside the viewer where there is room for it.
class _SidePanel extends StatelessWidget {
  final DesignDocument design;

  const _SidePanel({required this.design});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opening = design.panels.where((p) => p.behaviour.isOpening).toList();

    return ColoredBox(
      color: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panels', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final panel in design.panels)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The factory code, so the state reads without decoding a
                    // symbol or a colour.
                    SizedBox(
                      width: 32,
                      child: Text(
                        panel.behaviour.code,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${panel.widthMm.round()} × '
                            '${panel.heightMm.round()} mm',
                          ),
                          if (panel.opening != null)
                            Text(
                              panel.opening!.describe(design.viewedFrom),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedText),
                            ),
                          if (panel.hasMesh || panel.isEmpty)
                            Text(
                              [
                                if (panel.hasMesh) 'Mesh',
                                if (panel.isEmpty) 'Empty',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedText),
                            ),
                          if (panel.hasNote)
                            Text(
                              panel.note,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedText),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (opening.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              const Notice(
                message: 'Nothing in this design opens. Long-press a panel on '
                    'the drawing to make it a Z.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The honest footer: what this preview is, and what it is not.
class _ViewerFooter extends StatelessWidget {
  final DesignDocument design;

  const _ViewerFooter({required this.design});

  @override
  Widget build(BuildContext context) {
    final opening = design.panels.where((p) => p.behaviour.isOpening).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Text(
        opening == 0
            ? 'Preview only — the profiles are generic, not manufacturing data.'
            : 'Tap a Z panel to open it. Preview only — the profiles are '
                'generic, not manufacturing data.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.mutedText),
      ),
    );
  }
}
