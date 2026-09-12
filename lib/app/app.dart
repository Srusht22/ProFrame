import 'package:flutter/material.dart';

import '../core/design/app_theme.dart';
import '../core/design/tokens.dart';
import '../core/layout/responsive.dart';
import '../domain/design_document.dart';
import 'screens/new_design_screen.dart';

/// The application root.
///
/// Phase 1 stops at the point where a [DesignDocument] exists: creating one is
/// the whole of the flow that is built. The placeholder below says exactly
/// that rather than showing a canvas that does not work yet — a screen that
/// pretends to be finished is the thing this project is explicitly not doing
/// (spec section 9).
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

class _Entry extends StatefulWidget {
  final String Function() idFactory;

  const _Entry({required this.idFactory});

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  DesignDocument? _design;

  @override
  Widget build(BuildContext context) {
    final design = _design;
    if (design == null) {
      return NewDesignScreen(
        idFactory: widget.idFactory,
        onCreated: (document) => setState(() => _design = document),
      );
    }
    return _PhaseBoundary(
      design: design,
      onBack: () => setState(() => _design = null),
    );
  }
}

/// Where Phase 1 ends and Phase 2 begins.
///
/// This is deliberately not a mock canvas. It shows the design that was
/// actually created, from the real model, and states plainly what is not built
/// yet.
class _PhaseBoundary extends StatelessWidget {
  final DesignDocument design;
  final VoidCallback onBack;

  const _PhaseBoundary({required this.design, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(design.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to the product choices',
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Design created', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  _Fact('Product', design.category.label),
                  _Fact('Material', design.material.label),
                  _Fact('Colour', design.finish.name),
                  _Fact('Profile system', design.profile.toString()),
                  _Fact('Dimensions given as', design.dimensionReference.label),
                  _Fact('Drawing viewed from', design.viewedFrom.label),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Still to confirm',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final question in design.outstandingQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(question)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
