import 'package:flutter/material.dart';

/// The two manufacturing product families. Everything downstream
/// (validation ranges, 3D generation, pricing formulas) branches on this.
enum ProductCategory {
  door('Door', Icons.door_front_door_rounded),
  window('Window', Icons.window_rounded);

  final String label;
  final IconData icon;
  const ProductCategory(this.label, this.icon);
}

enum DoorType {
  interior('Interior Door', 'Lightweight internal partition door'),
  exterior('Exterior Door', 'Weather-sealed external entry door'),
  entrance('Entrance Door', 'Reinforced main entrance security door'),
  sliding('Sliding Door', 'Track-mounted horizontal sliding door'),
  folding('Folding Door', 'Multi-panel concertina folding door'),
  custom('Custom Door', 'Custom engineered configuration');

  final String label;
  final String description;
  const DoorType(this.label, this.description);
}

enum WindowType {
  fixed('Fixed', 'Non-opening picture window'),
  sliding('Sliding', 'Horizontal sliding sashes'),
  casement('Casement', 'Side-hinged outward swinging sash'),
  tiltAndTurn('Tilt & Turn', 'Dual-action tilt ventilation or full swing'),
  awning('Awning', 'Top-hinged outward opening sash'),
  doubleWindow('Double Window', 'Two coupled window units'),
  tripleWindow('Triple Window', 'Three coupled window units'),
  custom('Custom Window', 'Custom engineered configuration');

  final String label;
  final String description;
  const WindowType(this.label, this.description);
}

enum LeafArrangement {
  single('Single Leaf', 1),
  double_('Double Leaf (Equal)', 2),
  unequalDouble('Double Leaf (Unequal)', 2),
  doorPlusFixed('Leaf + Fixed Panel', 1),
  custom('Custom Arrangement', 0);

  final String label;

  /// Number of *operable* leaves this arrangement implies by default.
  final int operableLeaves;
  const LeafArrangement(this.label, this.operableLeaves);
}

enum FrameMaterial {
  aluminum('Aluminum', 'Powder-coated extruded aluminum profile'),
  upvc('uPVC', 'Multi-chamber uPVC profile'),
  wood('Timber', 'Engineered hardwood profile'),
  steel('Steel', 'Thermally-broken steel profile');

  final String label;
  final String description;
  const FrameMaterial(this.label, this.description);
}

enum PanelType {
  solid('Solid Panel', 'Insulated opaque panel'),
  glass('Glass Panel', 'Full glazed panel'),
  decorative('Decorative Panel', 'Moulded or louvered decorative panel');

  final String label;
  final String description;
  const PanelType(this.label, this.description);
}

enum GlassType {
  clear('Clear', 'High clarity float glass', Color(0xFFDCEAF0)),
  frosted('Frosted', 'Acid-etched satin privacy glass', Color(0xFFE9EEEF)),
  tinted('Tinted', 'Solar control tinted glass', Color(0xFF7C8B90)),
  tempered('Tempered', 'Heat-strengthened safety glass', Color(0xFFCFE1E8)),
  laminated('Laminated', 'PVB-interlayer security glass', Color(0xFFC9DDE4)),
  doubleGlazed('Double Glazed', 'Insulated double-pane unit', Color(0xFFB9D3DC)),
  tripleGlazed('Triple Glazed', 'Insulated triple-pane unit', Color(0xFFA6C6D1)),
  custom('Custom Glass', 'Custom specification glass', Color(0xFFD8E4E8));

  final String label;
  final String description;
  final Color previewColor;
  const GlassType(this.label, this.description, this.previewColor);
}

enum HandleModel {
  standardLever('Standard Lever', 0),
  premiumLever('Premium Lever', 45),
  pullBar('Architectural Pull Bar', 30),
  flushLatch('Flush Sash Latch', -10),
  none('None', -100);

  final String label;

  /// Relative price adjustment (currency units) applied on top of the base
  /// handle price in the pricing engine's hardware pricing table.
  final double relativePriceAdjustment;
  const HandleModel(this.label, this.relativePriceAdjustment);
}

enum LockType {
  none('None'),
  standardCylinder('Standard Cylinder'),
  multiPointLock('Multi-Point Lock'),
  mortiseKeyLock('Mortise Key Lock'),
  smartLock('Smart / Digital Lock');

  final String label;
  const LockType(this.label);
}

enum DoorCloserType {
  none('None'),
  standard('Standard Overhead Closer'),
  concealed('Concealed Closer'),
  floorSpring('Floor Spring');

  final String label;
  const DoorCloserType(this.label);
}

enum FrameColor {
  white('White', Color(0xFFF5F5F0)),
  black('Black', Color(0xFF1C1F1E)),
  darkGreen('ProFrame Green', Color(0xFF013E37)),
  woodFinish('Wood Finish', Color(0xFF6B4A2F)),
  anthracite('Anthracite', Color(0xFF383D3C)),
  silver('Anodized Silver', Color(0xFFC7CCC9)),
  bronze('Bronze', Color(0xFF4A3B30)),
  custom('Custom Color', Color(0xFF888888));

  final String label;
  final Color swatch;
  const FrameColor(this.label, this.swatch);
}

enum OpeningDirection {
  leftHinge('Hinged Left', 'Leaf swings on the left side'),
  rightHinge('Hinged Right', 'Leaf swings on the right side'),
  slideLeft('Slide Left', 'Active sash slides left'),
  slideRight('Slide Right', 'Active sash slides right'),
  bothActive('Both Active', 'Both leaves operable'),
  fixed('Fixed', 'Does not open');

  final String label;
  final String description;
  const OpeningDirection(this.label, this.description);
}

enum ProductConfigState {
  draft('Draft'),
  validated('Validated'),
  quoted('Quoted'),
  approved('Approved'),
  productionReady('Production Ready');

  final String label;
  const ProductConfigState(this.label);

  /// Enforces "only valid configurations can advance to production".
  bool get canAdvanceToProduction => this == productionReady;
}
