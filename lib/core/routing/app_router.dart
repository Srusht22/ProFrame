import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/configurator/screens/design_screen.dart';
import '../../features/configurator/screens/interpretation_screen.dart';
import '../../features/configurator/state/design_session.dart';
import '../../features/drawing/screens/drawing_screen.dart';
import '../../features/projects/screens/home_screen.dart';
import '../services/providers.dart';

/// Routes follow the journey exactly: draw → understand → design.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static String draw(String id) => '/design/$id/draw';
  static String interpret(String id) => '/design/$id/understand';
  static String model(String id) => '/design/$id/model';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => HomeScreen(
          onOpenDrawing: (design) => context.go(AppRoutes.draw(design.id)),
          onOpenDesign: (design) => context.go(AppRoutes.model(design.id)),
        ),
      ),
      GoRoute(
        path: '/design/:id/draw',
        builder: (context, state) => _DrawingRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/design/:id/understand',
        builder: (context, state) => _InterpretRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/design/:id/model',
        builder: (context, state) => _ModelRoute(id: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Makes sure the session holds the design named in the URL — a deep link or
/// a reload must not land on someone else's drawing.
class _SessionGuard extends ConsumerWidget {
  final String id;
  final Widget Function(BuildContext context) builder;

  const _SessionGuard({required this.id, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(designSessionProvider);
    if (session.document?.id == id) return builder(context);

    return FutureBuilder(
      future: ref.read(designRepositoryProvider).findById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final design = snapshot.data;
        if (design == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRoutes.home);
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(designSessionProvider.notifier).open(design);
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _DrawingRoute extends ConsumerWidget {
  final String id;

  const _DrawingRoute({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SessionGuard(
        id: id,
        builder: (context) => DrawingScreen(
          onBack: () => context.go(AppRoutes.home),
          onInterpret: ({bool useDrawingExtent = false}) async {
            final result = await ref
                .read(designSessionProvider.notifier)
                .interpret(useDrawingExtent: useDrawingExtent);
            if (!context.mounted) return;
            // A failure leaves the user on the drawing with the reason shown,
            // rather than navigating to an empty design.
            if (result != null) context.go(AppRoutes.interpret(id));
          },
        ),
      );
}

class _InterpretRoute extends ConsumerWidget {
  final String id;

  const _InterpretRoute({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SessionGuard(
        id: id,
        builder: (context) => InterpretationScreen(
          onEditDrawing: () => context.go(AppRoutes.draw(id)),
          onConfirm: () => context.go(AppRoutes.model(id)),
        ),
      );
}

class _ModelRoute extends ConsumerWidget {
  final String id;

  const _ModelRoute({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SessionGuard(
        id: id,
        builder: (context) => DesignScreen(
          onEditDrawing: () => context.go(AppRoutes.draw(id)),
          onExit: () => context.go(AppRoutes.home),
        ),
      );
}
