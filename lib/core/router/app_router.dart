// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart'; // ⬅️ BOT COMPLETO
// import 'package:botlode_player/features/player/presentation/widgets/ultra_simple_bot.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: EL BOT COMPLETO CON TODAS LAS FEATURES
    GoRoute(
      path: '/',
      builder: (context, state) => const FloatingBotWidget(), // ⬅️ BOT COMPLETO
    ),
  ],
);