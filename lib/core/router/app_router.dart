// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/player/presentation/views/player_screen.dart'; // ⬅️ PASO 4.2: CHAT COMPLETO
// import 'package:botlode_player/features/player/presentation/widgets/ultra_simple_bot.dart'; // ⬅️ TEST (funcionó)
// import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart'; // ⬅️ AHORA DENTRO DE PLAYER_SCREEN
// import 'package:botlode_player/features/player/presentation/widgets/progressive_chat_widget.dart'; // ⬅️ PASO 2 (DESACTIVADO)
// import 'package:botlode_player/features/player/presentation/views/simple_chat_test.dart'; // ⬅️ PASO 3.5 (AHORA DENTRO DE FLOATING_BOT_WIDGET)
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: PANTALLA BASE (PlayerScreen → FloatingBotWidget → SimpleChatTest)
    GoRoute(
      path: '/',
      builder: (context, state) => const PlayerScreen(), // ⬅️ PASO 4.2: CHAT COMPLETO FUNCIONAL
    ),
  ],
);