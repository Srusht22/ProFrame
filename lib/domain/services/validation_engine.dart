import '../configuration/config_enums.dart';
import '../configuration/dimension_limits.dart';
import '../configuration/product_configuration.dart';

enum ValidationSeverity { error, warning }

class ValidationIssue {
  final String field;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({
    required this.field,
    required this.message,
    this.severity = ValidationSeverity.error,
  });
}

class ValidationResult {
  final List<ValidationIssue> issues;

  const ValidationResult(this.issues);

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  bool get isValid => errors.isEmpty;

  static const ValidationResult empty = ValidationResult([]);
}

/// A single, independently testable manufacturing rule. Factories that need
/// different physical constraints can supply their own [ValidationRule]
/// list to [ValidationEngine] instead of forking the engine.
typedef ValidationRule = List<ValidationIssue> Function(ProductConfiguration config);

/// Prevents impossible configurations from ever reaching a quotation or
/// production order (spec principle: "Only valid configurations can advance
/// to production"). Every rule here is a pure function of the single source
/// of truth, [ProductConfiguration] — no UI, no side effects.
class ValidationEngine {
  final List<ValidationRule> rules;

  const ValidationEngine({List<ValidationRule>? rules}) : rules = rules ?? defaultRules;

  ValidationResult validate(ProductConfiguration config) {
    final issues = <ValidationIssue>[];
    for (final rule in rules) {
      issues.addAll(rule(config));
    }
    return ValidationResult(issues);
  }

  static ProductLimits limitsFor(ProductConfiguration config) {
    return config.category == ProductCategory.door
        ? ProductLimits.forDoor(config.doorType ?? DoorType.custom)
        : ProductLimits.forWindow(config.windowType ?? WindowType.custom);
  }

  static final List<ValidationRule> defaultRules = [
    _dimensionRangeRule,
    _frameDepthRule,
    _sectionCountRule,
    _sectionWidthPhysicalRule,
    _glassThicknessRule,
    _glazingPaneConsistencyRule,
    _wallOpeningRule,
    _quantityRule,
    _leafArrangementConsistencyRule,
    _doorSecurityHardwareRule,
    _hingeCountForHeightRule,
  ];

  static List<ValidationIssue> _dimensionRangeRule(ProductConfiguration c) {
    final limits = limitsFor(c);
    final issues = <ValidationIssue>[];
    if (!limits.width.contains(c.widthMm)) {
      issues.add(ValidationIssue(
        field: 'widthMm',
        message:
            'Width must be between ${limits.width.minMm.toInt()} mm and ${limits.width.maxMm.toInt()} mm for ${c.productTypeLabel}.',
      ));
    }
    if (!limits.height.contains(c.heightMm)) {
      issues.add(ValidationIssue(
        field: 'heightMm',
        message:
            'Height must be between ${limits.height.minMm.toInt()} mm and ${limits.height.maxMm.toInt()} mm for ${c.productTypeLabel}.',
      ));
    }
    return issues;
  }

  static List<ValidationIssue> _frameDepthRule(ProductConfiguration c) {
    final limits = limitsFor(c);
    if (!limits.frameDepth.contains(c.frame.frameDepthMm)) {
      return [
        ValidationIssue(
          field: 'frame.frameDepthMm',
          message:
              'Frame depth must be between ${limits.frameDepth.minMm.toInt()} mm and ${limits.frameDepth.maxMm.toInt()} mm.',
        ),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _sectionCountRule(ProductConfiguration c) {
    final limits = limitsFor(c);
    if (c.sections < limits.minSections || c.sections > limits.maxSections) {
      return [
        ValidationIssue(
          field: 'sections',
          message: 'Sections must be between ${limits.minSections} and ${limits.maxSections}.',
        ),
      ];
    }
    return const [];
  }

  /// A section narrower than ~220 mm cannot physically hold a sash/mullion
  /// profile plus glass — this mirrors real factory minimums.
  static List<ValidationIssue> _sectionWidthPhysicalRule(ProductConfiguration c) {
    if (c.sections <= 1) return const [];
    const minPhysicalSectionWidthMm = 220.0;
    final jambAllowance = c.frame.frameThicknessMm * 2;
    final netWidth = c.widthMm - jambAllowance;
    final perSection = netWidth / c.sections;
    if (perSection < minPhysicalSectionWidthMm) {
      return [
        ValidationIssue(
          field: 'sections',
          message:
              '${c.sections} sections do not fit within ${c.widthMm.toInt()} mm width — each section would be ${perSection.toInt()} mm (minimum ${minPhysicalSectionWidthMm.toInt()} mm).',
        ),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _glassThicknessRule(ProductConfiguration c) {
    if (c.panel.type != PanelType.glass) return const [];
    final minByType = <GlassType, double>{
      GlassType.clear: 4,
      GlassType.frosted: 4,
      GlassType.tinted: 5,
      GlassType.tempered: 6,
      GlassType.laminated: 6.4,
      GlassType.doubleGlazed: 16,
      GlassType.tripleGlazed: 24,
      GlassType.custom: 4,
    };
    final min = minByType[c.glass.type] ?? 4;
    if (c.glass.thicknessMm < min) {
      return [
        ValidationIssue(
          field: 'glass.thicknessMm',
          message:
              '${c.glass.type.label} glass requires a minimum thickness of ${min.toInt()} mm for this unit size.',
        ),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _glazingPaneConsistencyRule(ProductConfiguration c) {
    if (c.panel.type != PanelType.glass) return const [];
    final expected = switch (c.glass.type) {
      GlassType.doubleGlazed => 2,
      GlassType.tripleGlazed => 3,
      _ => null,
    };
    if (expected != null && c.glass.panesCount != expected) {
      return [
        ValidationIssue(
          field: 'glass.panesCount',
          message: '${c.glass.type.label} requires exactly $expected panes.',
        ),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _wallOpeningRule(ProductConfiguration c) {
    final issues = <ValidationIssue>[];
    if (c.wallOpeningWidthMm < c.widthMm) {
      issues.add(const ValidationIssue(
        field: 'wallOpeningWidthMm',
        message: 'Wall opening width is smaller than the unit width — the unit will not fit.',
      ));
    }
    if (c.wallOpeningHeightMm < c.heightMm) {
      issues.add(const ValidationIssue(
        field: 'wallOpeningHeightMm',
        message: 'Wall opening height is smaller than the unit height — the unit will not fit.',
      ));
    }
    final widthGap = c.wallOpeningWidthMm - c.widthMm;
    if (widthGap > 60) {
      issues.add(ValidationIssue(
        field: 'wallOpeningWidthMm',
        message:
            'Wall opening is ${widthGap.toInt()} mm wider than the unit — confirm packing/finishing allowance.',
        severity: ValidationSeverity.warning,
      ));
    }
    return issues;
  }

  static List<ValidationIssue> _quantityRule(ProductConfiguration c) {
    if (c.quantity < 1) {
      return const [
        ValidationIssue(field: 'quantity', message: 'Quantity must be at least 1.'),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _leafArrangementConsistencyRule(ProductConfiguration c) {
    if (c.category != ProductCategory.door) return const [];
    final expected = switch (c.leaf.arrangement) {
      LeafArrangement.single => 1,
      LeafArrangement.double_ => 2,
      LeafArrangement.unequalDouble => 2,
      LeafArrangement.doorPlusFixed => 1,
      LeafArrangement.custom => null,
    };
    if (expected != null && c.leaf.leafCount != expected) {
      return [
        ValidationIssue(
          field: 'leaf.leafCount',
          message: '${c.leaf.arrangement.label} requires $expected operable leaf/leaves.',
        ),
      ];
    }
    return const [];
  }

  static List<ValidationIssue> _doorSecurityHardwareRule(ProductConfiguration c) {
    if (c.category != ProductCategory.door) return const [];
    final needsLock = c.doorType == DoorType.exterior || c.doorType == DoorType.entrance;
    if (needsLock && c.hardware.lockType == LockType.none) {
      return [
        const ValidationIssue(
          field: 'hardware.lockType',
          message: 'Exterior/entrance doors should specify a lock for security.',
          severity: ValidationSeverity.warning,
        ),
      ];
    }
    return const [];
  }

  /// Real hardware rule of thumb: heavier/taller leaves need more hinges.
  static List<ValidationIssue> _hingeCountForHeightRule(ProductConfiguration c) {
    if (c.category != ProductCategory.door) return const [];
    if (c.leaf.arrangement == LeafArrangement.doorPlusFixed && c.leaf.leafCount == 0) {
      return const [];
    }
    final recommended = c.heightMm > 2400
        ? 4
        : c.heightMm > 2100
            ? 3
            : 2;
    if (c.hardware.hingeCount < recommended) {
      return [
        ValidationIssue(
          field: 'hardware.hingeCount',
          message:
              'A ${c.heightMm.toInt()} mm leaf is recommended to use at least $recommended hinges (currently ${c.hardware.hingeCount}).',
          severity: ValidationSeverity.warning,
        ),
      ];
    }
    return const [];
  }
}
