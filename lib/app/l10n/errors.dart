import 'package:flutter/widgets.dart';

import '../../domain/pricing/pricing_access.dart';
import '../../domain/text/refusal.dart';
import '../../infrastructure/keep_failed.dart';
import 'l10n.dart';

/// What to tell the user about [error], in the language shown.
///
/// A refusal the application made — not allowed, not valid, not kept — is
/// said as itself. Anything else is a fault, not a sentence for the user:
/// they are told plainly that it did not work, and the fault itself goes
/// to the log, where whoever looks after the application can read it. A
/// raw exception is never shown.
String userMessageOf(BuildContext context, Object error) {
  final w = context.words;
  return switch (error) {
    AccessDenied() => error.messageIn(w),
    Refusal() => error.messageIn(w),
    StateRefusal() => error.messageIn(w),
    KeepFailed() => context.l10n.errNotKept,
    _ => _logged(context, error),
  };
}

String _logged(BuildContext context, Object error) {
  debugPrint('ProFrame: $error');
  return context.l10n.errSomethingWrong;
}
