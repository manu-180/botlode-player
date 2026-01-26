// Archivo: lib/core/router/app_router.dart
// import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
// import 'package:botlode_player/features/player/presentation/widgets/progressive_chat_widget.dart'; // ⬅️ PASO 2 (DESACTIVADO)
import 'package:botlode_player/features/player/presentation/views/simple_chat_test.dart'; // ⬅️ PASO 3.5: ACTIVADO PARA CONSTRUCCIÓN GRADUAL
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ÚNICA RUTA: SIMPLE CHAT TEST (Construcción gradual desde cero)
    GoRoute(
      path: '/',
      builder: (context, state) => const SimpleChatTest(), // ⬅️ PASO 3.5: AHORA USAMOS SIMPLE CHAT
    ),
  ],
);