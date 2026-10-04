/// What the pen does next.
///
/// Every one of these makes real geometry. None of them draws a picture of
/// something: a rectangle tool makes four lines that enclose a section, not
/// a rectangle-shaped image.
enum Tool {
  select('Select', 'Tap a part to pick it. Drag to move it.'),
  pen('Freehand',
      'Draw as you would on paper. Pause with the pen down to straighten.'),
  line('Straight line', 'Two taps, or drag from one end to the other.'),
  rectangle('Rectangle', 'Drag a corner to the opposite corner.'),
  polyline('Polyline', 'Tap each corner. Tap the first one again to close.'),
  dimension('Dimension', 'Drag between the two points you are measuring.'),
  arrow('Arrow', 'Drag from the tail to the point.'),
  text('Note', 'Tap where the note goes, then type it.'),
  eraser('Eraser', 'Tap a stroke to rub it out.');

  const Tool(this.label, this.hint);
  final String label;
  final String hint;

  /// True when using this tool lays down ink.
  bool get draws => switch (this) {
        pen || line || rectangle || polyline || dimension || arrow => true,
        select || text || eraser => false,
      };

  /// True when the tool builds structure rather than annotation.
  bool get structural => switch (this) {
        pen || line || rectangle || polyline => true,
        _ => false,
      };
}

/// What the workspace is showing.
enum WorkspaceView {
  /// The drawing, with the geometry read from it over the top.
  draw('Draw', 'Draw'),

  /// The technical drawing: the same geometry, drawn to drafting
  /// conventions and editable by taking hold of it.
  plan('CAD drawing', 'CAD'),

  /// The model.
  model('3D model', '3D');

  const WorkspaceView(this.label, this.shortLabel);
  final String label;

  /// What it is called where a phone leaves room for a word, not two.
  final String shortLabel;
}
