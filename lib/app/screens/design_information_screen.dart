import 'package:flutter/material.dart';

import '../../domain/model/design.dart';
import '../../domain/model/new_design_setup.dart';
import '../../domain/text/names.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'design_name_screen.dart';
import 'designs_screen.dart';

/// **Edit information** for a design that already exists: what it is
/// called — *Basement Door* made *Basement Door - New PVC*.
///
/// The name is the one thing here that can be typed over. The category is
/// shown and stays with the design, because the design was begun as it and
/// everything drawn since was drawn in it; who it is for is the customer's,
/// changed on their own page. The name is held to the same rule as a new
/// design's — `NewDesignSetup.nameProblem`: it is needed, and whitespace
/// either side is trimmed away.
///
/// Nothing is kept here. **Save changes** hands back the name, trimmed, and
/// the caller renames the design it came from — the same design, by its
/// id, with its drawing, geometry, sizes, openings, lines, materials and
/// all untouched. Turning back hands back nothing and changes nothing.
class DesignInformationScreen extends StatefulWidget {
  /// What the design is called now.
  final String name;

  /// Its category, shown and kept.
  final DesignKind kind;

  /// Who it is for, where that is known.
  final String? customer;

  const DesignInformationScreen({
    super.key,
    required this.name,
    required this.kind,
    this.customer,
  });

  static const nameField = ValueKey('design-info-name');
  static const saveButton = ValueKey('design-info-save');
  static const problemText = ValueKey('design-info-problem');
  static const categoryText = ValueKey('design-info-category');

  @override
  State<DesignInformationScreen> createState() =>
      _DesignInformationScreenState();
}

class _DesignInformationScreenState extends State<DesignInformationScreen> {
  late final _name = TextEditingController(text: widget.name);
  final _focus = FocusNode();

  /// What is wrong with the name, once the user has tried to save it.
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final problem = NewDesignSetup.nameProblem(_name.text, context.words);
    if (problem != null) {
      setState(() => _problem = problem);
      _focus.requestFocus();
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    final who = widget.customer?.trim() ?? '';
    final problem = _problem;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editInformation)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (who.isNotEmpty) ...[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CustomerChip(name: who),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      context.l10n.editInformation,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.editInformationLine,
                      style: TextStyle(fontSize: 14, color: p.muted),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      key: DesignInformationScreen.nameField,
                      controller: _name,
                      focusNode: _focus,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_problem != null) setState(() => _problem = null);
                      },
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        labelText: context.l10n.designName,
                        hintText: context.l10n.designNameHint,
                        hintStyle: TextStyle(color: p.muted),
                        prefixIcon: Icon(
                          Icons.drive_file_rename_outline,
                          color: problem == null ? p.muted : danger,
                        ),
                        filled: true,
                        fillColor: p.shell,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: problem == null
                              ? BorderSide.none
                              : BorderSide(color: danger, width: 1.4),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: problem == null ? p.primary : danger,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    if (problem != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 18, color: danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              problem,
                              key: DesignInformationScreen.problemText,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.category,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: p.shell,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            kindIcon(widget.kind),
                            size: 20,
                            color: p.primary,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.kind.labelIn(context.words),
                              key: DesignInformationScreen.categoryText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.categoryStays,
                      style: TextStyle(fontSize: 12.5, color: p.muted),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: DesignInformationScreen.saveButton,
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text(context.l10n.saveChanges),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
