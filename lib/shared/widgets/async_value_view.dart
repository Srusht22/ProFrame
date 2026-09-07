import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_state.dart';

/// Consistent loading/error/data handling for `AsyncValue` everywhere in
/// the app, so no screen ever shows a raw exception (spec §34/§53).
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorState(message: _friendlyMessage(error), onRetry: onRetry),
    );
  }

  String _friendlyMessage(Object error) {
    // Local storage errors are the only realistic failure mode today; a
    // future HTTP repository swap should map its exceptions the same way.
    return "We couldn't load this data. Please try again.";
  }
}
