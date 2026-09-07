import 'package:flutter/material.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../../../../designer_2d/presentation/designer_2d_view.dart';
import '../../../../viewer_3d/presentation/viewer_3d_panel.dart';

/// 2D / 3D preview tabs — used both as a wizard step and as the always-on
/// center pane in the desktop 3-column layout.
class PreviewStep extends StatefulWidget {
  final ProductConfiguration config;
  const PreviewStep({super.key, required this.config});

  @override
  State<PreviewStep> createState() => _PreviewStepState();
}

class _PreviewStepState extends State<PreviewStep> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '2D Drawing', icon: Icon(Icons.crop_square_rounded, size: 18)),
            Tab(text: '3D Preview', icon: Icon(Icons.view_in_ar_rounded, size: 18)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Designer2DView(config: widget.config),
              Viewer3DPanel(configuration: widget.config),
            ],
          ),
        ),
      ],
    );
  }
}
