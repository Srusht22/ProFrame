import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'start_screen.dart';

/// The one step before a new design: who it is for, and what it is called.
///
/// Nothing else is asked here. **Continue** goes on to the choice of door,
/// window, both or sliding, exactly as it has always been made, and the
/// design is begun with these two answers on it. Either may be left empty:
/// a design with no name is called what it always was, *Untitled door*.
class NewDesignScreen extends StatefulWidget {
  const NewDesignScreen({super.key});

  @override
  State<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends State<NewDesignScreen> {
  final _customer = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _customer.dispose();
    _name.dispose();
    super.dispose();
  }

  static String? _said(TextEditingController field) {
    final text = field.text.trim();
    return text.isEmpty ? null : text;
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StartScreen(customer: _said(_customer), name: _said(_name)),
      ),
    );
  }

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.muted),
    filled: true,
    fillColor: AppTheme.shell,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New Design',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Who is it for, and what is it called?',
                    style: TextStyle(fontSize: 14, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 26),
                  _label('Person / Customer'),
                  TextField(
                    key: const ValueKey('new-design-customer'),
                    controller: _customer,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _field('e.g. Ahmed'),
                  ),
                  const SizedBox(height: 18),
                  _label('Design Name'),
                  TextField(
                    key: const ValueKey('new-design-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _continue(),
                    decoration: _field('e.g. Main entrance'),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
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
