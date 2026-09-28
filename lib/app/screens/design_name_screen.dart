import 'package:flutter/material.dart';

import '../../domain/model/new_design_setup.dart';
import '../theme/app_theme.dart';
import 'start_screen.dart';

/// **Design name**: the step of a new design that asks what the design is
/// called — *Basement Door*, *Front Entrance Door*, *Kitchen Window*.
///
/// It comes straight after **New Design**, before *Choose your design*, and
/// it is required: a customer's designs are told apart by their names, so
/// a design without one would be lost among them. The field starts empty —
/// nothing is offered in it, least of all the customer's own name, which is
/// who the design is for and not what it is called — and **Continue** with
/// nothing in it says so under the field and goes nowhere. Whitespace
/// either side of what is typed is trimmed away; everything else is the
/// user's name for their design, kept exactly.
///
/// Nothing is kept here. The name goes into the [NewDesignSetup] and on to
/// the choice of category with it; turning back from either leaves the
/// customer's designs as they were.
class DesignNameScreen extends StatefulWidget {
  /// The new design as it stands: whose it is, and nothing else yet.
  final NewDesignSetup setup;

  const DesignNameScreen({super.key, required this.setup});

  /// Keys, for finding the parts of the screen.
  static const nameField = ValueKey('design-name-field');
  static const continueButton = ValueKey('design-name-continue');
  static const problemText = ValueKey('design-name-problem');

  @override
  State<DesignNameScreen> createState() => _DesignNameScreenState();
}

class _DesignNameScreenState extends State<DesignNameScreen> {
  late final _name = TextEditingController(text: widget.setup.name ?? '');
  final _focus = FocusNode();

  /// What is wrong with the name, once the user has tried to go on with it
  /// — and only then, so an empty field is not scolded before anything has
  /// been typed.
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _continue() {
    final problem = NewDesignSetup.nameProblem(_name.text);
    if (problem != null) {
      setState(() => _problem = problem);
      _focus.requestFocus();
      return;
    }
    // The field shows what will be kept.
    final named = widget.setup.withName(_name.text);
    _name.text = named.name!;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => StartScreen(setup: named)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    final who = widget.setup.customer?.trim() ?? '';
    final problem = _problem;
    return Scaffold(
      appBar: AppBar(title: const Text('New Design')),
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
                      'Design name',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What is this design called?',
                      style: TextStyle(fontSize: 14, color: p.muted),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      key: DesignNameScreen.nameField,
                      controller: _name,
                      focusNode: _focus,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_problem != null) setState(() => _problem = null);
                      },
                      onSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        labelText: 'Design name',
                        hintText: 'e.g. Basement Door',
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
                              key: DesignNameScreen.problemText,
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
                    const SizedBox(height: 10),
                    Text(
                      'The customer is who it is for; this is the name of '
                      'the design itself.',
                      style: TextStyle(fontSize: 12.5, color: p.muted),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: DesignNameScreen.continueButton,
                      onPressed: _continue,
                      child: const Text('Continue'),
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

/// Who a new design is for, as a small chip over its steps.
class CustomerChip extends StatelessWidget {
  final String name;

  /// The chip's icon — a person, or what else it is labelling.
  final IconData icon;

  const CustomerChip({
    super.key,
    required this.name,
    this.icon = Icons.person_outline,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: context.palette.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.palette.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.palette.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
