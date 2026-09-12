import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../domain/design_document.dart';
import '../export/elevation_painter.dart';
import '../export/export_service.dart';
import '../state/preferences_controller.dart';
import '../widgets/notice.dart';

/// Which exports the app offers. Overridden in tests so nothing opens a share
/// sheet.
final exportServiceProvider = Provider<ExportService>(
  // Watches the language: an export is written in whatever the user is
  // reading the app in at the moment they ask for it.
  (ref) => ExportService(strings: ref.watch(appStringsProvider)),
);

/// The export screen (spec section 11).
///
/// Shows exactly what will be produced, and says plainly which of the three is
/// the editable project — a PDF or a PNG is a picture of a design and nothing
/// more.
Future<void> showExportSheet(BuildContext context, DesignDocument design) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _ExportSheet(design: design),
    );

class _ExportSheet extends ConsumerStatefulWidget {
  final DesignDocument design;

  const _ExportSheet({required this.design});

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  ElevationOptions _options = const ElevationOptions();
  String? _busy;
  String? _message;

  Future<void> _run(String label, Future<ExportResult> Function() action) async {
    setState(() {
      _busy = label;
      _message = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _busy = null;
        _message = '${result.fileName} — ${_size(context, result.byteCount)}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _message = context.s(T.exportFailed, {'error': error});
      });
    }
  }

  static String _size(BuildContext context, int bytes) => bytes < 1024
      ? context.s(T.fileBytes, {'size': context.s.number(bytes)})
      : context.s(T.fileKilobytes, {'size': context.s.number(bytes / 1024)});

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(exportServiceProvider);
    final theme = Theme.of(context);
    final s = context.s;
    final design = widget.design;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s(T.export), style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),

            if (!design.hasConfirmedSize)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Notice(
                  tone: NoticeTone.caution,
                  title: s(T.measurementsIncomplete),
                  message: s(T.everyExportPreview),
                ),
              ),

            Text(s(T.drawing), style: theme.textTheme.titleMedium),
            SwitchListTile(
              value: _options.showDimensions,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(showDimensions: v)),
              title: Text(s(T.includeDimensions)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _options.showNotes,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(showNotes: v)),
              title: Text(s(T.includeNoteMarkers)),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.sm),
            _ExportRow(
              icon: Icons.description_outlined,
              title: s(T.designSheetPdf),
              subtitle: s(T.designSheetPdfHelp),
              busy: _busy == 'pdf',
              onPressed: () => _run('pdf', () => service.exportPdf(design)),
            ),
            _ExportRow(
              icon: Icons.image_outlined,
              title: s(T.drawingPng),
              subtitle: s(T.drawingPngHelp),
              busy: _busy == 'png',
              onPressed: () => _run(
                'png',
                () => service.exportPng(design, options: _options),
              ),
            ),
            _ExportRow(
              icon: Icons.inventory_2_outlined,
              title: s(T.projectFileProframe),
              subtitle: s(T.projectFileHelp),
              busy: _busy == 'project',
              onPressed: () =>
                  _run('project', () => service.exportProject(design)),
            ),

            if (_message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Notice(message: _message!),
            ],

            const SizedBox(height: AppSpacing.sm),
            Notice(tone: NoticeTone.caution, message: s(T.exportFooter)),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onPressed;

  const _ExportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: AppColors.deepGreen),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        // Disabled while one is running, so a slow export cannot be started
        // twice.
        onTap: busy ? null : onPressed,
      );
}
