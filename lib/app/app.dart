import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/layout/responsive.dart';
import 'screens/canvas_screen.dart';
import 'screens/new_design_screen.dart';
import 'screens/viewer_screen.dart';
import 'state/design_controller.dart';
import 'state/viewer_controller.dart';

/// The application root.
///
/// Phase 3 runs from the product choices, through drawing and measuring, to a
/// 2.5D preview that opens and closes. Saving and exporting are Phases 4 and 5
/// and are not present in any form.
class ProFrameApp extends StatelessWidget {
  /// Supplies project ids. Injected so a test can make them deterministic.
  final String Function() idFactory;

  const ProFrameApp({required this.idFactory, super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ProFrame',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) =>
            BoundedTextScale(child: child ?? const SizedBox.shrink()),
        home: _Entry(idFactory: idFactory),
      );
}

class _Entry extends ConsumerStatefulWidget {
  final String Function() idFactory;

  const _Entry({required this.idFactory});

  @override
  ConsumerState<_Entry> createState() => _EntryState();
}

class _EntryState extends ConsumerState<_Entry> {
  /// Which screen is showing.
  ///
  /// The design and the viewer's camera both live in Riverpod providers, not
  /// here, which is what makes the canvas-to-preview round trip lossless
  /// however many times it is made, and what lets both survive a rotation
  /// (spec Phase 3, item 4).
  _Step _step = _Step.choosing;

  @override
  Widget build(BuildContext context) => switch (_step) {
        _Step.choosing => NewDesignScreen(
            idFactory: widget.idFactory,
            onCreated: (document) {
              ref.read(designControllerProvider.notifier).open(document);
              ref.read(viewerControllerProvider.notifier).closeAll();
              setState(() => _step = _Step.drawing);
            },
          ),
        _Step.drawing => CanvasScreen(
            onBack: () => setState(() => _step = _Step.choosing),
            onPreview: () {
              // A divider moved on the canvas can merge two panels into a new
              // one; the viewer must not keep holding the old ids open.
              ref.read(viewerControllerProvider.notifier).retainOnly(
                    ref
                        .read(designControllerProvider)
                        .design
                        .panels
                        .map((panel) => panel.id),
                  );
              setState(() => _step = _Step.previewing);
            },
          ),
        _Step.previewing => ViewerScreen(
            onBack: () => setState(() => _step = _Step.drawing),
          ),
      };
}

/// Where the user is in the flow.
enum _Step { choosing, drawing, previewing }
