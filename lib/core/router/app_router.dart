// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/crm/presentation/views/nexus_dashboard_view.dart';
import 'package:botlode_player/features/crm/presentation/views/nexus_gate_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // RUTA 1: EL BOT (PÚBLICA)
    // Es lo que se ve en el iframe.
    GoRoute(
      path: '/',
      builder: (context, state) => const FloatingBotWidget(),
    ),

    // RUTA 2: NEXUS GATE (LOGIN)
    // Acceso: tudominio.com/nexus?bot_id=...
    GoRoute(
      path: '/nexus',
      builder: (context, state) {
        // Capturamos el ID de la URL para autocompletar
        final botId = state.uri.queryParameters['bot_id'] ?? '';
        return NexusGateView(initialBotId: botId);
      },
    ),

    // RUTA 3: NEXUS DASHBOARD (PRIVADA)
    GoRoute(
      path: '/nexus/dashboard',
      builder: (context, state) {
        // Pasamos el ID del bot autenticado
        final botId = state.extra as String?;
        if (botId == null) return const NexusGateView(initialBotId: '');
        return NexusDashboardView(botId: botId);
      },
    ),
  ],
);