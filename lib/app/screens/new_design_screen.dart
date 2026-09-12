import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/design/tokens.dart';
import '../../core/i18n/product_labels.dart';
import '../../core/i18n/strings.dart';
import '../../core/layout/responsive.dart';
import '../../core/layout/window_size.dart';
import '../../domain/design_document.dart';
import '../../domain/product/factory_settings.dart';
import '../../domain/product/finish.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/product/profile_system.dart';
import '../state/settings_controller.dart';
import '../widgets/choice_card.dart';
import '../widgets/notice.dart';

/// Creating a design: door or window, PVC or aluminium, colour and profile
/// system (spec section 3A).
///
/// The profile system is pre-selected from the factory default for the chosen
/// material, so a beginner never has to open it — but it is visible and
/// changeable, and the fact that the shipped systems are generic previews is
/// stated here rather than buried.
class NewDesignScreen extends ConsumerStatefulWidget {
  /// Called with the created design. Phase 2 hands this to the drawing canvas.
  final ValueChanged<DesignDocument> onCreated;

  /// Supplies the project id. Injected so tests get a stable one.
  final String Function() idFactory;

  /// Returns to the project list.
  final VoidCallback onBack;

  const NewDesignScreen({
    required this.onCreated,
    required this.idFactory,
    required this.onBack,
    super.key,
  });

  @override
  ConsumerState<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends ConsumerState<NewDesignScreen> {
  ProductCategory? _category;
  FrameMaterial? _material;
  Finish? _finish;
  ProfileSystem? _profile;

  /// The factory's defaults, so a beginner never has to answer a technical
  /// question that has already been answered once (spec section 9).
  FactorySettings get _settings => ref.watch(factorySettingsProvider);

  bool get _canContinue => _category != null && _material != null;

  void _selectMaterial(FrameMaterial material) {
    setState(() {
      _material = material;
      // Follows the material unless the user has since chosen a system that
      // belongs to it.
      if (_profile == null || _profile!.material != material) {
        _profile = GenericProfiles.defaultFor(material);
      }
    });
  }

  void _create() {
    final category = _category;
    final material = _material;
    if (category == null || material == null) return;

    final settings = _settings;
    final document = DesignDocument.blank(
      id: widget.idFactory(),
      category: category,
      material: material,
    ).copyWith(
      finish: _finish ?? settings.defaultFinish,
      profile: (_profile ?? GenericProfiles.defaultFor(material)).ref,
      // The factory's conventions, carried onto the project so they are
      // recorded with it rather than assumed later (spec sections 6 and 9).
      viewedFrom: settings.defaultViewingSide,
      dimensionReference: settings.defaultDimensionReference,
      fittingGapMm:
          settings.defaultDimensionReference == DimensionReference.wallOpening
              ? settings.fittingGapMm
              : 0,
      displayUnit: settings.displayUnit,
    );
    widget.onCreated(document);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.s(T.newDesign)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: context.s(T.backToProjects),
            onPressed: widget.onBack,
          ),
        ),
        body: SafeArea(
          child: ResponsiveBuilder(
            builder: (context, size) {
              final content = _Choices(
                category: _category,
                material: _material,
                finish: _finish ?? _settings.defaultFinish,
                profile: _profile,
                onCategory: (c) => setState(() => _category = c),
                onMaterial: _selectMaterial,
                onFinish: (f) => setState(() => _finish = f),
                onProfile: (p) => setState(() => _profile = p),
                twoColumn: size.widthClass != WindowWidthClass.compact,
              );

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        // Keeps line lengths readable on a wide desktop window
                        // instead of stretching the form across 1600px.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                  _ContinueBar(enabled: _canContinue, onPressed: _create),
                ],
              );
            },
          ),
        ),
      );
}

class _Choices extends StatelessWidget {
  final ProductCategory? category;
  final FrameMaterial? material;
  final Finish finish;
  final ProfileSystem? profile;
  final ValueChanged<ProductCategory> onCategory;
  final ValueChanged<FrameMaterial> onMaterial;
  final ValueChanged<Finish> onFinish;
  final ValueChanged<ProfileSystem> onProfile;
  final bool twoColumn;

  const _Choices({
    required this.category,
    required this.material,
    required this.finish,
    required this.profile,
    required this.onCategory,
    required this.onMaterial,
    required this.onFinish,
    required this.onProfile,
    required this.twoColumn,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(context.s(T.whatAreYouMaking)),
          _ChoiceRow(
            twoColumn: twoColumn,
            children: [
              for (final option in ProductCategory.values)
                ChoiceCard(
                  label: context.s.product(option),
                  icon: option == ProductCategory.door
                      ? Icons.door_front_door_outlined
                      : Icons.window_outlined,
                  selected: category == option,
                  onPressed: () => onCategory(option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Heading(context.s(T.whatIsItMadeFrom)),
          _ChoiceRow(
            twoColumn: twoColumn,
            children: [
              for (final option in FrameMaterial.values)
                ChoiceCard(
                  label: context.s.frameMaterial(option),
                  icon: Icons.layers_outlined,
                  selected: material == option,
                  onPressed: () => onMaterial(option),
                ),
            ],
          ),
          if (material != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Heading(context.s(T.colour)),
            Text(
              context.s(T.colourHelp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _FinishPicker(selected: finish, onSelected: onFinish),
            const SizedBox(height: AppSpacing.lg),
            _Heading(context.s(T.profileSystem)),
            _ProfilePicker(
              material: material!,
              selected: profile,
              onSelected: onProfile,
            ),
            const SizedBox(height: AppSpacing.sm),
            Notice(
              tone: NoticeTone.caution,
              title: context.s(T.previewProfilesTitle),
              message: context.s(T.previewProfilesHelp),
            ),
          ],
        ],
      );
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

/// Two choices side by side where there is room, stacked where there is not.
class _ChoiceRow extends StatelessWidget {
  final List<Widget> children;
  final bool twoColumn;

  const _ChoiceRow({required this.children, required this.twoColumn});

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) {
      return Column(
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: SizedBox(width: double.infinity, child: child),
            ),
        ],
      );
    }
    // IntrinsicHeight, because the row sits in a scroll view: a stretched
    // cross axis inside unbounded height is an infinite constraint. This gives
    // the two cards a shared height equal to the taller one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _FinishPicker extends StatelessWidget {
  final Finish selected;
  final ValueChanged<Finish> onSelected;

  const _FinishPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final finish in StockFinishes.all)
            _FinishSwatch(
              finish: finish,
              selected: finish == selected,
              onPressed: () => onSelected(finish),
            ),
        ],
      );
}

class _FinishSwatch extends StatelessWidget {
  final Finish finish;
  final bool selected;
  final VoidCallback onPressed;

  const _FinishSwatch({
    required this.finish,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: selected
            ? '${context.s.finishName(finish)}, ${context.s(T.selected)}'
            : context.s.finishName(finish),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              // The swatch itself is well under 48dp, so the row that carries
              // its name provides the touch target.
              constraints: const BoxConstraints(minHeight: AppSizing.minTouchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: selected ? AppColors.deepGreen : AppColors.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(finish.argb),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(context.s.finishName(finish)),
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(Icons.check, size: 18, color: AppColors.deepGreen),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _ProfilePicker extends StatelessWidget {
  final FrameMaterial material;
  final ProfileSystem? selected;
  final ValueChanged<ProfileSystem> onSelected;

  const _ProfilePicker({
    required this.material,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options =
        GenericProfiles.all.where((p) => p.material == material).toList();
    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ChoiceCard(
              label: context.s.profileName(option),
              description: context.s(T.profileFaceAndDepth, {
                'face': context.s.number(option.frameFaceMm),
                'depth': context.s.number(option.frameDepthMm),
              }),
              icon: Icons.view_in_ar_outlined,
              selected: selected?.id == option.id,
              onPressed: () => onSelected(option),
            ),
          ),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _ContinueBar({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!enabled)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  context.s(T.chooseProductAndMaterial),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
              ),
            FilledButton(
              onPressed: enabled ? onPressed : null,
              child: Text(context.s(T.startDrawing)),
            ),
          ],
        ),
      );
}
