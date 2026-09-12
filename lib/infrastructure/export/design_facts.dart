import '../../core/i18n/product_labels.dart';
import '../../core/i18n/strings.dart';
import '../../domain/design_document.dart';

/// The facts an export sheet states about a design, already in words.
///
/// Assembled from the document, so nothing in a PDF can be invented
/// (spec section 8A: "never invent information in the summary"), and
/// assembled *here* rather than in the domain, because the sheet is written
/// in whatever language the app is set to — and the domain has no language.
class DesignFacts {
  final String projectName;
  final String category;
  final String material;
  final String finish;
  final String profile;
  final bool profileIsGeneric;
  final String profileAssumptions;
  final String size;
  final bool sizeConfirmed;
  final String viewedFrom;
  final String dimensionReference;
  final String dimensionReferenceDetail;
  final int fixedCount;
  final int openingCount;
  final String designNote;

  /// Everything still unanswered, for the warning block.
  final List<String> outstanding;

  const DesignFacts({
    required this.projectName,
    required this.category,
    required this.material,
    required this.finish,
    required this.profile,
    required this.profileIsGeneric,
    required this.profileAssumptions,
    required this.size,
    required this.sizeConfirmed,
    required this.viewedFrom,
    required this.dimensionReference,
    required this.dimensionReferenceDetail,
    required this.fixedCount,
    required this.openingCount,
    required this.designNote,
    required this.outstanding,
  });

  static DesignFacts of(DesignDocument design, AppStrings strings) {
    final unit = design.displayUnit;
    final width = design.overallWidth;
    final height = design.overallHeight;
    final profile = design.profileSystem;

    return DesignFacts(
      projectName: design.name,
      category: strings.product(design.category),
      material: strings.frameMaterial(design.material),
      finish: strings.finishName(design.finish),
      profile: strings.profileName(profile),
      profileIsGeneric: profile.isGeneric,
      profileAssumptions: strings.profileAssumptions(profile),
      size: width == null || height == null
          ? strings(T.sheetNotMeasured)
          : '${strings.length(width.millimetres, unit)} × '
              '${strings.length(height.millimetres, unit)}',
      sizeConfirmed: design.hasConfirmedSize,
      viewedFrom: strings.viewingSide(design.viewedFrom),
      dimensionReference: strings.dimensionReference(design.dimensionReference),
      dimensionReferenceDetail:
          strings.dimensionReferenceHelp(design.dimensionReference) +
              (design.fittingGapMm > 0
                  ? ' ${strings(T.sheetFittingGapDetail, {
                        'gap': strings.length(design.fittingGapMm, unit),
                        'width': strings.length(design.frameWidthMm ?? 0, unit),
                        'height':
                            strings.length(design.frameHeightMm ?? 0, unit),
                      })}'
                  : ''),
      fixedCount: design.fixedPanelCount,
      openingCount: design.openingPanelCount,
      designNote: design.designNote.trim(),
      outstanding: [
        for (final question in design.outstandingQuestions)
          strings.question(question),
      ],
    );
  }
}
