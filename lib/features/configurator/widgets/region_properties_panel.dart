import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/design_region.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../geometry/design_validator.dart';
import '../../geometry/region_editor.dart';
import '../state/design_session.dart';
import 'instruction_bar.dart';

/// Everything about the design, editable by number.
///
/// This panel and the drawing edit the same geometry: selecting here highlights
/// there, dragging there updates the fields here, and every value is applied
/// exactly as typed.
class RegionPropertiesPanel extends ConsumerWidget {
  final OpeningModel model;

  const RegionPropertiesPanel({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    final notifier = ref.read(designSessionProvider.notifier);
    final selectedId = session.selectedRegionId;
    final selected = selectedId == null ? null : model.region(selectedId);
    final issues = const DesignValidator().validate(model);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        InstructionBar(model: model),
        const Divider(height: AppSpacing.lg),
        const SectionHeader(title: 'Overall size'),
        Row(
          children: [
            Expanded(
              child: MillimetreField(
                label: 'Width',
                value: model.widthMm,
                onChanged: (value) => notifier.updateModel(
                  RegionEditor.setOverallSize(model, widthMm: value),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MillimetreField(
                label: 'Height',
                value: model.heightMm,
                onChanged: (value) => notifier.updateModel(
                  RegionEditor.setOverallSize(model, heightMm: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Material'),
        _Dropdown<FrameMaterial>(
          label: 'Frame material',
          value: model.material,
          items: FrameMaterial.values,
          labelOf: (m) => '${m.label} · ${m.frameDepthMm.round()} mm deep',
          onChanged: (value) => notifier.updateModel(model.copyWith(material: value)),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Dropdown<FrameFinish>(
          label: 'Finish',
          value: model.finish,
          items: FrameFinish.values,
          labelOf: (f) => f.label,
          onChanged: (value) => notifier.updateModel(model.copyWith(finish: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        _ProfileEditor(model: model),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(
          title: 'Sections',
          subtitle: '${model.leafRegions.length} in this design · tap one to edit',
        ),
        for (final region in model.allRegions)
          _RegionRow(
            region: region,
            selected: region.id == selectedId,
            onTap: () =>
                notifier.selectRegion(region.id == selectedId ? null : region.id),
          ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: () => _addOpening(context, ref),
              icon: const Icon(Icons.add_box_outlined, size: 16),
              label: const Text('Add an opening'),
            ),
          ],
        ),
        if (selected != null) ...[
          const Divider(height: AppSpacing.lg),
          _SelectedRegionEditor(model: model, region: selected),
        ],
        const Divider(height: AppSpacing.lg),
        _Checks(model: model, issues: issues),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _addOpening(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_PlacementRequest>(
      context: context,
      builder: (_) => _AddOpeningDialog(model: model),
    );
    if (result == null) return;
    final rect = result.anchor.place(model.outerRect, result.width, result.height);
    final placed = RegionEditor.placeRegion(
      model,
      rect,
      operation: result.operation,
      swing: result.operation.isOperable && !result.operation.isSliding
          ? SwingDirection.outward
          : SwingDirection.none,
      handle: result.operation.isOperable ? HandleStyle.lever : HandleStyle.none,
      label: result.label,
    );
    ref.read(designSessionProvider.notifier)
      ..updateModel(placed.model)
      ..selectRegion(placed.id);
  }
}

class _RegionRow extends StatelessWidget {
  final DesignRegion region;
  final bool selected;
  final VoidCallback onTap;

  const _RegionRow({
    required this.region,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        color: selected ? AppColors.brandCreamSoft : null,
        border: selected
            ? Border.all(color: AppColors.brandDarkGreen.withValues(alpha: 0.5), width: 1.4)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.label ?? 'Section ${region.id}',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    region.summary,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(selected ? Icons.expand_less : Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The full property sheet for one section — the panel from the brief.
class _SelectedRegionEditor extends ConsumerWidget {
  final OpeningModel model;
  final DesignRegion region;

  const _SelectedRegionEditor({required this.model, required this.region});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(designSessionProvider.notifier);
    void apply(OpeningModel next) => notifier.updateModel(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: region.label ?? 'Section ${region.id}',
          subtitle: region.summary,
        ),
        Row(
          children: [
            Expanded(
              child: MillimetreField(
                label: 'Width',
                value: region.rect.width,
                helper: 'Moves the boundary it shares',
                onChanged: (value) =>
                    apply(RegionEditor.setWidth(model, region.id, value)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MillimetreField(
                label: 'Height',
                value: region.rect.height,
                onChanged: (value) =>
                    apply(RegionEditor.setHeight(model, region.id, value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: MillimetreField(
                label: 'From left',
                value: region.rect.left,
                allowZero: true,
                onChanged: (value) => apply(RegionEditor.moveTo(
                  model,
                  region.id,
                  Vec2(value, region.rect.top),
                )),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MillimetreField(
                label: 'From top',
                value: region.rect.top,
                allowZero: true,
                onChanged: (value) => apply(RegionEditor.moveTo(
                  model,
                  region.id,
                  Vec2(region.rect.left, value),
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Move to', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final anchor in RegionAnchor.values)
              ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(anchor.label),
                onPressed: () => apply(RegionEditor.anchor(model, region.id, anchor)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Dropdown<CellOperation>(
          label: 'Opens',
          value: region.operation,
          items: CellOperation.values,
          labelOf: (o) => o.label,
          onChanged: (value) =>
              apply(RegionEditor.setOperation(model, region.id, value)),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Dropdown<CellInfill>(
          label: 'Filled with',
          value: region.infill,
          items: CellInfill.values,
          labelOf: (i) => i.label,
          onChanged: (value) => apply(
            RegionEditor.update(model, region.id, (r) => r.copyWith(infill: value)),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (region.infill != CellInfill.open)
          MillimetreField(
            label: 'Infill thickness',
            value: region.infillThicknessMm,
            helper: 'Follows the glass or panel type until you set it',
            onChanged: (value) => apply(RegionEditor.update(
              model,
              region.id,
              (r) => r.infill == CellInfill.glass
                  ? r.copyWith(glassThicknessMm: value)
                  : r.copyWith(panelThicknessMm: value),
            )),
          ),
        if (region.infill == CellInfill.glass) ...[
          const SizedBox(height: AppSpacing.xs),
          _Dropdown<GlassType>(
            label: 'Glass',
            value: region.glass,
            items: GlassType.values,
            labelOf: (g) => g.label,
            onChanged: (value) => apply(
              RegionEditor.update(model, region.id, (r) => r.copyWith(glass: value)),
            ),
          ),
        ],
        if (region.infill == CellInfill.panel || region.infill == CellInfill.louvre) ...[
          const SizedBox(height: AppSpacing.xs),
          _Dropdown<PanelMaterial>(
            label: 'Panel',
            value: region.panel,
            items: PanelMaterial.values,
            labelOf: (p) => p.label,
            onChanged: (value) => apply(
              RegionEditor.update(model, region.id, (r) => r.copyWith(panel: value)),
            ),
          ),
        ],
        if (region.operation.isOperable) ...[
          const SizedBox(height: AppSpacing.xs),
          _Dropdown<SwingDirection>(
            label: 'Swing',
            value: region.swing,
            items: SwingDirection.values,
            labelOf: (s) => s.label,
            onChanged: (value) => apply(
              RegionEditor.update(model, region.id, (r) => r.copyWith(swing: value)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _Dropdown<HandleStyle>(
            label: 'Handle',
            value: region.handle,
            items: HandleStyle.values,
            labelOf: (h) => h.label,
            onChanged: (value) => apply(
              RegionEditor.update(model, region.id, (r) => r.copyWith(handle: value)),
            ),
          ),
          if (region.handle != HandleStyle.none) ...[
            const SizedBox(height: AppSpacing.xs),
            MillimetreField(
              label: 'Handle height from the floor',
              value: region.handleHeightMm ?? 1050,
              helper: 'Measured to the centre of the handle',
              onChanged: (value) => apply(RegionEditor.update(
                model,
                region.id,
                (r) => r.copyWith(handleHeightMm: value),
              )),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: region.hasLock,
            onChanged: (value) => apply(RegionEditor.update(
              model,
              region.id,
              (r) => r.copyWith(hasLock: value),
            )),
            title: const Text('Lock'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: region.hasMesh,
            onChanged: (value) => apply(RegionEditor.update(
              model,
              region.id,
              (r) => r.copyWith(hasMesh: value),
            )),
            title: const Text('Insect mesh'),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text('Divide this section', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: () => apply(
                RegionEditor.divide(model, region.id, axis: Axis2.horizontal),
              ),
              icon: const Icon(Icons.horizontal_split, size: 15),
              label: const Text('Across'),
            ),
            OutlinedButton.icon(
              onPressed: () => apply(
                RegionEditor.divide(model, region.id, axis: Axis2.vertical),
              ),
              icon: const Icon(Icons.vertical_split, size: 15),
              label: const Text('Down'),
            ),
            OutlinedButton.icon(
              onPressed: () => apply(RegionEditor.divide(
                model,
                region.id,
                axis: Axis2.horizontal,
                ratio: 0.6,
                inside: true,
              )),
              icon: const Icon(Icons.splitscreen, size: 15),
              label: const Text('Panes inside'),
            ),
            OutlinedButton.icon(
              onPressed: model.regions.length <= 1
                  ? null
                  : () {
                      ref.read(designSessionProvider.notifier)
                        ..updateModel(RegionEditor.removeRegion(model, region.id))
                        ..selectRegion(null);
                    },
              icon: const Icon(Icons.delete_outline, size: 15),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Manufacturing checks. They report; they never edit.
class _Checks extends ConsumerWidget {
  final OpeningModel model;
  final List<DesignIssue> issues;

  const _Checks({required this.model, required this.issues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (issues.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'No problems found with this design.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Checks',
          subtitle: 'Nothing here changes your design on its own',
        ),
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _IssueCard(model: model, issue: issue),
          ),
      ],
    );
  }
}

class _IssueCard extends ConsumerWidget {
  final OpeningModel model;
  final DesignIssue issue;

  const _IssueCard({required this.model, required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (issue.severity) {
      IssueSeverity.info => AppColors.info,
      IssueSeverity.warning => AppColors.warning,
      IssueSeverity.serious => AppColors.error,
    };
    final notifier = ref.read(designSessionProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(issue.title, style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(issue.detail, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 4,
            children: [
              if (issue.regionId != null)
                TextButton(
                  onPressed: () => notifier.selectRegion(issue.regionId),
                  child: const Text('Show me'),
                ),
              if (issue.hasRecommendation)
                OutlinedButton(
                  onPressed: () => notifier.updateModel(issue.recommendedFix!(model)),
                  child: Text(issue.recommendationLabel ?? 'Apply the suggestion'),
                ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kept as you designed it.')),
                ),
                child: const Text('Keep my design'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlacementRequest {
  final double width;
  final double height;
  final RegionAnchor anchor;
  final CellOperation operation;
  final String? label;

  const _PlacementRequest({
    required this.width,
    required this.height,
    required this.anchor,
    required this.operation,
    this.label,
  });
}

/// "At the top-right, an opening 400 mm wide and 400 mm high."
class _AddOpeningDialog extends StatefulWidget {
  final OpeningModel model;

  const _AddOpeningDialog({required this.model});

  @override
  State<_AddOpeningDialog> createState() => _AddOpeningDialogState();
}

class _AddOpeningDialogState extends State<_AddOpeningDialog> {
  final TextEditingController _width = TextEditingController(text: '400');
  final TextEditingController _height = TextEditingController(text: '400');
  final TextEditingController _label = TextEditingController();
  RegionAnchor _anchor = RegionAnchor.topRight;
  CellOperation _operation = CellOperation.awning;
  bool _fullHeight = false;
  bool _fullWidth = false;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final width = _fullWidth
        ? widget.model.widthMm
        : double.tryParse(_width.text.trim().replaceAll(',', '.'));
    final height = _fullHeight
        ? widget.model.heightMm
        : double.tryParse(_height.text.trim().replaceAll(',', '.'));
    if (width == null || height == null || width <= 0 || height <= 0) return;
    Navigator.of(context).pop(_PlacementRequest(
      width: width,
      height: height,
      anchor: _anchor,
      operation: _operation,
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add an opening'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'It is placed at exactly this size and position. Whatever is '
              'already there keeps the area around it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _width,
                    enabled: !_fullWidth,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Width',
                      suffixText: 'mm',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: _height,
                    enabled: !_fullHeight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'mm',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _fullHeight,
              onChanged: (value) => setState(() => _fullHeight = value ?? false),
              title: const Text('Full height'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _fullWidth,
              onChanged: (value) => setState(() => _fullWidth = value ?? false),
              title: const Text('Full width'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Position', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final anchor in RegionAnchor.values)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(anchor.label),
                    selected: _anchor == anchor,
                    onSelected: (_) => setState(() => _anchor = anchor),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<CellOperation>(
              initialValue: _operation,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Opens', isDense: true),
              items: CellOperation.values
                  .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _operation = value ?? _operation),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}


/// Profile sizes. Each one follows the chosen material until it is pinned, and
/// a pinned value reaches the drawing, the 3D model and the price alike.
class _ProfileEditor extends ConsumerStatefulWidget {
  final OpeningModel model;

  const _ProfileEditor({required this.model});

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  bool _expanded = false;

  double _valueOf(ProfileDimension dimension) => switch (dimension) {
        ProfileDimension.frameFace => widget.model.frameFaceMm,
        ProfileDimension.frameDepth => widget.model.frameDepthMm,
        ProfileDimension.sashFace => widget.model.sashFaceMm,
        ProfileDimension.sashDepth => widget.model.sashDepthMm,
        ProfileDimension.mullionFace => widget.model.mullionFaceMm,
        ProfileDimension.glazingBead => widget.model.glazingBeadMm,
      };

  bool _isPinned(ProfileDimension dimension) => switch (dimension) {
        ProfileDimension.frameFace => widget.model.profile.frameFaceMm != null,
        ProfileDimension.frameDepth => widget.model.profile.frameDepthMm != null,
        ProfileDimension.sashFace => widget.model.profile.sashFaceMm != null,
        ProfileDimension.sashDepth => widget.model.profile.sashDepthMm != null,
        ProfileDimension.mullionFace => widget.model.profile.mullionFaceMm != null,
        ProfileDimension.glazingBead => widget.model.profile.glazingBeadMm != null,
      };

  ProfileSpec _pin(ProfileDimension dimension, double value) {
    final profile = widget.model.profile;
    return switch (dimension) {
      ProfileDimension.frameFace => profile.copyWith(frameFaceMm: value),
      ProfileDimension.frameDepth => profile.copyWith(frameDepthMm: value),
      ProfileDimension.sashFace => profile.copyWith(sashFaceMm: value),
      ProfileDimension.sashDepth => profile.copyWith(sashDepthMm: value),
      ProfileDimension.mullionFace => profile.copyWith(mullionFaceMm: value),
      ProfileDimension.glazingBead => profile.copyWith(glazingBeadMm: value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(designSessionProvider.notifier);
    final pinnedCount =
        ProfileDimension.values.where(_isPinned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Profile sizes',
          subtitle: pinnedCount == 0
              ? 'Following the ${widget.model.material.label} system'
              : '$pinnedCount set by hand',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
            tooltip: _expanded ? 'Hide' : 'Show',
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded) ...[
          for (final dimension in ProfileDimension.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MillimetreField(
                      label: dimension.label,
                      value: _valueOf(dimension),
                      helper: _isPinned(dimension)
                          ? 'Set by hand'
                          : dimension.help,
                      onChanged: (value) => notifier.updateModel(
                        widget.model.copyWith(profile: _pin(dimension, value)),
                      ),
                    ),
                  ),
                  if (_isPinned(dimension))
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Follow the material again',
                      icon: const Icon(Icons.restart_alt, size: 18),
                      onPressed: () => notifier.updateModel(
                        widget.model.copyWith(
                          profile: widget.model.profile.clearing(dimension),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
