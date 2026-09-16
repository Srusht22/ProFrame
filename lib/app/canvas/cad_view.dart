import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/units.dart';
import '../../domain/editing/design_edits.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'cad_layers.dart';
import 'cad_painter.dart';
import 'cad_style.dart';
import 'dimension_handles.dart';
import 'view_transform.dart';

/// The technical drawing, and the drafting board it sits on.
///
/// The same design as every other view, drawn to drafting conventions and
/// editable by taking hold of it. Opening this view changes nothing: it
/// reads the design and draws it.
class CadView extends ConsumerStatefulWidget {
  final Set<String> highlighted;

  const CadView({super.key, this.highlighted = const {}});

  @override
  ConsumerState<CadView> createState() => _CadViewState();
}

class _CadViewState extends ConsumerState<CadView> {
  ViewTransform? _view;
  Size _size = Size.zero;
  Polygon? _fittedTo;

  Grip? _holding;
  Vec2? _pointer;
  Vec2? _snapped;
  Offset? _panFrom;

  /// The figure the user has opened for typing, if any.
  DimensionHandle? _editing;

  /// What the next click inside the selected opening does.
  InsideTool _inside = InsideTool.select;

  /// Room round the drawing for the things that sit beside it: two rows of
  /// dimensions and their names along the bottom and down the left, and the
  /// status bar under everything.
  static const EdgeInsets _sheetPadding =
      EdgeInsets.only(left: 118, right: 70, top: 20, bottom: 150);

  ViewTransform _fitted(Polygon? content, Size size) => ViewTransform.fit(
        content,
        size,
        marginFraction: 0.06,
        padding: _sheetPadding,
      );

  ViewTransform get _transform => _view ?? _fitted(_fittedTo, _size);

  void _fitIfNeeded(Polygon? content) {
    if (content == null) return;
    final previous = _fittedTo;
    final changed = previous == null ||
        (previous.width - content.width).abs() > previous.width * 0.35 ||
        (previous.height - content.height).abs() > previous.height * 0.35;
    if (!changed) return;
    _fittedTo = content;
    _view = _fitted(content, _size);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    final layers = state.layers;

    // An opening is a container. Pick any part of one and the tools for
    // drawing inside it appear, because from there a line is the opening's.
    final insideId =
        DesignEdits.openingAround(state.design, state.selectedId);
    final insideSection =
        insideId == null ? null : state.design.sectionById(insideId);

    return Column(
      children: [
        _LayerBar(
          layers: layers,
          onChanged: controller.setLayers,
          onFit: () => setState(() {
            _fittedTo = state.design.bounds;
            _view = _fitted(state.design.bounds, _size);
          }),
        ),
        const Divider(height: 1),
        if (insideSection != null)
          _InsideBar(
            opening: insideSection,
            mechanism: state.design.openingOf(insideSection.id),
            tool: _inside,
            selected: state.selected,
            onTool: (tool) => setState(() => _inside = tool),
            onErase: controller.deleteSelected,
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (size != _size) {
                _size = size;
                _view ??= _fitted(_fittedTo, size);
              }
              _fitIfNeeded(state.design.bounds);
              final view = _transform;
              final grips = _gripsFor(state.design, state.selectedId);
              final figures =
                  CadDimensions.of(state.design, view, layers);

              // The opening the user is working inside, if they have picked
              // any part of one. A line tool only exists while there is
              // somewhere for its line to belong.
              final insideOf =
                  DesignEdits.openingAround(state.design, state.selectedId);
              if (insideOf == null && _inside != InsideTool.select) {
                _inside = InsideTool.select;
              }
              final within = insideOf == null
                  ? null
                  : state.design.sectionById(insideOf)?.outline;
              final ghost = _inside == InsideTool.select || within == null
                  ? null
                  : _lineAt(_pointer, within, _inside);

              return ClipRect(
                child: MouseRegion(
                  cursor: _holding == null
                      ? SystemMouseCursors.precise
                      : SystemMouseCursors.move,
                  onHover: (event) => setState(
                    () => _pointer = view.toSheet(event.localPosition),
                  ),
                  onExit: (_) => setState(() => _pointer = null),
                  child: Listener(
                    onPointerDown: (event) => _down(
                          event,
                          view,
                          grips,
                          figures,
                          insideOf,
                          controller,
                        ),
                    onPointerMove: (event) => _move(event, view, controller),
                    onPointerUp: (_) => _up(controller),
                    onPointerCancel: (_) => _up(controller),
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        setState(() {
                          _view = view.zoomed(
                            event.scrollDelta.dy > 0 ? 0.9 : 1.1,
                            event.localPosition,
                          );
                        });
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        if (details.pointerCount < 2) return;
                        _panFrom = details.localFocalPoint;
                      },
                      onScaleUpdate: (details) {
                        if (details.pointerCount < 2) return;
                        final from = _panFrom ?? details.localFocalPoint;
                        setState(() {
                          _view = _transform
                              .panned(details.localFocalPoint - from)
                              .zoomed(
                                details.scale == 0
                                    ? 1
                                    : 1 + (details.scale - 1) * 0.25,
                                details.localFocalPoint,
                              );
                        });
                        _panFrom = details.localFocalPoint;
                      },
                      onScaleEnd: (_) => _panFrom = null,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              size: size,
                              painter: CadPainter(
                                design: state.design,
                                view: view,
                                layers: layers,
                                selectedId: state.selectedId,
                                highlighted: widget.highlighted,
                                snapAt: _snapped,
                                grips: grips,
                                guide: ghost,
                                guideWithin:
                                    _inside == InsideTool.select ? null : within,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _StatusBar(
                              state: state,
                              pointer: _pointer,
                              scale: view.scale,
                            ),
                          ),
                          if (_editing case final figure?)
                            _FigureEditor(
                              figure: figure,
                              within: size,
                              onApply: (value) {
                                _applyFigure(figure, value, controller);
                                setState(() => _editing = null);
                              },
                              onCancel: () => setState(() => _editing = null),
                            ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: _ZoomStack(
                              onIn: () => setState(() => _view = _transform
                                  .zoomed(1.25, size.center(Offset.zero))),
                              onOut: () => setState(() => _view = _transform
                                  .zoomed(0.8, size.center(Offset.zero))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ grips

  /// The handles for whatever is selected.
  ///
  /// A section's handles sit on its own edges but move the bars and frame
  /// sides that make them, because a pane is the space between those and has
  /// no edges of its own. That is what lets a boundary be dragged from
  /// either side of it.
  List<Grip> _gripsFor(Design design, String? selectedId) {
    if (selectedId == null) return const [];
    final element = design.elementById(selectedId);
    return switch (element) {
      DividerElement() => [
          Grip(at: element.a, elementId: element.id, kind: GripKind.endStart),
          Grip(
            at: element.segment.midpoint,
            elementId: element.id,
            kind: GripKind.boundary,
            dividerId: element.id,
          ),
          Grip(at: element.b, elementId: element.id, kind: GripKind.endFinish),
        ],
      FrameElement() => [
          for (final member in design.frameMembers)
            Grip(
              at: member.run.midpoint,
              elementId: element.id,
              kind: GripKind.boundary,
              memberIndex: member.index,
            ),
        ],
      FrameMemberElement() => [
          Grip(
            at: element.run.midpoint,
            elementId: element.id,
            kind: GripKind.boundary,
            memberIndex: element.index,
          ),
        ],
      SectionElement() => _sectionGrips(design, element),
      OpeningElement() => () {
          final section = design.sectionById(element.sectionId);
          return section == null
              ? const <Grip>[]
              : _sectionGrips(design, section, on: element.id);
        }(),
      HardwareElement() => [
          Grip(at: element.at, elementId: element.id, kind: GripKind.move),
        ],
      DimensionElement() => [
          Grip(at: element.a, elementId: element.id, kind: GripKind.endStart),
          Grip(at: element.b, elementId: element.id, kind: GripKind.endFinish),
          Grip(
            at: element.anchor +
                Segment(element.a, element.b).unit.perpendicular *
                    element.offsetMm,
            elementId: element.id,
            kind: GripKind.offset,
          ),
        ],
      TextElement() => [
          Grip(at: element.at, elementId: element.id, kind: GripKind.move),
        ],
      ArrowElement() => [
          Grip(at: element.from, elementId: element.id, kind: GripKind.endStart),
          Grip(at: element.to, elementId: element.id, kind: GripKind.endFinish),
        ],
      _ => const [],
    };
  }

  /// A handle on the middle of each of a section's edges, moving whatever
  /// makes that edge.
  List<Grip> _sectionGrips(
    Design design,
    SectionElement section, {
    String? on,
  }) {
    final grips = <Grip>[];
    final elementId = on ?? section.id;

    for (final edge in section.outline.edges) {
      final middle = edge.midpoint;

      // A bar whose face runs along this edge.
      String? dividerId;
      for (final divider in design.dividers) {
        final half = divider.widthMm / 2;
        final across = divider.segment.unit.perpendicular;
        for (final side in [across * half, -across * half]) {
          final face = Segment(divider.a + side, divider.b + side);
          if (face.distanceTo(middle) <= math.max(2, divider.widthMm * 0.15)) {
            dividerId = divider.id;
          }
        }
      }
      if (dividerId != null) {
        grips.add(Grip(
          at: middle,
          elementId: elementId,
          kind: GripKind.boundary,
          dividerId: dividerId,
        ));
        continue;
      }

      // Otherwise it is the daylight edge of the frame, and moving it moves
      // that side of the frame.
      for (final member in design.frameMembers) {
        if (member.run.distanceTo(middle) >
            (design.frame!.profileMm * 1.4)) {
          continue;
        }
        grips.add(Grip(
          at: middle,
          elementId: elementId,
          kind: GripKind.boundary,
          memberIndex: member.index,
        ));
        break;
      }
    }
    return grips;
  }

  // --------------------------------------------------------------- pointers

  void _down(
    PointerDownEvent event,
    ViewTransform view,
    List<Grip> grips,
    List<DimensionHandle> figures,
    String? insideOf,
    WorkspaceController controller,
  ) {
    final at = view.toSheet(event.localPosition);
    final reach = view.lengthToSheet(13);

    // A line tool has been picked, so this click places a line rather than
    // selecting anything. It goes in the opening and nowhere else: a click
    // outside puts the tool down without drawing.
    if (_inside != InsideTool.select && insideOf != null) {
      final horizontal = _inside == InsideTool.horizontalLine;
      final design = ref.read(workspaceProvider).design;
      final within = design.sectionById(insideOf)?.outline;
      if (within != null && within.contains(at)) {
        controller.addLineInside(insideOf, at, horizontal: horizontal);
      }
      setState(() {
        _inside = InsideTool.select;
        _holding = null;
        _editing = null;
      });
      return;
    }

    for (final grip in grips) {
      if (grip.at.distanceTo(at) <= reach) {
        setState(() {
          _holding = grip;
          _editing = null;
        });
        return;
      }
    }

    // A figure on the drawing is the geometry it measures, so tapping one
    // opens it for typing rather than selecting whatever is behind it.
    final figure = CadDimensions.at(figures, event.localPosition);
    if (figure != null) {
      setState(() {
        _editing = figure;
        _holding = null;
      });
      return;
    }
    if (_editing != null) setState(() => _editing = null);

    controller.selectAt(at, slopMm: view.lengthToSheet(12));
    setState(() {
      _holding = null;
      _pointer = at;
    });
  }

  /// Where [tool] would lay a line if the user clicked at [at].
  ///
  /// The same arithmetic that places the line for real, so what is shown is
  /// what is drawn rather than a sketch of roughly where it might go.
  Segment? _lineAt(Vec2? at, Polygon within, InsideTool tool) {
    if (at == null || !within.contains(at)) return null;
    return DesignEdits.spanAcross(
      within,
      Segment(
        at,
        tool == InsideTool.horizontalLine
            ? at + const Vec2(1, 0)
            : at + const Vec2(0, 1),
      ),
    );
  }

  /// Types a new figure over a dimension, which moves the geometry it
  /// measures and nothing else.
  void _applyFigure(
    DimensionHandle figure,
    double valueMm,
    WorkspaceController controller,
  ) {
    final id = figure.elementId;
    switch (figure.of) {
      case DimensionOf.overallWidth:
        controller.resizeFrame(widthMm: valueMm);
      case DimensionOf.overallHeight:
        controller.resizeFrame(heightMm: valueMm);
      case DimensionOf.sectionWidth:
        if (id != null) controller.setSectionWidth(id, valueMm);
      case DimensionOf.sectionHeight:
        if (id != null) controller.setSectionHeight(id, valueMm);
      case DimensionOf.drawn:
        if (id != null) controller.setDimensionValue(id, valueMm);
    }
  }

  void _move(
    PointerMoveEvent event,
    ViewTransform view,
    WorkspaceController controller,
  ) {
    final raw = view.toSheet(event.localPosition);
    setState(() => _pointer = raw);

    final grip = _holding;
    if (grip == null) return;

    final state = ref.read(workspaceProvider);
    final design = state.design;
    final within = view.lengthToSheet(11);

    double? snapX;
    double? snapY;
    if (state.layers.snap) {
      snapX = DesignEdits.snapTo(
        DesignEdits.snapCandidates(
          design,
          horizontal: true,
          ignoreId: grip.elementId,
        ),
        raw.x,
        withinMm: within,
      );
      snapY = DesignEdits.snapTo(
        DesignEdits.snapCandidates(
          design,
          horizontal: false,
          ignoreId: grip.elementId,
        ),
        raw.y,
        withinMm: within,
      );
    }
    final at = Vec2(snapX ?? raw.x, snapY ?? raw.y);

    switch (grip.kind) {
      case GripKind.boundary:
        if (grip.dividerId != null) {
          controller.moveDividerAcross(grip.dividerId!, at);
        } else if (grip.memberIndex != null) {
          controller.moveFrameMember(
            grip.memberIndex!,
            DesignEdits.frameMemberOffset(design, grip.memberIndex!, at),
          );
        }
        setState(() => _snapped = snapX != null || snapY != null ? at : null);
      case GripKind.move:
        final element = design.elementById(grip.elementId);
        if (element is DividerElement) {
          controller.moveDividerTo(grip.elementId, at);
        } else if (element != null) {
          controller.select(grip.elementId);
          controller.dragElement(grip.elementId, at - element.anchor);
        }
        setState(() => _snapped = snapX != null || snapY != null ? at : null);
      case GripKind.endStart:
      case GripKind.endFinish:
        final start = grip.kind == GripKind.endStart;
        final element = design.elementById(grip.elementId);
        switch (element) {
          case DividerElement():
            controller.moveDividerEnd(
              grip.elementId,
              startEnd: start,
              to: at,
            );
          case DimensionElement():
            controller.moveDimensionEnd(
              grip.elementId,
              to: at,
              startEnd: start,
            );
          case ArrowElement():
            controller.moveArrowEnd(grip.elementId, to: at, startEnd: start);
          default:
            break;
        }
        setState(() => _snapped = snapX != null || snapY != null ? at : null);
      case GripKind.offset:
        controller.setDimensionOffset(grip.elementId, raw);
        setState(() => _snapped = null);
    }
  }

  void _up(WorkspaceController controller) {
    controller.endGesture();
    setState(() {
      _holding = null;
      _snapped = null;
    });
  }
}

/// What a click inside the selected opening does.
enum InsideTool {
  /// Pick something, which is what a click does the rest of the time.
  select('Select', Icons.near_me_outlined),

  /// Lay a horizontal line across the opening where the user clicks.
  horizontalLine('Horizontal line', Icons.horizontal_rule),

  /// The same, standing up.
  verticalLine('Vertical line', Icons.vertical_align_center);

  const InsideTool(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The tools for drawing inside an opening.
///
/// An opening is a container, not a single pane: it can hold its own bars
/// and its own glass and panels. This strip appears whenever any part of an
/// opening is picked, and every line it draws belongs to that opening —
/// dividing it, never ending it, and travelling with it ever afterwards.
///
/// Nothing here divides an opening on its own. An opening with no line drawn
/// in it stays one pane, however tall it is.
class _InsideBar extends StatelessWidget {
  final SectionElement opening;
  final OpeningElement? mechanism;
  final InsideTool tool;
  final DesignElement? selected;
  final ValueChanged<InsideTool> onTool;
  final VoidCallback onErase;

  const _InsideBar({
    required this.opening,
    required this.mechanism,
    required this.tool,
    required this.selected,
    required this.onTool,
    required this.onErase,
  });

  @override
  Widget build(BuildContext context) {
    final erasable = selected != null &&
        (selected is DividerElement &&
            (selected! as DividerElement).parentId == opening.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.hairline)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined,
              size: 15, color: AppTheme.accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Inside ${mechanism?.mechanism.label.toLowerCase() ?? 'this opening'}'
              ' — ${Units.format(opening.widthMm)} × '
              '${Units.label(opening.heightMm)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(width: 14),
          for (final option in InsideTool.values) ...[
            _InsideButton(
              label: option.label,
              icon: option.icon,
              on: tool == option,
              onTap: () => onTool(option),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          _InsideButton(
            label: 'Erase',
            icon: Icons.backspace_outlined,
            on: false,
            enabled: erasable,
            onTap: onErase,
          ),
        ],
      ),
    );
  }
}

class _InsideButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  const _InsideButton({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colour = !enabled
        ? AppTheme.muted.withValues(alpha: 0.45)
        : on
            ? AppTheme.primary
            : AppTheme.ink;
    return Material(
      color: on ? AppTheme.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colour),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Typing a new figure over one on the drawing.
///
/// It opens where the figure is written, so what is being changed is never
/// in doubt, and it shows centimetres because that is what the user works
/// in. Applying it moves the geometry the figure measures. There is no way
/// from here to change the number alone: a figure that did not match the
/// design would be a lie about what gets built.
class _FigureEditor extends StatefulWidget {
  final DimensionHandle figure;
  final Size within;
  final ValueChanged<double> onApply;
  final VoidCallback onCancel;

  const _FigureEditor({
    required this.figure,
    required this.within,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<_FigureEditor> createState() => _FigureEditorState();
}

class _FigureEditorState extends State<_FigureEditor> {
  static const double _width = 212;
  static const double _height = 128;

  late final TextEditingController _field =
      TextEditingController(text: Units.format(widget.figure.valueMm))
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: Units.format(widget.figure.valueMm).length,
        );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply() {
    final value = Units.parse(_field.text);
    if (value == null || value <= 0) {
      widget.onCancel();
      return;
    }
    widget.onApply(value);
  }

  @override
  Widget build(BuildContext context) {
    // Beside the figure, and always on the sheet: a card off the edge of the
    // view would be a figure the user could not type into.
    final at = widget.figure.rect.center;
    final left = (at.dx - _width / 2).clamp(8.0, widget.within.width - _width - 8);
    final top = (at.dy + 16).clamp(8.0, widget.within.height - _height - 8);

    return Positioned(
      left: left,
      top: top,
      width: _width,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.figure.label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  suffixText: Units.symbol,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
                onSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the drawing is showing, as a row of switches.
class _LayerBar extends StatelessWidget {
  final CadLayers layers;
  final ValueChanged<CadLayers> onChanged;
  final VoidCallback onFit;

  const _LayerBar({
    required this.layers,
    required this.onChanged,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'Dimensions',
                icon: Icons.straighten,
                on: layers.dimensions,
                onTap: () =>
                    onChanged(layers.copyWith(dimensions: !layers.dimensions)),
              ),
              _Chip(
                label: 'Hatching',
                icon: Icons.texture,
                on: layers.hatching,
                onTap: () =>
                    onChanged(layers.copyWith(hatching: !layers.hatching)),
              ),
              _Chip(
                label: 'Openings',
                icon: Icons.door_sliding_outlined,
                on: layers.openings,
                onTap: () =>
                    onChanged(layers.copyWith(openings: !layers.openings)),
              ),
              _Chip(
                label: 'Centre lines',
                icon: Icons.more_vert,
                on: layers.centreLines,
                onTap: () => onChanged(
                  layers.copyWith(centreLines: !layers.centreLines),
                ),
              ),
              _Chip(
                label: 'Notes',
                icon: Icons.short_text,
                on: layers.annotations,
                onTap: () => onChanged(
                  layers.copyWith(annotations: !layers.annotations),
                ),
              ),
              _Chip(
                label: 'My drawing',
                icon: Icons.gesture,
                on: layers.sketch,
                onTap: () => onChanged(layers.copyWith(sketch: !layers.sketch)),
              ),
              _Chip(
                label: 'Grid',
                icon: Icons.grid_4x4,
                on: layers.grid,
                onTap: () => onChanged(layers.copyWith(grid: !layers.grid)),
              ),
              const SizedBox(width: 6),
              const SizedBox(
                height: 22,
                child: VerticalDivider(width: 12),
              ),
              _Chip(
                label: 'Handles',
                icon: Icons.open_with,
                on: layers.grips,
                onTap: () => onChanged(layers.copyWith(grips: !layers.grips)),
              ),
              _Chip(
                label: 'Snap',
                icon: Icons.control_point,
                on: layers.snap,
                onTap: () => onChanged(layers.copyWith(snap: !layers.snap)),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: onFit,
                icon: const Icon(Icons.fit_screen_outlined, size: 17),
                label: const Text('Fit'),
              ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: on
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: on ? AppTheme.primary : AppTheme.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? AppTheme.primary : AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// The strip along the bottom that a drafting program has: where the pointer
/// is, what is selected, what the drawing is at.
class _StatusBar extends StatelessWidget {
  final WorkspaceState state;
  final Vec2? pointer;
  final double scale;

  const _StatusBar({
    required this.state,
    required this.pointer,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    final design = state.design;

    // The drawing scale, as a drawing states it: one to something.
    final ratio = scale <= 0 ? 0 : (1 / scale);
    final rounded = _nearestDrawingScale(ratio.toDouble());

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Cad.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: DefaultTextStyle(
        // The family has to be named. A DefaultTextStyle replaces the
        // inherited one rather than merging with it, so leaving it out drops
        // the theme's font and the text renders blank on the web.
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          color: AppTheme.muted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A status bar that overflows is worse than one that says less,
            // so the middle of it goes first as the panel narrows.
            final roomy = constraints.maxWidth > 620;
            return Row(
              // Space between, with a group either end: the readings belong
              // at the left of the bar and what is selected at the right,
              // and neither should drift towards the middle as the panel
              // changes width.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pointer == null
                            ? 'X —   Y —'
                            : 'X ${Units.format(pointer!.x)}   '
                                'Y ${Units.format(pointer!.y)} '
                                '${Units.symbol}',
                      ),
                      const SizedBox(width: 18),
                      Text('1 : $rounded'),
                      if (roomy) ...[
                        const SizedBox(width: 18),
                        Flexible(
                          child: Text(
                            '${design.sections.length} sections · '
                            '${design.dividers.length} bars · '
                            '${design.openings.length} openings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    selected?.label ??
                        (roomy ? 'Tap a line, a bar or a pane' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: selected == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color:
                          selected == null ? AppTheme.muted : AppTheme.ink,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The nearest of the ratios drawings are actually issued at.
  int _nearestDrawingScale(double ratio) {
    const steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000];
    var best = steps.first;
    var bestGap = double.infinity;
    for (final step in steps) {
      final gap = (step - ratio).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = step;
      }
    }
    return best;
  }
}

class _ZoomStack extends StatelessWidget {
  final VoidCallback onIn;
  final VoidCallback onOut;

  const _ZoomStack({required this.onIn, required this.onOut});

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onIn,
              icon: const Icon(Icons.add),
              tooltip: 'Zoom in',
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onOut,
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom out',
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}
