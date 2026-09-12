import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units/length_unit.dart';

/// The unit the user types and reads dimensions in.
///
/// This is a display preference only. Every stored dimension is millimetres
/// (spec section 3D), so changing this never changes a design — a point the
/// tests assert rather than assume.
class DisplayUnitController extends Notifier<LengthUnit> {
  @override
  LengthUnit build() => LengthUnit.millimetre;

  void select(LengthUnit unit) => state = unit;
}

final displayUnitProvider =
    NotifierProvider<DisplayUnitController, LengthUnit>(DisplayUnitController.new);
