import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/units/unit_converter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LengthUnit _selectedUnit = LengthUnit.mm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              // MEASUREMENT UNITS SECTION
              const Text(
                'MEASUREMENT SYSTEM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: LengthUnit.values.map((unit) {
                    final isSelected = _selectedUnit == unit;
                    return RadioListTile<LengthUnit>(
                      value: unit,
                      groupValue: _selectedUnit,
                      activeColor: AppTheme.primary,
                      title: Text(
                        '${unit.label} (${unit.symbol})',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        unit == LengthUnit.mm
                            ? 'Factory Canonical Standard (Recommended)'
                            : 'Displayed as ${unit.format(1200)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // OFFLINE & FACTORY INFO
              const Text(
                'SYSTEM & STORAGE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.wifi_off_rounded, 'Offline Status', '100% Offline Ready'),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.view_in_ar_rounded, '3D Geometry Engine', 'Three.js WebGL 2.0 PBR'),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.straighten_rounded, 'Geometry Precision', '1:1 Real Millimeter (mm)'),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.info_outline_rounded, 'Application Version', '${AppConstants.appName} v1.0.0'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}
