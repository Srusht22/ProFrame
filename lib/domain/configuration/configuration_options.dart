import 'package:flutter/material.dart';

class ProductType {
  final String id;
  final String label;
  final String icon;
  final String description;
  final bool isCustom;

  const ProductType({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    this.isCustom = false,
  });

  static const window = ProductType(
    id: 'window',
    label: 'Window',
    icon: '🪟',
    description: 'Casement, sliding, and fixed architectural windows',
  );

  static const door = ProductType(
    id: 'door',
    label: 'Hinged Door',
    icon: '🚪',
    description: 'Single and double leaf aluminum hinged entry and interior doors',
  );

  static const slidingDoor = ProductType(
    id: 'slidingDoor',
    label: 'Sliding Patio Door',
    icon: '🪟',
    description: 'Multi-panel patio and pocket sliding glass doors',
  );

  static const partition = ProductType(
    id: 'partition',
    label: 'Glass Partition',
    icon: '🏢',
    description: 'Floor-to-ceiling office walls and architectural glass dividers',
  );

  static const cabinet = ProductType(
    id: 'cabinet',
    label: 'Cabinet & Unit',
    icon: '🗄️',
    description: 'Industrial aluminum and glass cabinetry and storage display units',
  );

  static const custom = ProductType(
    id: 'custom',
    label: 'Custom Frame',
    icon: '📐',
    description: 'Custom dimensions, profiles, and structural framing',
  );

  static List<ProductType> get builtIns => [
        window,
        door,
        slidingDoor,
        partition,
        cabinet,
        custom,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'description': description,
        'isCustom': isCustom,
      };

  factory ProductType.fromJson(Map<String, dynamic> json) => ProductType(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Product',
        icon: json['icon'] as String? ?? '📦',
        description: json['description'] as String? ?? '',
        isCustom: json['isCustom'] as bool? ?? false,
      );

  factory ProductType.fromString(String id) {
    for (final b in builtIns) {
      if (b.id == id) return b;
    }
    return ProductType(
      id: id,
      label: id.isNotEmpty ? id[0].toUpperCase() + id.substring(1) : 'Custom',
      icon: '📦',
      description: 'Custom product type',
      isCustom: true,
    );
  }

  String get name => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ProductType && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => label;
}

enum WindowStyle {
  sliding('Sliding', 'Horizontal sliding sashes on bypass tracks', Icons.view_column_rounded),
  fixed('Fixed (Picture)', 'Non-opening panoramic glass panel', Icons.crop_square_rounded),
  casement('Casement', 'Side-hinged swinging sash with outward swing', Icons.sensor_window_rounded),
  tiltAndTurn('Tilt & Turn', 'Dual-action top tilt ventilation or full swing', Icons.flip_to_front_rounded),
  bifold('Bi-Fold', 'Folding multi-panel concertina sashes', Icons.menu_open_rounded),
  doubleHinged('French / Double Swing', 'Dual active swinging door/window panels', Icons.meeting_room_rounded);

  final String label;
  final String description;
  final IconData icon;

  const WindowStyle(this.label, this.description, this.icon);
}

enum FrameColorType {
  black('Black', Color(0xFF1E2124), '#1E2124', 'Powder Coated Matte Black'),
  white('White', Color(0xFFF3F4F6), '#F3F4F6', 'Powder Coated Traffic White'),
  anthraciteGray('Anthracite', Color(0xFF373E44), '#373E44', 'Architectural Anthracite Gray'),
  bronzeBrown('Bronze', Color(0xFF483B32), '#483B32', 'Warm Bronze Dark Anodized'),
  anodizedSilver('Silver', Color(0xFFD3D6DB), '#D3D6DB', 'Natural Anodized Aluminum'),
  custom('Custom RAL', Color(0xFF3B82F6), null, 'Custom factory RAL color');

  final String label;
  final Color color;
  final String? defaultHex;
  final String finishDescription;

  const FrameColorType(this.label, this.color, this.defaultHex, this.finishDescription);
}

enum GlassType {
  clear('Clear', 'High clarity float glass with optimal light transmission', Color(0xFFE2E8F0)),
  tintedGray('Tinted Gray', 'Solar control tinted glass reducing glare and heat', Color(0xFF64748B)),
  reflectiveBlue('Reflective Blue', 'Mirror-like solar reflective architectural coating', Color(0xFF38BDF8)),
  frostedPrivacy('Frosted', 'Acid-etched satin privacy glass for bathrooms & offices', Color(0xFFF1F5F9)),
  solarDark('Dark Bronze', 'Maximum solar shading and privacy dark tint', Color(0xFF334155)),
  lowEGreen('Low-E Green', 'High efficiency thermal insulated solar glass', Color(0xFFA7F3D0)),
  flutedReeded('Fluted / Reeded', 'Decorative ribbed architectural glass', Color(0xFFE0E7FF)),
  opaquePanel('Solid Panel', 'Solid insulated powder-coated sandwich panel', Color(0xFF475569));

  final String label;
  final String description;
  final Color previewColor;

  const GlassType(this.label, this.description, this.previewColor);
}

enum HandleType {
  standardPull('Standard Pull', 'Ergonomic vertical pull handle bar', Icons.reorder_rounded),
  flushLatch('Flush Latch', 'Recessed sliding sash pocket latch', Icons.indeterminate_check_box_outlined),
  leverHandle('Modern Lever', 'Architectural swinging lever handle', Icons.meeting_room_rounded),
  modernBar('Architectural Bar', 'Full-length vertical stainless steel pull bar', Icons.view_headline_rounded),
  lockAndKey('Mortise Key Lock', 'High-security keyed entry cylinder latch', Icons.vpn_key_rounded),
  none('None', 'Fixed glass without operational hardware', Icons.block_rounded);

  final String label;
  final String description;
  final IconData icon;

  const HandleType(this.label, this.description, this.icon);
}

enum OpeningDirection {
  left('Slide Left', 'Active sash slides to the left', Icons.arrow_back_rounded),
  right('Slide Right', 'Active sash slides to the right', Icons.arrow_forward_rounded),
  bothSlide('Both Active', 'Both sashes can slide independently', Icons.swap_horiz_rounded),
  fixed('Fixed Pane', 'Glass panel does not open', Icons.lock_outline_rounded);

  final String label;
  final String description;
  final IconData icon;

  const OpeningDirection(this.label, this.description, this.icon);
}
