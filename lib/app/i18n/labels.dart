import '../../core/i18n/strings.dart';
import '../../core/units/length_unit.dart';
import '../../domain/product/finish.dart';
import '../../domain/product/opening.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/product/profile_system.dart';

/// Translations for the things the domain names.
///
/// The domain keeps its own English labels — they are what a stored file and a
/// log say, and they must not change when a user picks another language. This
/// extension is the one place that maps them onto what is shown.
extension ProductLabels on AppStrings {
  String product(ProductCategory category) => call(switch (category) {
        ProductCategory.door => T.productDoor,
        ProductCategory.window => T.productWindow,
      });

  String frameMaterial(FrameMaterial material) => call(switch (material) {
        FrameMaterial.pvc => T.materialPvc,
        FrameMaterial.aluminium => T.materialAluminium,
      });

  String viewingSide(ViewingSide side) => call(switch (side) {
        ViewingSide.outside => T.viewedFromOutside,
        ViewingSide.inside => T.viewedFromInside,
      });

  String dimensionReference(DimensionReference reference) =>
      call(switch (reference) {
        DimensionReference.outerFrame => T.dimensionOuterFrame,
        DimensionReference.wallOpening => T.dimensionWallOpening,
      });

  String dimensionReferenceHelp(DimensionReference reference) =>
      call(switch (reference) {
        DimensionReference.outerFrame => T.dimensionOuterFrameHelp,
        DimensionReference.wallOpening => T.dimensionWallOpeningHelp,
      });

  String behaviour(PanelBehaviour behaviour) => call(switch (behaviour) {
        PanelBehaviour.fixed => T.behaviourFixed,
        PanelBehaviour.opening => T.behaviourOpening,
      });

  String behaviourHelp(PanelBehaviour behaviour) => call(switch (behaviour) {
        PanelBehaviour.fixed => T.behaviourFixedHelp,
        PanelBehaviour.opening => T.behaviourOpeningHelp,
      });

  String mechanism(OpeningMechanism mechanism) => call(switch (mechanism) {
        OpeningMechanism.hinged => T.mechanismHinged,
        OpeningMechanism.tilt => T.mechanismTilt,
        OpeningMechanism.slidingLeft => T.mechanismSlidingLeft,
        OpeningMechanism.slidingRight => T.mechanismSlidingRight,
      });

  String mechanismHelp(OpeningMechanism mechanism) => call(switch (mechanism) {
        OpeningMechanism.hinged => T.mechanismHingedHelp,
        OpeningMechanism.tilt => T.mechanismTiltHelp,
        OpeningMechanism.slidingLeft => T.mechanismSlidingLeftHelp,
        OpeningMechanism.slidingRight => T.mechanismSlidingRightHelp,
      });

  String hingeSide(HingeSide side) => call(switch (side) {
        HingeSide.left => T.hingeLeft,
        HingeSide.right => T.hingeRight,
        HingeSide.top => T.hingeTop,
        HingeSide.bottom => T.hingeBottom,
      });

  String openingDirection(OpeningDirection direction) =>
      call(switch (direction) {
        OpeningDirection.inward => T.opensInward,
        OpeningDirection.outward => T.opensOutward,
      });

  /// A stock finish's name. A colour the factory adds later has no key, so its
  /// own name is shown rather than a blank.
  String finishName(Finish finish) => switch (finish.id) {
        'white' => call(T.finishWhite),
        'cream' => call(T.finishCream),
        'grey' => call(T.finishGrey),
        'anthracite' => call(T.finishAnthracite),
        'black' => call(T.finishBlack),
        'brown' => call(T.finishBrown),
        'golden_oak' => call(T.finishGoldenOak),
        _ => finish.name,
      };

  /// A built-in profile system's name; anything else keeps its own.
  String profileName(ProfileSystem system) => switch (system.id) {
        'generic.pvc.casement' => call(T.profileGenericPvc),
        'generic.aluminium.casement' => call(T.profileGenericAluminium),
        _ => system.name,
      };

  /// What an opening does, in one line, always saying which side it is read
  /// from — handing means nothing without that (spec section 3C).
  String openingSummary(OpeningSpec opening, ViewingSide viewedFrom) {
    final parts = <String>[
      if (opening.mechanism.needsHingeSide)
        hingeSide(opening.hingeSide)
      else
        mechanism(opening.mechanism),
      if (opening.mechanism.needsSwingDirection)
        openingDirection(opening.direction),
    ];
    return '${parts.join(' · ')} (${viewingSide(viewedFrom)})';
  }

  String unitName(LengthUnit unit) => call(switch (unit) {
        LengthUnit.millimetre => T.unitMillimetreName,
        LengthUnit.centimetre => T.unitCentimetreName,
        LengthUnit.metre => T.unitMetreName,
        LengthUnit.inch => T.unitInchName,
      });
}
