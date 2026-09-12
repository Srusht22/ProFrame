import '../geometry/point2.dart';
import '../panel.dart';
import '../panel_note.dart';

/// The outcome of moving notes when panels change shape.
class NoteResolution {
  /// The panels, with the notes placed on them.
  final List<Panel> panels;

  /// What happened to every note that moved, for telling the user.
  final List<NoteTransfer> transfers;

  const NoteResolution({required this.panels, required this.transfers});

  /// Notes that could not be placed anywhere.
  List<NoteTransfer> get lost =>
      transfers.where((t) => !t.wasKept).toList();

  bool get anythingMoved => transfers.isNotEmpty;
}

/// Decides where a panel's notes go when that panel stops existing.
///
/// Splitting and merging change which panels exist, and their notes have to go
/// somewhere the user can predict. The spec forbids silently discarding them
/// or silently putting them on the wrong half (section 8B), so every decision
/// here is recorded as a [NoteTransfer] and shown.
///
/// **The rule is geometric.** A note stays with whichever new panel covers the
/// place it was sitting. That matches what the user sees: a remark written on
/// the left of a pane stays on the left half when the pane is cut in two.
abstract final class NoteResolver {
  /// Distributes [source]'s notes across the panels that replaced it.
  ///
  /// [source] is the panel being split; [replacements] are the new panels, in
  /// model space. A note whose position falls inside one of them moves there,
  /// keeping its position relative to its new panel so the label does not
  /// jump.
  static NoteResolution afterSplit(
    Panel source,
    List<Panel> replacements,
  ) {
    if (replacements.isEmpty) {
      return NoteResolution(
        panels: const [],
        transfers: [
          for (final note in source.notes)
            NoteTransfer(
              noteId: note.id,
              text: note.text,
              fromPanelId: source.id,
              explanation: 'The panel it was on no longer exists.',
            ),
        ],
      );
    }

    final box = source.boundary;
    final buckets = <String, List<PanelNote>>{
      for (final panel in replacements) panel.id: [],
    };
    final transfers = <NoteTransfer>[];

    for (final note in source.notes) {
      // Where the label actually sat, in millimetres.
      final at = Point2(
        box.left + note.position.x * box.width,
        box.top + note.position.y * box.height,
      );

      final home = replacements.firstWhere(
        (panel) => panel.boundary.contains(at),
        // A note sitting exactly on the cut belongs to the larger half: the
        // one more likely to be what the remark was about.
        orElse: () => replacements.reduce(
          (a, b) => a.areaMm2 >= b.areaMm2 ? a : b,
        ),
      );

      final homeBox = home.boundary;
      buckets[home.id]!.add(
        note.copyWith(
          // Re-expressed against its new panel, so the label stays under the
          // user's finger rather than jumping to a corner.
          position: Point2(
            homeBox.width == 0 ? 0.5 : (at.x - homeBox.left) / homeBox.width,
            homeBox.height == 0 ? 0.5 : (at.y - homeBox.top) / homeBox.height,
          ),
        ),
      );
      transfers.add(
        NoteTransfer(
          noteId: note.id,
          text: note.text,
          fromPanelId: source.id,
          toPanelId: home.id,
          explanation: 'Moved to the part of the panel it was written on.',
        ),
      );
    }

    return NoteResolution(
      panels: [
        for (final panel in replacements)
          panel.copyWith(notes: buckets[panel.id]!),
      ],
      transfers: transfers,
    );
  }

  /// Gathers the notes of two panels onto the panel that replaced them.
  ///
  /// Nothing is dropped: a merged pane carries both sets of remarks, because
  /// deciding that one of them no longer applies is the user's call, not the
  /// app's.
  static NoteResolution afterMerge(
    List<Panel> sources,
    Panel merged,
  ) {
    final mergedBox = merged.boundary;
    final notes = <PanelNote>[];
    final transfers = <NoteTransfer>[];

    for (final source in sources) {
      final box = source.boundary;
      for (final note in source.notes) {
        final at = Point2(
          box.left + note.position.x * box.width,
          box.top + note.position.y * box.height,
        );
        notes.add(
          note.copyWith(
            position: Point2(
              mergedBox.width == 0
                  ? 0.5
                  : (at.x - mergedBox.left) / mergedBox.width,
              mergedBox.height == 0
                  ? 0.5
                  : (at.y - mergedBox.top) / mergedBox.height,
            ),
          ),
        );
        transfers.add(
          NoteTransfer(
            noteId: note.id,
            text: note.text,
            fromPanelId: source.id,
            toPanelId: merged.id,
            explanation: 'Kept on the panel the two became.',
          ),
        );
      }
    }

    return NoteResolution(
      panels: [merged.copyWith(notes: notes)],
      transfers: transfers,
    );
  }

  /// How many notes moved and how many could not be kept.
  ///
  /// Counts rather than a sentence, so the words can be written in the user's
  /// language where they are shown.
  static ({int moved, int lost}) summarise(List<NoteTransfer> transfers) {
    final lost = transfers.where((t) => !t.wasKept).length;
    return (moved: transfers.length - lost, lost: lost);
  }

  /// A sentence summarising [transfers] in English, or null when nothing
  /// moved. Kept for logs and tests; the UI writes its own from [summarise].
  static String? describe(List<NoteTransfer> transfers) {
    if (transfers.isEmpty) return null;
    final lost = transfers.where((t) => !t.wasKept).length;
    final moved = transfers.length - lost;
    return [
      if (moved == 1)
        '1 note moved with its panel.'
      else if (moved > 1)
        '$moved notes moved with their panels.',
      if (lost == 1)
        '1 note had nowhere to go and was removed.'
      else if (lost > 1)
        '$lost notes had nowhere to go and were removed.',
    ].join(' ');
  }
}
