import 'package:flutter/material.dart';

import '../../domain/model/design.dart';
import '../../domain/model/infill.dart';
import '../../domain/pricing/design_pricing.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/profile_category.dart';
import '../../domain/text/names.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// A change to a design's pricing choices, made by whoever is at the device
/// — [DesignPricing] refuses it where they may not.
typedef PricingOptionChange = Future<void> Function(
  Design Function(Authority by) change,
);

/// What the user says about a design's price that its drawing cannot: which
/// profile category its aluminium is — System or Bend Shoulder, for the
/// whole design or part by part — and whether its glass is charged for.
///
/// The same in the workspace's **Price** panel and on a design's price
/// sheet, so there is one way to say each. Nothing here is a figure: the
/// rates are the price list's, and the measurements the design's.
class PricingOptions extends StatefulWidget {
  final Design design;

  /// How a change is made; null where it cannot be made from here.
  final PricingOptionChange? onChange;

  const PricingOptions({super.key, required this.design, this.onChange});

  static const glassKey = ValueKey('pricing-options-glass');
  static const glassNoteKey = ValueKey('pricing-options-glass-note');
  static const categoryKey = ValueKey('pricing-options-category');
  static const eachKey = ValueKey('pricing-options-each');
  static ValueKey<String> partKey(String key) =>
      ValueKey('pricing-options-part-$key');

  /// What the category field says for nothing chosen.
  static const notSelected = 'Not selected';

  @override
  State<PricingOptions> createState() => _PricingOptionsState();
}

class _PricingOptionsState extends State<PricingOptions> {
  bool _each = false;

  @override
  Widget build(BuildContext context) {
    final design = widget.design;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final change = widget.onChange;
    final parts = [
      for (final part in ProfileAllocation.partsOf(design))
        if (ProfileCategory.divides(part.material)) part,
    ];
    final material = parts.firstOrNull?.material;
    final categories = material == null
        ? const <ProfileCategory>[]
        : ProfileCategory.of(material);
    final ownChoices = parts.any(
      (part) => design.pricing.profileCategoryOf.containsKey(part.key),
    );
    final hasGlass = Infill.partsOf(design)
        .any((x) => Infill.isGlass(x.finish));
    final glassOn = design.pricing.glassPriced;
    final l = context.l10n;
    final w = context.words;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parts.isNotEmpty) ...[
          DropdownButtonFormField<ProfileCategory?>(
            key: PricingOptions.categoryKey,
            initialValue: design.pricing.profileCategory,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.poProfileOf(material!.labelIn(w)),
              helperText: ownChoices
                  ? l.poSomeOwn
                  : design.pricing.profileCategory == null
                  ? l.poChooseProfile
                  : null,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<ProfileCategory?>(child: Text(w.notSelected)),
              for (final c in categories)
                DropdownMenuItem<ProfileCategory?>(
                  value: c,
                  child: Text(c.labelIn(w)),
                ),
            ],
            onChanged: change == null
                ? null
                : (c) => change(
                    (by) => DesignPricing.setProfileCategory(design, c, by: by),
                  ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: PricingOptions.eachKey,
              onPressed: () => setState(() => _each = !_each),
              icon: Icon(
                _each ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_each ? l.poHideParts : l.poEachPart),
            ),
          ),
          if (_each)
            for (final part in parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${part.nameIn(w)} · '
                        '${part.part.labelIn(w).toLowerCase()}',
                        style: text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: DropdownButton<ProfileCategory?>(
                        key: PricingOptions.partKey(part.key),
                        value: design.pricing.profileCategoryOf[part.key],
                        isExpanded: true,
                        isDense: true,
                        style: text.bodySmall,
                        hint: Text(
                          part.category == null
                              ? w.notSelected
                              : l.poAsDesignOf(part.category!.labelIn(w)),
                          style: text.bodySmall?.copyWith(color: p.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: [
                          DropdownMenuItem<ProfileCategory?>(
                            child: Text(l.poAsDesign),
                          ),
                          for (final c in categories)
                            DropdownMenuItem<ProfileCategory?>(
                              value: c,
                              child: Text(
                                c.labelIn(w),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: change == null
                            ? null
                            : (c) => change(
                                (by) => DesignPricing.setProfileCategory(
                                  design,
                                  c,
                                  part: part.key,
                                  by: by,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(child: Text(l.poIncludeGlass, style: text.bodyMedium)),
            Switch(
              key: PricingOptions.glassKey,
              value: glassOn,
              onChanged: change == null
                  ? null
                  : (on) => change(
                      (by) => DesignPricing.setGlassPriced(design, on, by: by),
                    ),
            ),
          ],
        ),
        Text(
          switch ((glassOn, hasGlass)) {
            (false, true) => l.poGlassMeasured,
            (false, false) => l.poGlassOff,
            (true, true) => l.poGlassCharged,
            (true, false) => l.poNoGlass,
          },
          key: PricingOptions.glassNoteKey,
          style: text.bodySmall?.copyWith(color: p.muted),
        ),
      ],
    );
  }
}
