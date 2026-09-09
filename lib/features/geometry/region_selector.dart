import '../../shared/models/design_region.dart';
import '../../shared/models/opening_model.dart';

/// How an instruction names a section: by where it is, by what fills it, or
/// simply as the one currently selected.
class RegionSelector {
  final String? id;
  final RegionAnchor? position;
  final CellInfill? infill;
  final bool operableOnly;

  /// "this", "that", "it" — whatever the user has selected.
  final bool useSelection;

  const RegionSelector({
    this.id,
    this.position,
    this.infill,
    this.operableOnly = false,
    this.useSelection = false,
  });

  static const RegionSelector selection = RegionSelector(useSelection: true);

  bool get isEmpty =>
      id == null && position == null && infill == null && !operableOnly && !useSelection;

  String describe() {
    if (id != null) return 'section $id';
    if (useSelection) return 'the selected section';
    final parts = <String>[
      if (position != null) position!.label,
      if (infill != null) infill!.label.toLowerCase(),
      if (operableOnly) 'opening',
    ];
    return parts.isEmpty ? 'the design' : 'the ${parts.join(' ')}';
  }
}

/// The outcome of looking a selector up.
class SelectorMatch {
  final String? id;
  final String? problem;

  const SelectorMatch.found(this.id) : problem = null;
  const SelectorMatch.missing(this.problem) : id = null;

  bool get isFound => id != null;
}

/// Resolves a selector against a design.
///
/// When more than one section fits equally well the resolver refuses rather
/// than picking one, so an instruction can never quietly change the wrong part
/// of the design.
class RegionResolver {
  const RegionResolver();

  SelectorMatch resolve(
    OpeningModel model,
    RegionSelector selector, {
    String? selectedId,
  }) {
    if (selector.id != null) {
      final exists = model.region(selector.id!) != null;
      return exists
          ? SelectorMatch.found(selector.id)
          : SelectorMatch.missing('There is no section called ${selector.id}.');
    }

    if (selector.useSelection) {
      if (selectedId != null && model.region(selectedId) != null) {
        return SelectorMatch.found(selectedId);
      }
      return const SelectorMatch.missing(
        'Nothing is selected. Tap the section you mean first.',
      );
    }

    var candidates = model.allRegions.toList();
    if (selector.infill != null) {
      candidates = candidates.where((r) => r.infill == selector.infill).toList();
    }
    if (selector.operableOnly) {
      candidates = candidates.where((r) => r.operation.isOperable).toList();
    }

    if (candidates.isEmpty) {
      return SelectorMatch.missing(
        'No section matches ${selector.describe()}.',
      );
    }

    if (selector.position != null) {
      candidates = _byPosition(model, candidates, selector.position!);
    }

    if (candidates.length == 1) return SelectorMatch.found(candidates.first.id);
    if (candidates.isEmpty) {
      return SelectorMatch.missing('No section matches ${selector.describe()}.');
    }

    // A tie: pick the largest only when it is clearly the largest, otherwise
    // ask instead of guessing.
    candidates.sort((a, b) => (b.rect.area).compareTo(a.rect.area));
    final biggest = candidates[0].rect.area;
    final runnerUp = candidates[1].rect.area;
    if (biggest > runnerUp * 1.2) return SelectorMatch.found(candidates.first.id);

    return SelectorMatch.missing(
      '${selector.describe()} could mean ${candidates.length} different '
      'sections. Tap the one you mean and say "this one".',
    );
  }

  /// Narrows to the sections furthest towards the named side, keeping ties.
  List<DesignRegion> _byPosition(
    OpeningModel model,
    List<DesignRegion> candidates,
    RegionAnchor position,
  ) {
    double score(DesignRegion r) => switch (position) {
          RegionAnchor.centreLeft || RegionAnchor.topLeft || RegionAnchor.bottomLeft =>
            r.rect.left,
          RegionAnchor.centreRight ||
          RegionAnchor.topRight ||
          RegionAnchor.bottomRight =>
            -r.rect.right,
          RegionAnchor.topCentre => r.rect.top,
          RegionAnchor.bottomCentre => -r.rect.bottom,
          RegionAnchor.centre => (r.rect.center - model.outerRect.center).length,
        };

    // Corner anchors need both axes to agree.
    double secondary(DesignRegion r) => switch (position) {
          RegionAnchor.topLeft || RegionAnchor.topRight => r.rect.top,
          RegionAnchor.bottomLeft || RegionAnchor.bottomRight => -r.rect.bottom,
          _ => 0,
        };

    final ranked = [...candidates]..sort((a, b) {
        final primary = score(a).compareTo(score(b));
        return primary != 0 ? primary : secondary(a).compareTo(secondary(b));
      });
    final best = score(ranked.first);
    final bestSecondary = secondary(ranked.first);
    return ranked
        .where((r) =>
            (score(r) - best).abs() < 1 && (secondary(r) - bestSecondary).abs() < 1)
        .toList();
  }
}
