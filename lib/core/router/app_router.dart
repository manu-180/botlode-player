// Archivo: lib/core/router/app_router.dart
// import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:botlode_player/features/player/presentation/widgets/ultra_simple_bot.dart'; // ⬅️ TEST
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: EL BOT ULTRA SIMPLE
    GoRoute(
      path: '/',
      builder: (context, state) => const UltraSimpleBot(), // ⬅️ TEST
    ),
  ],
);