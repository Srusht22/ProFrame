import '../model/customer_discount.dart';
import '../model/elements.dart';
import '../model/materials.dart';
import '../model/payment.dart';
import '../model/surface.dart';
import '../pricing/price_list.dart';
import '../pricing/price_result.dart';
import '../pricing/profile_category.dart';
import '../pricing/quotation.dart';
import '../solid/camera.dart';
import 'words.dart';

// What each of the domain's choices is called, in a language.
//
// Every enum keeps its English `label`, which is what the domain's own
// tests and records read. These say the same in whichever [Words] they are
// handed — `labelIn(EnglishWords())` is the `label` exactly, and
// `test/app/the_words_are_one_set_test.dart` holds that — so a screen asks
// `kind.labelIn(context.words)` and never reads `label` itself.

extension DesignKindNames on DesignKind {
  String labelIn(Words w) => switch (this) {
    DesignKind.door => w.kindDoor,
    DesignKind.window => w.kindWindow,
    DesignKind.both => w.kindBoth,
    DesignKind.sliding => w.kindSliding,
    DesignKind.angled => w.kindAngled,
    DesignKind.unsupported => w.kindUnsupported,
  };

  /// What it is called in the middle of a sentence ([DesignKind.noun]).
  String nounIn(Words w) => switch (this) {
    DesignKind.door => w.nounDoor,
    DesignKind.window => w.nounWindow,
    DesignKind.both => w.nounBoth,
    DesignKind.sliding => w.nounSliding,
    DesignKind.angled => w.nounAngled,
    DesignKind.unsupported => w.nounUnsupported,
  };
}

extension ConstructionNames on Construction {
  String labelIn(Words w) => switch (this) {
    Construction.pending => w.constructionPending,
    Construction.panel => w.constructionPanel,
    Construction.glass => w.constructionGlass,
    Construction.both => w.constructionBoth,
  };
}

extension MaterialKindNames on MaterialKind {
  String labelIn(Words w) => switch (this) {
    MaterialKind.upvc => w.matUpvc,
    MaterialKind.aluminium => w.matAluminium,
    MaterialKind.wood => w.matWood,
    MaterialKind.steel => w.matSteel,
    MaterialKind.clearGlass => w.matClearGlass,
    MaterialKind.frostedGlass => w.matFrostedGlass,
    MaterialKind.tintedGlass => w.matTintedGlass,
    MaterialKind.panel => w.matPanel,
    MaterialKind.louvre => w.matLouvre,
    MaterialKind.mesh => w.matMesh,
    MaterialKind.rubber => w.matRubber,
  };
}

extension MaterialClassNames on MaterialClass {
  String labelIn(Words w) => switch (this) {
    MaterialClass.glass => w.classGlass,
    MaterialClass.panel => w.classPanel,
    MaterialClass.pvc => w.classPvc,
    MaterialClass.aluminium => w.classAluminium,
    MaterialClass.wood => w.classWood,
    MaterialClass.rubber => w.classRubber,
    MaterialClass.metal => w.classMetal,
    MaterialClass.handleMetal => w.classHandleMetal,
    MaterialClass.hingeMetal => w.classHingeMetal,
    MaterialClass.mesh => w.classMesh,
  };
}

extension HardwareColourNames on HardwareColour {
  String labelIn(Words w) => switch (this) {
    HardwareColour.black => w.colourBlack,
    HardwareColour.white => w.colourWhite,
    HardwareColour.silver => w.colourSilver,
    HardwareColour.grey => w.colourGrey,
    HardwareColour.bronze => w.colourBronze,
    HardwareColour.brown => w.colourBrown,
  };
}

extension GlassLookNames on GlassLook {
  String labelIn(Words w) => switch (this) {
    GlassLook.clear => w.glassClear,
    GlassLook.tinted => w.glassTinted,
    GlassLook.frosted => w.glassFrosted,
    GlassLook.dark => w.glassDark,
    GlassLook.blueGrey => w.glassBlueGrey,
  };
}

extension PanelColourNames on PanelColour {
  String labelIn(Words w) => switch (this) {
    PanelColour.white => w.colourWhite,
    PanelColour.black => w.colourBlack,
    PanelColour.grey => w.colourGrey,
    PanelColour.brown => w.colourBrown,
  };
}

/// What [english] — one of the names in [finishPalette], or anything else
/// a colour has been called — is called in [w]. A name that is not one of
/// the palette's is somebody's own and comes back as it was.
String paletteNameIn(Words w, String english) => switch (english) {
  'White' => w.colourWhite,
  'Off white' => w.colourOffWhite,
  'Cream' => w.colourCream,
  'Silver' => w.colourSilver,
  'Grey' => w.colourGrey,
  'Graphite' => w.colourGraphite,
  'Black' => w.colourBlack,
  'Deep green' => w.colourDeepGreen,
  'Steel blue' => w.colourSteelBlue,
  'Oak' => w.colourOak,
  'Walnut' => w.colourWalnut,
  'Oxblood' => w.colourOxblood,
  'Clear glass' => w.colourClearGlass,
  'Frosted' => w.colourFrosted,
  'Warm cream' => w.colourWarmCream,
  _ => english,
};

extension OpeningMechanismNames on OpeningMechanism {
  String labelIn(Words w) => switch (this) {
    OpeningMechanism.fixed => w.mechFixed,
    OpeningMechanism.hingedLeft => w.mechHingedLeft,
    OpeningMechanism.hingedRight => w.mechHingedRight,
    OpeningMechanism.topHung => w.mechTopHung,
    OpeningMechanism.bottomHung => w.mechBottomHung,
    OpeningMechanism.slidingLeft => w.mechSlidingLeft,
    OpeningMechanism.slidingRight => w.mechSlidingRight,
    OpeningMechanism.tiltAndTurn => w.mechTiltAndTurn,
    OpeningMechanism.bifold => w.mechBifold,
    OpeningMechanism.pivot => w.mechPivot,
  };

  /// [OpeningMechanism.description], in [w].
  String descriptionIn(Words w) => switch (this) {
    OpeningMechanism.fixed => w.mechFixedHint,
    OpeningMechanism.hingedLeft => w.mechHingedLeftHint,
    OpeningMechanism.hingedRight => w.mechHingedRightHint,
    OpeningMechanism.topHung => w.mechTopHungHint,
    OpeningMechanism.bottomHung => w.mechBottomHungHint,
    OpeningMechanism.slidingLeft => w.mechSlidingLeftHint,
    OpeningMechanism.slidingRight => w.mechSlidingRightHint,
    OpeningMechanism.tiltAndTurn => w.mechTiltAndTurnHint,
    OpeningMechanism.bifold => w.mechBifoldHint,
    OpeningMechanism.pivot => w.mechPivotHint,
  };
}

extension HardwareKindNames on HardwareKind {
  String labelIn(Words w) => switch (this) {
    HardwareKind.handle => w.hwHandle,
    HardwareKind.lever => w.hwLever,
    HardwareKind.knob => w.hwKnob,
    HardwareKind.lock => w.hwLock,
    HardwareKind.hinge => w.hwHinge,
    HardwareKind.letterplate => w.hwLetterplate,
    HardwareKind.peephole => w.hwPeephole,
    HardwareKind.closer => w.hwCloser,
    HardwareKind.pull => w.hwPull,
    HardwareKind.screen => w.hwScreen,
    HardwareKind.sensor => w.hwSensor,
  };
}

extension PaymentTypeNames on PaymentType {
  String labelIn(Words w) => switch (this) {
    PaymentType.payment => w.payTypePayment,
    PaymentType.refund => w.payTypeRefund,
  };
}

extension PaymentMethodNames on PaymentMethod {
  String labelIn(Words w) => switch (this) {
    PaymentMethod.cash => w.payCash,
    PaymentMethod.bankTransfer => w.payBankTransfer,
    PaymentMethod.card => w.payCard,
    PaymentMethod.other => w.payOther,
    PaymentMethod.legacy => w.payLegacy,
  };
}

extension DiscountKindNames on DiscountKind {
  String labelIn(Words w) => switch (this) {
    DiscountKind.percent => w.discountPercent,
    DiscountKind.fixed => w.discountFixed,
  };
}

extension ProjectionNames on Projection {
  String labelIn(Words w) => switch (this) {
    Projection.perspective => w.projectionPerspective,
    Projection.parallel => w.projectionParallel,
  };
}

extension PriceGroupNames on PriceGroup {
  String labelIn(Words w) => switch (this) {
    PriceGroup.normalProfile => w.groupNormalProfile,
    PriceGroup.openingProfile => w.groupOpeningProfile,
    PriceGroup.otherProfile => w.groupOtherProfile,
    PriceGroup.colour => w.groupColour,
    PriceGroup.glass => w.groupGlass,
    PriceGroup.panel => w.groupPanel,
    PriceGroup.hardware => w.groupHardware,
    PriceGroup.labour => w.groupLabour,
    PriceGroup.installation => w.groupInstallation,
  };
}

extension PriceUnitNames on PriceUnit {
  /// [PriceUnit.symbol], in [w]: only *each* is a word; the rest are the
  /// units every language here writes the same way.
  String symbolIn(Words w) => this == PriceUnit.each ? w.unitEach : symbol;
}

extension GlassStateNames on GlassState {
  /// [GlassState.words], in [w].
  String wordsIn(Words w) => switch (this) {
    GlassState.charged => '',
    GlassState.notIncluded => w.glassNotIncluded,
    GlassState.nothingToCharge => w.glassNothingToCharge,
    GlassState.notUsed => w.glassNotUsed,
  };
}

extension ProfileCategoryNames on ProfileCategory {
  String labelIn(Words w) => switch (this) {
    ProfileCategory.systemAluminium => w.catSystemAluminium,
    ProfileCategory.bendShoulderAluminium => w.catBendShoulderAluminium,
  };
}

extension ProfilePartNames on ProfilePart {
  String labelIn(Words w) => switch (this) {
    ProfilePart.border => w.partBorder,
    ProfilePart.lines => w.partLines,
  };
}

/// What a frame member placed at [english] — *Head*, *Left jamb*,
/// *Raking upper left side* (`Design.frameMembers`) — is called in [w].
String placementIn(Words w, String english) => switch (english) {
  'Head' => w.placeHead,
  'Sill' => w.placeSill,
  'Left jamb' => w.placeLeftJamb,
  'Right jamb' => w.placeRightJamb,
  'Raking upper left side' => w.placeRakingUpperLeft,
  'Raking upper right side' => w.placeRakingUpperRight,
  'Raking lower left side' => w.placeRakingLowerLeft,
  'Raking lower right side' => w.placeRakingLowerRight,
  _ => english,
};

extension ColourGradeNames on ColourGrade {
  String labelIn(Words w) => switch (this) {
    ColourGrade.standard => w.gradeStandard,
    ColourGrade.nonStandard => w.gradeNonStandard,
    ColourGrade.special => w.gradeSpecial,
  };
}

/// What [element] is called — [DesignElement.label] — in [w]. What the
/// user wrote (a note's text, a section they named) is theirs and comes
/// back as written; a figure is a figure.
String elementLabelIn(Words w, DesignElement element) => switch (element) {
  FrameElement() => w.elFrame,
  FrameMemberElement(:final placement) => placementIn(w, placement),
  DividerElement(:final isVertical, :final isHorizontal) =>
    isVertical
        ? w.elVerticalDivider
        : isHorizontal
        ? w.elHorizontalDivider
        : w.elAngledDivider,
  SectionElement(:final name) => name ?? w.elSection,
  OpeningElement(:final mechanism, :final markGlyph) =>
    switch (mechanism.glyph ?? markGlyph) {
      null => mechanism.labelIn(w),
      final glyph => '${mechanism.labelIn(w)}  $glyph',
    },
  HardwareElement(:final kind) => kind.labelIn(w),
  DimensionElement() => element.label,
  TextElement(:final text) => text.isEmpty ? w.elNote : text,
  ArrowElement() => w.elArrow,
};

extension QuotationStatusNames on QuotationStatus {
  String labelIn(Words w) => switch (this) {
    QuotationStatus.draft => w.qsDraft,
    QuotationStatus.issued => w.qsIssued,
    QuotationStatus.accepted => w.qsAccepted,
    QuotationStatus.rejected => w.qsRejected,
    QuotationStatus.expired => w.qsExpired,
  };
}

/// A category kept on a record by its English label — a quotation's line
/// — in [w]. The record is not changed; it is only read in [w]'s words.
String keptCategoryIn(Words w, String english) =>
    DesignKind.values
        .where((k) => k.label == english)
        .firstOrNull
        ?.labelIn(w) ??
    english;

/// A material kept on a record by its English label, in [w].
String keptMaterialIn(Words w, String english) => english == 'Not selected'
    ? w.notSelected
    : MaterialKind.values
              .where((m) => m.label == english)
              .firstOrNull
              ?.labelIn(w) ??
          english;

/// A colour kept on a record by its English name, in [w]: the palette's
/// names and *Not selected* or *Custom* are words; a catalog colour's name
/// is the factory's own and comes back as written.
String keptColourIn(Words w, String english) => switch (english) {
  'Not selected' => w.notSelected,
  'Custom' => w.custom,
  _ => paletteNameIn(w, english),
};
