import 'package:flutter/material.dart';

import '../../domain/model/materials.dart';
import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/profile_selection.dart';
import '../theme/app_theme.dart';

/// The design's profile — its **Material** and its **Colour** — as its
/// price reads them, chosen from what the price list sells.
///
/// The materials are the ones the list prices a profile in. The colours are
/// the catalog's **active colours sold in the material** (`PriceList
/// .offeredFor`), in the factory's order, each with its swatch and its
/// name — no list of colours is written here. The colour the design is
/// already in is shown too where it is not among them: a retired colour
/// under its name, said to be retired beneath the field, a colour the catalog does not name as *special* — so choosing
/// a material never quietly repaints the design.
///
/// **A material is chosen without choosing a colour for the user.** The
/// colour goes with it; where the new material is not sold in it, the field
/// says *Please select a colour available for Aluminium* and the design is
/// not priced until one is chosen. Nothing here is a rate: what a choice
/// costs is the price list's, and the price is worked out again from it.
class ProfileChooser extends StatelessWidget {
  final ProfileSelection selection;

  /// The finish the frame is in now — what a material chosen before any
  /// colour is shown in, since it is the colour the design is drawn in.
  final Finish current;
  final PriceList list;

  /// Called with the profile chosen — the material, the colour it is drawn
  /// in and the catalog colour it is, where it is one; null where it cannot
  /// be changed here.
  final void Function(MaterialKind material, int colour, String? colourId)?
  onChanged;

  const ProfileChooser({
    super.key,
    required this.selection,
    required this.current,
    required this.list,
    required this.onChanged,
  });

  static const materialKey = ValueKey('profile-material');
  static const colourKey = ValueKey('profile-colour');

  /// A colour the catalog does not name, as the colour field holds it.
  static String _special(int colour) => '#$colour';

  @override
  Widget build(BuildContext context) {
    final material = selection.material;
    final colour = selection.colour;
    final materials = [
      ...profileMaterialsOf(list),
      if (material != null && !list.profiles.containsKey(material)) material,
    ];
    final colourMaterial = material ?? current.material;
    final pricing = selection.colourIn(list);
    final entry = selection.catalogColourIn(list);
    final offered = [
      for (final c in list.offeredFor(colourMaterial))
        (key: c.id, swatch: c.swatch, name: c.name),
    ];
    String? value;
    if (colour != null && !(pricing?.needsSelection ?? false)) {
      if (entry == null) {
        value = _special(colour);
        offered.add((
          key: value,
          swatch: colour,
          name: '${selection.colourName(list)} (special)',
        ));
      } else {
        value = entry.id;
        if (!offered.any((o) => o.key == entry.id)) {
          offered.add((key: entry.id, swatch: entry.swatch, name: entry.name));
        }
      }
    }
    final problem = pricing?.problem;
    // A retired colour the design is still in: said under the field, where
    // it is read whole, rather than cut off after the name.
    final retired = problem == null && entry != null && !entry.active
        ? 'Retired: no longer offered for new designs.'
        : null;
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
              // The colour goes with the material, as the catalog colour it
              // is: where the new material is not sold in it, the price
              // asks for one that is — none is chosen in its stead.
              onChanged: change == null
                  ? null
                  : (m) {
                      if (m != null) {
                        change(m, colour ?? current.colour, entry?.id);
                      }
                    },
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: field(
            key: colourKey,
            label: 'Colour',
            child: DropdownButtonFormField<String>(
              key: ValueKey(('colour', colourMaterial, value, problem)),
              initialValue: value,
              isExpanded: true,
              hint: const Text('Not selected'),
              decoration: InputDecoration(
                errorText: problem,
                errorMaxLines: 3,
                helperText: retired,
                helperMaxLines: 2,
              ),
              items: [
                for (final o in offered)
                  DropdownMenuItem(
                    value: o.key,
                    child: Row(
                      children: [
                        _Swatch(o.swatch),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            o.name,
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
                  : (key) {
                      if (key == null) return;
                      if (list.colourById(key) case final c?) {
                        change(colourMaterial, c.swatch, c.id);
                      } else if (colour != null && key == _special(colour)) {
                        change(colourMaterial, colour, null);
                      }
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
