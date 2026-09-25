import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'start_screen.dart';

/// The one step before a new design: who it is for.
///
/// That is all that is asked, because it is what finds the design again
/// among every other one the workshop has drawn — the list of designs is
/// searched by the person it was drawn for. So it is needed: **Continue**
/// waits until there is a name, and then goes on to *Choose your design*
/// with it. The design is known by that name everywhere after, from the
/// list to the top of the drawing.
class NewDesignScreen extends StatefulWidget {
  const NewDesignScreen({super.key});

  /// The field's key, for finding it.
  static const customerField = ValueKey('new-design-customer');

  @override
  State<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends State<NewDesignScreen> {
  final _customer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  String get _who => _customer.text.trim();

  void _continue() {
    if (_who.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StartScreen(customer: _who)),
    );
  }

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
                    'Who is this design for?',
                    style: TextStyle(fontSize: 14, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Person / Customer',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  TextField(
                    key: NewDesignScreen.customerField,
                    controller: _customer,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _continue(),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ahmed',
                      hintStyle: const TextStyle(color: AppTheme.muted),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppTheme.muted,
                      ),
                      filled: true,
                      fillColor: AppTheme.shell,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _who.isEmpty ? null : _continue,
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
