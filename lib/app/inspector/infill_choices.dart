import 'package:flutter/material.dart';

import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../../domain/model/infill.dart';
import '../../domain/model/materials.dart';
import '../theme/app_theme.dart';
import 'colour_picker.dart';

/// What fills a part, as the user says it: glass or panel.
enum Fill {
  glass('Glass'),
  panel('Panel');

  const Fill(this.label);
  final String label;

  /// Which of the two [finish] is, or null for anything else — a louvre, a
  /// mesh — or nothing said.
  static Fill? of(Finish? finish) {
    if (finish == null) return null;
    if (Infill.isGlass(finish)) return glass;
    if (Infill.isPanel(finish)) return panel;
    return null;
  }
}

/// The looks a part can be given once it is said to be [fill]: the glass a
/// joiner orders by name, or the colours a panel comes in — and **Custom**
/// for anything else.
///
/// Nothing is chosen for the user: with [finish] null, no swatch is marked,
/// and it is their tap that says what the part is.
class LookChoices extends StatefulWidget {
  final Fill fill;

  /// What the part is filled with now, or null while nothing is said.
  final Finish? finish;
  final ValueChanged<Finish> onChanged;

  const LookChoices({
    super.key,
    required this.fill,
    required this.finish,
    required this.onChanged,
  });

  @override
  State<LookChoices> createState() => _LookChoicesState();
}

class _LookChoicesState extends State<LookChoices> {
  bool _custom = false;

  @override
  void didUpdateWidget(LookChoices old) {
    super.didUpdateWidget(old);
    if (old.fill != widget.fill) _custom = false;
  }

  @override
  Widget build(BuildContext context) {
    final finish = widget.finish;
    final isThisFill = Fill.of(finish) == widget.fill;
    final named = switch (widget.fill) {
      Fill.glass => [
        for (final look in GlassLook.values) (look.label, look.finish),
      ],
      Fill.panel => [
        for (final colour in PanelColour.values) (colour.label, colour.finish),
      ],
    };
    final isNamed = isThisFill && named.any((option) => option.$2 == finish);
    final custom = _custom || (isThisFill && !isNamed);
    // The colour the custom swatch shows, and the picker starts from: the
    // part's own where it is the user's own, or a neutral grey that says
    // nothing about the answer — never a named look's, which would make
    // Custom look like that look.
    final customColour = isThisFill && !isNamed ? finish!.colour : 0xFFB5B9BB;

    Finish customOf(int colour) => switch (widget.fill) {
      // A glass given a colour of its own is tinted to it: clear glass
      // lets nearly all the light through, so its colour would not show.
      Fill.glass => Finish(
        colour: colour,
        material: isThisFill && finish!.material != MaterialKind.clearGlass
            ? finish.material
            : MaterialKind.tintedGlass,
      ),
      Fill.panel => Finish(colour: colour, material: MaterialKind.panel),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, option) in named)
              LookSwatch(
                key: ValueKey('look-${widget.fill.name}-$label'),
                finish: option,
                label: label,
                selected: !custom && finish == option,
                onTap: () {
                  setState(() => _custom = false);
                  widget.onChanged(option);
                },
              ),
            LookSwatch(
              key: ValueKey('look-${widget.fill.name}-Custom'),
              finish: customOf(customColour),
              label: 'Custom',
              selected: custom,
              onTap: () => setState(() => _custom = true),
            ),
          ],
        ),
        if (custom) ...[
          const SizedBox(height: 10),
          ColourPicker(
            colour: customColour,
            onChanged: (colour) => widget.onChanged(customOf(colour)),
          ),
        ],
      ],
    );
  }
}

/// One look, drawn as what it is: a panel as its colour, glass as its
/// colour with the two strokes a drawing uses to mean glass.
class LookSwatch extends StatelessWidget {
  final Finish finish;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const LookSwatch({
    super.key,
    required this.finish,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? p.primary : p.hairline,
                    width: selected ? 2.6 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(painter: _SwatchPainter(finish)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? p.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final Finish finish;
  const _SwatchPainter(this.finish);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Color(finish.colour));
    if (!Infill.isGlass(finish)) return;
    // Frosted glass is drawn softer: it lets less of what is behind it
    // through, which is the whole of what frosting is.
    if (finish.material == MaterialKind.frostedGlass) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35),
      );
    }
    final line = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
      ..strokeWidth = 1.4;
    final reach = size.shortestSide * 0.55;
    for (final inset in [0.0, 5.0]) {
      canvas.drawLine(
        Offset(size.width - reach - inset, 0),
        Offset(size.width, reach + inset),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.finish != finish;
}

/// One part of the design, and what fills it: the part picked out on a
/// small drawing of the whole design, glass or panel, and its look.
///
/// Glass or panel is chosen first and the look second, and the part is said
/// only when both are — a part the user has said is a panel but not yet
/// which colour is waiting on them, not given one.
class PartChoice extends StatefulWidget {
  final Design design;
  final SectionElement part;

  /// What fills it now, or null while the user has not said.
  final Finish? finish;
  final ValueChanged<Finish> onChanged;

  /// The part the user had picked when they asked, drawn out.
  final bool highlighted;

  const PartChoice({
    super.key,
    required this.design,
    required this.part,
    required this.finish,
    required this.onChanged,
    this.highlighted = false,
  });

  @override
  State<PartChoice> createState() => _PartChoiceState();
}

class _PartChoiceState extends State<PartChoice> {
  /// Glass or panel, chosen and waiting on a look.
  Fill? _waiting;

  @override
  void didUpdateWidget(PartChoice old) {
    super.didUpdateWidget(old);
    if (Fill.of(widget.finish) == _waiting) _waiting = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final said = Fill.of(widget.finish);
    final fill = _waiting ?? said;
    return Container(
      key: ValueKey('part-${widget.part.id}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: widget.highlighted
            ? p.primary.withValues(alpha: 0.07)
            : p.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.highlighted ? p.primary : p.hairline,
          width: widget.highlighted ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PartThumb(
                design: widget.design,
                partId: widget.part.id,
                finish: widget.finish,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Infill.nameOf(widget.design, widget.part),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Infill.whereIs(widget.design, widget.part),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<Fill>(
            key: ValueKey('fill-${widget.part.id}'),
            segments: [
              for (final option in Fill.values)
                ButtonSegment(
                  value: option,
                  label: Text(option.label),
                  icon: Icon(
                    option == Fill.glass
                        ? Icons.window_outlined
                        : Icons.rectangle,
                    size: 18,
                  ),
                ),
            ],
            selected: {?fill},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (chosen) {
              if (chosen.isEmpty) return;
              final next = chosen.single;
              setState(() => _waiting = next == said ? null : next);
            },
          ),
          if (fill != null) ...[
            const SizedBox(height: 10),
            Text(
              _waiting != null
                  ? (fill == Fill.panel
                        ? 'Choose the panel colour'
                        : 'Choose the glass')
                  : (fill == Fill.panel ? 'Panel colour' : 'Glass'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _waiting != null ? p.primary : p.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            LookChoices(
              fill: fill,
              finish: _waiting != null ? null : widget.finish,
              onChanged: (finish) {
                setState(() => _waiting = null);
                widget.onChanged(finish);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The whole design small, with one part filled so the user can see which
/// part they are saying something about. Drawn from the design's own
/// outlines, as every picture of it is.
class PartThumb extends StatelessWidget {
  final Design design;
  final String partId;
  final Finish? finish;
  final double size;

  const PartThumb({
    super.key,
    required this.design,
    required this.partId,
    required this.finish,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _ThumbPainter(
        design: design,
        partId: partId,
        finish: finish,
        ink: context.palette.ink,
        accent: context.palette.primary,
      ),
    ),
  );
}

class _ThumbPainter extends CustomPainter {
  final Design design;
  final String partId;
  final Finish? finish;
  final Color ink;
  final Color accent;

  const _ThumbPainter({
    required this.design,
    required this.partId,
    required this.finish,
    required this.ink,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frame = design.frame;
    if (frame == null) return;
    final bounds = frame.outline;
    final scale =
        (size.shortestSide - 4) /
        (bounds.width > bounds.height ? bounds.width : bounds.height);
    final dx = (size.width - bounds.width * scale) / 2;
    final dy = (size.height - bounds.height * scale) / 2;
    Offset at(double x, double y) =>
        Offset(dx + (x - bounds.left) * scale, dy + (y - bounds.top) * scale);
    Path pathOf(List<({double x, double y})> points) {
      final path = Path();
      for (final (i, v) in points.indexed) {
        final o = at(v.x, v.y);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    final outer = pathOf([
      for (final v in frame.outline.corners) (x: v.x, y: v.y),
    ]);
    canvas.drawPath(outer, Paint()..color = ink.withValues(alpha: 0.08));
    for (final part in Infill.partsOf(design)) {
      final path = pathOf([
        for (final v in part.outline.corners) (x: v.x, y: v.y),
      ]);
      if (part.id == partId) {
        canvas.drawPath(
          path,
          Paint()
            ..color = finish == null
                ? accent.withValues(alpha: 0.35)
                : Color(finish!.colour),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = ink.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
    canvas.drawPath(
      outer,
      Paint()
        ..color = ink.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.design != design || old.partId != partId || old.finish != finish;
}
