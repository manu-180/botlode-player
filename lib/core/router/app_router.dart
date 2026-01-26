// Archivo: lib/core/router/app_router.dart
// import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:botlode_player/features/player/presentation/widgets/progressive_chat_widget.dart'; // ⬅️ PASO 2
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: CHAT PROGRESIVO (Construcción incremental)
    GoRoute(
      path: '/',
      builder: (context, state) => const ProgressiveChatWidget(), // ⬅️ PASO 2
    ),
  ],
);