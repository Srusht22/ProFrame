import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../geometry/model_editor.dart';
import '../state/design_session.dart';

/// Edits the structure the app understood. Every change goes to the model and
/// the drawing, the 3D view and the price follow immediately (§18, §27).
class StructureEditor extends ConsumerWidget {
  final OpeningModel model;

  const StructureEditor({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(designSessionProvider.notifier);
    final selected = ref.watch(designSessionProvider).selectedCellPath;
    final solved = OpeningSolver.solve(model);
    final issues = model.validate();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionHeader(title: 'Size'),
        Row(
          children: [
            Expanded(
              child: MillimetreField(
                label: 'Width',
                value: model.widthMm,
                onChanged: (value) =>
                    notifier.updateModel(ModelEditor.setSize(model, widthMm: value)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MillimetreField(
                label: 'Height',
                value: model.heightMm,
                onChanged: (value) =>
                    notifier.updateModel(ModelEditor.setSize(model, heightMm: value)),
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
        const SectionHeader(
          title: 'Divisions',
          subtitle: 'Transoms run across, mullions run up and down',
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => notifier.updateModel(ModelEditor.addTransom(model)),
                icon: const Icon(Icons.horizontal_split, size: 16),
                label: const Text('Add row'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: model.layout.rows.length > 1
                    ? () => notifier.updateModel(ModelEditor.removeTransom(model))
                    : null,
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Remove row'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < model.layout.rows.length; i++)
          _RowEditor(model: model, rowIndex: i),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Sections',
          subtitle: 'How each part of the unit opens and what fills it',
        ),
        for (final cell in solved.leaves)
          _CellEditor(
            model: model,
            cell: cell,
            selected: selected == cell.path,
            onSelect: () => notifier.selectCell(selected == cell.path ? null : cell.path),
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Finishing'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: model.hasThreshold,
          onChanged: (value) => notifier.updateModel(model.copyWith(hasThreshold: value)),
          title: const Text('Threshold'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: model.hasSill,
          onChanged: (value) => notifier.updateModel(model.copyWith(hasSill: value)),
          title: const Text('Window sill'),
        ),
        if (model.hasSill)
          MillimetreField(
            label: 'Sill projection',
            value: model.sillProjectionMm,
            onChanged: (value) => notifier.updateModel(model.copyWith(sillProjectionMm: value)),
          ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.warningSurface,
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Check before building',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $issue', style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RowEditor extends ConsumerWidget {
  final OpeningModel model;
  final int rowIndex;

  const _RowEditor({required this.model, required this.rowIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(designSessionProvider.notifier);
    final row = model.layout.rows[rowIndex];
    final solved = OpeningSolver.solve(model);
    final rowCells = solved.topCells.where((c) => c.rowIndex == rowIndex).toList();
    final rowHeight = rowCells.isEmpty ? 0.0 : rowCells.first.aperture.height;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Row ${rowIndex + 1} · ${row.cells.length} '
                      '${row.cells.length == 1 ? 'section' : 'sections'}'),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Add a mullion',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () =>
                      notifier.updateModel(ModelEditor.addMullion(model, rowIndex)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove a mullion',
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: row.cells.length > 1
                      ? () => notifier.updateModel(ModelEditor.removeMullion(model, rowIndex))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            MillimetreField(
              label: 'Row height',
              value: row.fixedHeightMm ?? rowHeight,
              helper: row.fixedHeightMm == null
                  ? 'Shared proportionally — type a number to pin it'
                  : 'Pinned',
              onChanged: (value) =>
                  notifier.updateModel(ModelEditor.setRowHeightMm(model, rowIndex, value)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CellEditor extends ConsumerWidget {
  final OpeningModel model;
  final SolvedCell cell;
  final bool selected;
  final VoidCallback onSelect;

  const _CellEditor({
    required this.model,
    required this.cell,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(designSessionProvider.notifier);
    final spec = cell.spec;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        color: selected ? AppColors.brandCreamSoft : null,
        border: selected
            ? Border.all(color: AppColors.brandDarkGreen.withValues(alpha: 0.5), width: 1.4)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onSelect,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Section ${cell.rowIndex + 1}.${cell.columnIndex + 1} · '
                      '${cell.aperture.width.round()} × ${cell.aperture.height.round()} mm',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(selected ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(height: AppSpacing.xs),
              _Dropdown<CellOperation>(
                label: 'Opens',
                value: spec.operation,
                items: CellOperation.values,
                labelOf: (o) => o.label,
                onChanged: (value) => notifier
                    .updateModel(ModelEditor.setCellOperation(model, spec.id, value)),
              ),
              const SizedBox(height: AppSpacing.xs),
              _Dropdown<CellInfill>(
                label: 'Filled with',
                value: spec.infill,
                items: CellInfill.values,
                labelOf: (i) => i.label,
                onChanged: (value) => notifier.updateModel(
                  ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(infill: value)),
                ),
              ),
              if (spec.infill == CellInfill.glass) ...[
                const SizedBox(height: AppSpacing.xs),
                _Dropdown<GlassType>(
                  label: 'Glass',
                  value: spec.glass,
                  items: GlassType.values,
                  labelOf: (g) => g.label,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(glass: value)),
                  ),
                ),
              ],
              if (spec.infill == CellInfill.panel || spec.infill == CellInfill.louvre) ...[
                const SizedBox(height: AppSpacing.xs),
                _Dropdown<PanelMaterial>(
                  label: 'Panel',
                  value: spec.panel,
                  items: PanelMaterial.values,
                  labelOf: (p) => p.label,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(panel: value)),
                  ),
                ),
              ],
              if (spec.operation.isOperable) ...[
                const SizedBox(height: AppSpacing.xs),
                _Dropdown<SwingDirection>(
                  label: 'Swing',
                  value: spec.swing,
                  items: SwingDirection.values,
                  labelOf: (s) => s.label,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(swing: value)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _Dropdown<HandleStyle>(
                  label: 'Handle',
                  value: spec.handle,
                  items: HandleStyle.values,
                  labelOf: (h) => h.label,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(handle: value)),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: spec.hasLock,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(hasLock: value)),
                  ),
                  title: const Text('Lock'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: spec.hasMesh,
                  onChanged: (value) => notifier.updateModel(
                    ModelEditor.updateCell(model, spec.id, (c) => c.copyWith(hasMesh: value)),
                  ),
                  title: const Text('Insect mesh'),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => notifier
                        .updateModel(ModelEditor.splitCellHorizontally(model, spec.id)),
                    icon: const Icon(Icons.splitscreen, size: 15),
                    label: const Text('Glass over panel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        notifier.updateModel(ModelEditor.mergeCell(model, spec.id)),
                    icon: const Icon(Icons.merge, size: 15),
                    label: const Text('Single pane'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
