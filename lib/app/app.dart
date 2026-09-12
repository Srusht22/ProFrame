import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/layout/responsive.dart';
import 'screens/canvas_screen.dart';
import 'screens/new_design_screen.dart';
import 'state/design_controller.dart';

/// The application root.
///
/// Phase 2 runs from the product choices to a drawn, measured, assigned
/// design. Generating 3D, saving and exporting are Phases 3 to 5 and are not
/// present in any form.
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
  /// True once a design has been created and handed to the controller.
  ///
  /// The design itself lives in the Riverpod provider, not here, which is what
  /// lets it survive a rotation: this flag is the only thing the widget owns
  /// (spec Phase 2, item 10).
  bool _drawing = false;

  @override
  Widget build(BuildContext context) {
    if (!_drawing) {
      return NewDesignScreen(
        idFactory: widget.idFactory,
        onCreated: (document) {
          ref.read(designControllerProvider.notifier).open(document);
          setState(() => _drawing = true);
        },
      );
    }
    return CanvasScreen(onBack: () => setState(() => _drawing = false));
  }
}
