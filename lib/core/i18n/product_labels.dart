import '../../domain/design_question.dart';
import '../../domain/layout/design_validator.dart';
import '../../domain/layout/note_resolver.dart';
import '../../domain/layout/width_solver.dart';
import '../../domain/measurement.dart';
import '../../domain/panel_note.dart';
import '../../domain/product/finish.dart';
import '../../domain/product/opening.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/product/profile_system.dart';
import '../units/length_unit.dart';
import 'strings.dart';

/// Translations for the things the domain names.
///
/// This is the one place a domain enum, a validator finding or an outstanding
/// question turns into words. It lives here, beside the phrases, rather than
/// in the UI, because the exported sheet needs exactly the same words as the
/// screen — and it reads them from the export layer.
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

  /// What a built-in profile system's numbers are based on. A system the
  /// factory adds later has no key, so its own words are shown.
  String profileAssumptions(ProfileSystem system) => switch (system.id) {
        'generic.pvc.casement' => call(T.assumptionsPvc),
        'generic.aluminium.casement' => call(T.assumptionsAluminium),
        _ => system.assumptions,
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

/// Turns what the domain found into a sentence in the user's language.
///
/// The domain reports a code and the numbers behind it; the words are written
/// here. That is what lets the same finding read correctly in English, Arabic
/// and Kurdish without the domain knowing any of them.
extension FindingLabels on AppStrings {
  /// A panel's name: the one the user gave it, or its number.
  String panelName({int? index, String? label}) =>
      label != null && label.isNotEmpty
          ? label
          : call(T.panelNumber, {
              'number': index == null ? '?' : number(index),
            });

  String question(DesignQuestion asked) => switch (asked.kind) {
        DesignQuestionKind.notInterpreted => call(T.askNotInterpreted),
        DesignQuestionKind.overallWidthMissing => call(T.askWidthMissing),
        DesignQuestionKind.overallWidthUnconfirmed => call(
            T.askWidthUnconfirmed,
            {'source': measurementSource(asked.source)},
          ),
        DesignQuestionKind.overallHeightMissing => call(T.askHeightMissing),
        DesignQuestionKind.overallHeightUnconfirmed => call(
            T.askHeightUnconfirmed,
            {'source': measurementSource(asked.source)},
          ),
        DesignQuestionKind.hingeSideUnconfirmed => call(T.askHingeSide, {
            'panel': panelName(label: asked.panelLabel ?? asked.panelId),
          }),
      };

  /// Where a measurement came from, for a sentence that has to say so.
  String measurementSource(MeasurementSource? source) => switch (source) {
        MeasurementSource.estimated => call(T.sourceEstimated),
        MeasurementSource.derived => call(T.sourceDerived),
        _ => call(T.sizeConfirmed),
      };

  String findingMessage(Finding finding) {
    final panel =
        panelName(index: finding.subjectNumber, label: finding.subjectLabel);
    String mm(String key) => length(
          finding.values[key] ?? 0,
          LengthUnit.millimetre,
        );

    return switch (finding.code) {
      FindingCode.widthMissing => call(T.findWidthMissing),
      FindingCode.widthNotPositive => call(T.findWidthNotPositive),
      FindingCode.heightMissing => call(T.findHeightMissing),
      FindingCode.heightNotPositive => call(T.findHeightNotPositive),
      FindingCode.fittingGapLeavesNoWidth => call(T.findFittingGapNoWidth, {
          'gap': mm('gap'),
          'opening': mm('opening'),
        }),
      FindingCode.fittingGapLeavesNoHeight => call(T.findFittingGapNoHeight),
      FindingCode.panelHasNoSize => call(T.findPanelHasNoSize, {'panel': panel}),
      FindingCode.panelUnderMinimum => call(T.findPanelUnderMinimum, {
          'panel': panel,
          'width': mm('width'),
          'height': mm('height'),
          'minimum': mm('minimum'),
        }),
      FindingCode.panelOutsideFrame =>
        call(T.findPanelOutsideFrame, {'panel': panel}),
      FindingCode.gapBetweenPanels =>
        call(T.findGapBetweenPanels, {'gap': mm('gap')}),
      FindingCode.panelsOverlap =>
        call(T.findPanelsOverlap, {'gap': mm('gap')}),
      FindingCode.rowDoesNotFillFrame => call(T.findRowDoesNotFillFrame, {
          'total': mm('total'),
          'frame': mm('frame'),
        }),
      FindingCode.openingNotConfirmed =>
        call(T.findOpeningNotConfirmed, {'panel': panel}),
      FindingCode.sashTooWide => call(T.findSashTooWide, {
          'panel': panel,
          'width': mm('width'),
          'limit': mm('limit'),
          'profile': finding.profileName ?? '',
        }),
      FindingCode.sashTooTall => call(T.findSashTooTall, {
          'panel': panel,
          'height': mm('height'),
          'limit': mm('limit'),
          'profile': finding.profileName ?? '',
        }),
    };
  }

  /// What happened to the notes on a panel that was split or merged.
  ///
  /// Null when nothing moved: there is nothing worth interrupting the user
  /// for.
  String? noteTransfers(List<NoteTransfer> transfers) {
    if (transfers.isEmpty) return null;
    final counts = NoteResolver.summarise(transfers);
    return [
      if (counts.moved > 0)
        call(T.notesMovedWithPanels, {'count': number(counts.moved)}),
      if (counts.lost > 0)
        call(T.notesRemovedNowhereToGo, {'count': number(counts.lost)}),
    ].join(' ');
  }

  /// Why a width could not be set, with the widest that would have worked.
  String widthRefusal(WidthRefused refusal) {
    String mm(String key) =>
        length(refusal.values[key] ?? 0, LengthUnit.millimetre);

    final reason = switch (refusal.code) {
      WidthRefusal.noPanelsToResize => call(T.refuseNoPanels),
      WidthRefusal.panelNotInRow => call(T.refuseNotInRow),
      WidthRefusal.onlyPanelInRow => call(T.refuseOnlyPanel),
      WidthRefusal.narrowerThanMinimum =>
        call(T.refuseTooNarrow, {'minimum': mm('minimum')}),
      WidthRefusal.neighbourWouldBeTooNarrow => call(T.refuseNotEnoughRoom, {
          'requested': mm('requested'),
          'neighbour': mm('neighbour'),
          'minimum': mm('minimum'),
        }),
    };

    final largest = refusal.largestWorkableMm;
    if (largest == null) return reason;
    return '$reason '
        '${call(T.refuseWidestIs, {
          'width': length(largest, LengthUnit.millimetre),
        })}';
  }

  String findingRemedy(Finding finding) => call(switch (finding.code) {
        FindingCode.widthMissing => T.fixWidthMissing,
        FindingCode.widthNotPositive => T.fixWidthNotPositive,
        FindingCode.heightMissing => T.fixHeightMissing,
        FindingCode.heightNotPositive => T.fixHeightNotPositive,
        FindingCode.fittingGapLeavesNoWidth => T.fixFittingGapWidth,
        FindingCode.fittingGapLeavesNoHeight => T.fixFittingGapHeight,
        FindingCode.panelHasNoSize => T.fixPanelHasNoSize,
        FindingCode.panelUnderMinimum => T.fixPanelUnderMinimum,
        FindingCode.panelOutsideFrame => T.fixPanelOutsideFrame,
        FindingCode.gapBetweenPanels => T.fixGapBetweenPanels,
        FindingCode.panelsOverlap => T.fixPanelsOverlap,
        FindingCode.rowDoesNotFillFrame => T.fixRowDoesNotFillFrame,
        FindingCode.openingNotConfirmed => T.fixOpeningNotConfirmed,
        FindingCode.sashTooWide => T.fixSashTooWide,
        FindingCode.sashTooTall => T.fixSashTooTall,
      });
}
