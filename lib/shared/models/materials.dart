/// Frame material. Each one carries the real profile dimensions a fabricator
/// works with, so the 3D model has honest depth and face widths rather than
/// arbitrary thicknesses (spec §21, §24).
enum FrameMaterial { aluminium, upvc, steel, wood }

extension FrameMaterialInfo on FrameMaterial {
  String get label => switch (this) {
        FrameMaterial.aluminium => 'Aluminium',
        FrameMaterial.upvc => 'uPVC',
        FrameMaterial.steel => 'Steel',
        FrameMaterial.wood => 'Wood',
      };

  /// Depth of the outer frame, front to back, in millimetres.
  double get frameDepthMm => switch (this) {
        FrameMaterial.aluminium => 62,
        FrameMaterial.upvc => 70,
        FrameMaterial.steel => 55,
        FrameMaterial.wood => 68,
      };

  /// Visible face width of the outer frame in elevation.
  double get frameFaceMm => switch (this) {
        FrameMaterial.aluminium => 50,
        FrameMaterial.upvc => 62,
        FrameMaterial.steel => 42,
        FrameMaterial.wood => 68,
      };

  /// Visible face width of a sash / leaf profile.
  double get sashFaceMm => switch (this) {
        FrameMaterial.aluminium => 42,
        FrameMaterial.upvc => 58,
        FrameMaterial.steel => 38,
        FrameMaterial.wood => 60,
      };

  double get sashDepthMm => frameDepthMm - 12;

  /// Face width of a mullion or transom bar.
  double get mullionFaceMm => switch (this) {
        FrameMaterial.aluminium => 52,
        FrameMaterial.upvc => 64,
        FrameMaterial.steel => 44,
        FrameMaterial.wood => 70,
      };

  /// Surface roughness used by the renderer; wood and uPVC are matte,
  /// aluminium is satin, steel is more reflective.
  double get roughness => switch (this) {
        FrameMaterial.aluminium => 0.42,
        FrameMaterial.upvc => 0.68,
        FrameMaterial.steel => 0.32,
        FrameMaterial.wood => 0.75,
      };

  double get metalness => switch (this) {
        FrameMaterial.aluminium => 0.85,
        FrameMaterial.upvc => 0.0,
        FrameMaterial.steel => 0.95,
        FrameMaterial.wood => 0.0,
      };

  /// Kilograms per metre of profile — used by the pricing engine.
  double get kgPerMetre => switch (this) {
        FrameMaterial.aluminium => 1.35,
        FrameMaterial.upvc => 1.15,
        FrameMaterial.steel => 3.10,
        FrameMaterial.wood => 2.20,
      };
}

/// Finish applied to the frame. Colour is what the renderer paints; the finish
/// also changes how glossy the surface is.
enum FrameFinish {
  naturalAnodised,
  whitePowder,
  blackPowder,
  anthracite,
  bronze,
  goldenOak,
  walnut,
}

extension FrameFinishInfo on FrameFinish {
  String get label => switch (this) {
        FrameFinish.naturalAnodised => 'Natural anodised',
        FrameFinish.whitePowder => 'White',
        FrameFinish.blackPowder => 'Black',
        FrameFinish.anthracite => 'Anthracite grey',
        FrameFinish.bronze => 'Bronze',
        FrameFinish.goldenOak => 'Golden oak',
        FrameFinish.walnut => 'Walnut',
      };

  /// 0xRRGGBB.
  int get colorValue => switch (this) {
        FrameFinish.naturalAnodised => 0xC9CDD1,
        FrameFinish.whitePowder => 0xF2F3F1,
        FrameFinish.blackPowder => 0x1C1D1F,
        FrameFinish.anthracite => 0x3A3E42,
        FrameFinish.bronze => 0x6E5432,
        FrameFinish.goldenOak => 0xA5702F,
        FrameFinish.walnut => 0x4E2F1C,
      };

  double get roughnessBias => switch (this) {
        FrameFinish.naturalAnodised => 0.0,
        FrameFinish.whitePowder => 0.12,
        FrameFinish.blackPowder => 0.10,
        FrameFinish.anthracite => 0.10,
        FrameFinish.bronze => 0.05,
        FrameFinish.goldenOak => 0.18,
        FrameFinish.walnut => 0.18,
      };
}

/// Glazing. Thickness and optical properties both feed the 3D renderer and
/// the price.
enum GlassType {
  clearSingle,
  clearDouble,
  tinted,
  frosted,
  reflective,
  laminated,
  lowE,
}

extension GlassTypeInfo on GlassType {
  String get label => switch (this) {
        GlassType.clearSingle => 'Clear single 6 mm',
        GlassType.clearDouble => 'Clear double glazed',
        GlassType.tinted => 'Tinted',
        GlassType.frosted => 'Frosted / obscure',
        GlassType.reflective => 'Reflective',
        GlassType.laminated => 'Laminated safety',
        GlassType.lowE => 'Low-E double glazed',
      };

  double get thicknessMm => switch (this) {
        GlassType.clearSingle => 6,
        GlassType.clearDouble => 24,
        GlassType.tinted => 6,
        GlassType.frosted => 6,
        GlassType.reflective => 6,
        GlassType.laminated => 10,
        GlassType.lowE => 24,
      };

  /// 0..1 — how much light passes through. Drives `transmission` on the
  /// physical material in the renderer.
  double get transmission => switch (this) {
        GlassType.clearSingle => 0.92,
        GlassType.clearDouble => 0.88,
        GlassType.tinted => 0.55,
        GlassType.frosted => 0.62,
        GlassType.reflective => 0.35,
        GlassType.laminated => 0.86,
        GlassType.lowE => 0.80,
      };

  /// Surface roughness — frosted glass scatters, everything else is smooth.
  double get roughness => switch (this) {
        GlassType.frosted => 0.55,
        GlassType.reflective => 0.03,
        _ => 0.06,
      };

  int get tintColor => switch (this) {
        GlassType.clearSingle || GlassType.clearDouble || GlassType.lowE => 0xDCE9EA,
        GlassType.tinted => 0x6E7F82,
        GlassType.frosted => 0xE4EAEA,
        GlassType.reflective => 0x8FA6AE,
        GlassType.laminated => 0xD2E1E3,
      };

  double get reflectivity => switch (this) {
        GlassType.reflective => 0.9,
        GlassType.lowE => 0.55,
        _ => 0.35,
      };

  /// How solid the pane reads on screen. Glass that is physically almost
  /// perfectly transmissive still has to be *visible* as glass — an invisible
  /// pane looks like an empty hole in the frame.
  double get renderOpacity => switch (this) {
        GlassType.clearSingle => 0.42,
        GlassType.clearDouble => 0.48,
        GlassType.tinted => 0.72,
        GlassType.frosted => 0.80,
        GlassType.reflective => 0.76,
        GlassType.laminated => 0.52,
        GlassType.lowE => 0.55,
      };
}

/// A solid infill instead of glass — the lower half of many entrance doors.
enum PanelMaterial { sandwichPanel, aluminiumSheet, mdf, solidWood, louvre }

extension PanelMaterialInfo on PanelMaterial {
  String get label => switch (this) {
        PanelMaterial.sandwichPanel => 'Insulated sandwich panel',
        PanelMaterial.aluminiumSheet => 'Aluminium sheet',
        PanelMaterial.mdf => 'MDF panel',
        PanelMaterial.solidWood => 'Solid wood',
        PanelMaterial.louvre => 'Louvre / ventilation',
      };

  double get thicknessMm => switch (this) {
        PanelMaterial.sandwichPanel => 24,
        PanelMaterial.aluminiumSheet => 3,
        PanelMaterial.mdf => 18,
        PanelMaterial.solidWood => 30,
        PanelMaterial.louvre => 20,
      };
}

/// Handle styles that actually change the generated 3D hardware.
enum HandleStyle { lever, pullBar, knob, cremone, none }

extension HandleStyleInfo on HandleStyle {
  String get label => switch (this) {
        HandleStyle.lever => 'Lever handle',
        HandleStyle.pullBar => 'Pull bar',
        HandleStyle.knob => 'Knob',
        HandleStyle.cremone => 'Cremone / espagnolette',
        HandleStyle.none => 'No handle',
      };
}
