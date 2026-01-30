// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/player/presentation/widgets/ultra_simple_bot.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const UltraSimpleBot(),
    ),
  ],
);