import 'package:flutter/material.dart';

enum CameraPreset {
  perspective('perspective', 'Perspective', Icons.view_in_ar_rounded),
  front('front', 'Front', Icons.crop_din_rounded),
  back('back', 'Back', Icons.flip_to_back_rounded),
  left('left', 'Left', Icons.chevron_left_rounded),
  right('right', 'Right', Icons.chevron_right_rounded),
  top('top', 'Top', Icons.vertical_align_top_rounded),
  bottom('bottom', 'Bottom', Icons.vertical_align_bottom_rounded);

  final String id;
  final String label;
  final IconData icon;
  const CameraPreset(this.id, this.label, this.icon);
}
