// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart'; // ⬅️ PASO 3.8: BURBUJA FLOTANTE (FIX TRANSPARENCIA)
// import 'package:botlode_player/features/player/presentation/widgets/progressive_chat_widget.dart'; // ⬅️ PASO 2 (DESACTIVADO)
// import 'package:botlode_player/features/player/presentation/views/simple_chat_test.dart'; // ⬅️ PASO 3.5 (AHORA DENTRO DE FLOATING_BOT_WIDGET)
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: BURBUJA FLOTANTE (que contiene SimpleChatTest cuando se abre)
    GoRoute(
      path: '/',
      builder: (context, state) => const FloatingBotWidget(), // ⬅️ PASO 3.8: BURBUJA → CLICK → SIMPLE CHAT (FIX TRANSPARENCIA)
    ),
  ],
);