enum CameraPreset {
  perspective('perspective', '3D Isometric'),
  front('front', 'Front View'),
  back('back', 'Back View'),
  left('left', 'Left Side'),
  right('right', 'Right Side'),
  top('top', 'Top View');

  final String id;
  final String label;
  const CameraPreset(this.id, this.label);
}

class SceneSnapshot {
  final String base64Data;
  const SceneSnapshot(this.base64Data);
}
