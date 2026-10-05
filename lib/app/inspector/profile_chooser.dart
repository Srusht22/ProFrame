import 'package:flutter/material.dart';

import '../../domain/model/materials.dart';
import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/profile_selection.dart';
import '../theme/app_theme.dart';

/// The design's profile — its **Material** and its **Colour** — as its
/// price reads them, chosen from what the price list sells.
///
/// The materials are the ones the list prices a profile in, and each
/// material's colours are the ones the list names for it, each with its
/// swatch and its name. A colour the design is already in that the list
/// does not name is offered too, under its own name, so choosing a
/// material never quietly repaints the design. Nothing here is a rate:
/// what a choice costs is the price list's, and the price is worked out
/// again from it.
class ProfileChooser extends StatelessWidget {
  final ProfileSelection selection;

  /// The finish the frame is in now — what a material chosen before any
  /// colour is shown in, since it is the colour the design is drawn in.
  final Finish current;
  final PriceList list;

  /// Called with the profile chosen; null where it cannot be changed here.
  final void Function(MaterialKind material, int colour)? onChanged;

  const ProfileChooser({
    super.key,
    required this.selection,
    required this.current,
    required this.list,
    required this.onChanged,
  });

  static const materialKey = ValueKey('profile-material');
  static const colourKey = ValueKey('profile-colour');

  @override
  Widget build(BuildContext context) {
    final material = selection.material;
    final colour = selection.colour;
    final materials = [
      ...profileMaterialsOf(list),
      if (material != null && !list.profiles.containsKey(material)) material,
    ];
    final colourMaterial = material ?? current.material;
    final rates = list.profiles[colourMaterial]?.colours ?? const [];
    final offered = [
      for (final r in rates) (r.colour, r.name),
      if (colour != null && !rates.any((r) => r.colour == colour))
        (colour, '${selection.colourName(list)} (special)'),
    ];
    final change = onChanged;

    Widget field({
      required Key key,
      required String label,
      required Widget child,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        KeyedSubtree(key: key, child: child),
      ],
    );

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 220,
          child: field(
            key: materialKey,
            label: 'Material',
            child: DropdownButtonFormField<MaterialKind>(
              // A field reads its value once: keyed by it, so a profile
              // chosen anywhere else is shown here at once.
              key: ValueKey(('material', material)),
              initialValue: material,
              isExpanded: true,
              hint: const Text('Not selected'),
              items: [
                for (final m in materials)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: change == null
                  ? null
                  : (m) {
                      if (m != null) change(m, colour ?? current.colour);
                    },
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: field(
            key: colourKey,
            label: 'Colour',
            child: DropdownButtonFormField<int>(
              key: ValueKey(('colour', colourMaterial, colour)),
              initialValue: colour,
              isExpanded: true,
              hint: const Text('Not selected'),
              items: [
                for (final (value, name) in offered)
                  DropdownMenuItem(
                    value: value,
                    child: Row(
                      children: [
                        _Swatch(value),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: change == null
                  ? null
                  : (c) {
                      if (c != null) change(colourMaterial, c);
                    },
            ),
          ),
        ),
      ],
    );
  }
}

/// A colour's swatch, beside its name — never instead of it.
class _Swatch extends StatelessWidget {
  final int colour;

  const _Swatch(this.colour);

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: Color(colour),
      shape: BoxShape.circle,
      border: Border.all(color: context.palette.hairline),
    ),
  );
}

/// [colour]'s swatch, for a line that names it.
Widget colourSwatch(int colour) => _Swatch(colour);
