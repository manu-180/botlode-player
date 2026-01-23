// Archivo: lib/core/router/app_router.dart
import 'package:botlode_player/features/crm/presentation/views/nexus_dashboard_view.dart';
import 'package:botlode_player/features/crm/presentation/views/nexus_gate_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // RUTA 1: EL BOT (PÚBLICA - IFRAME)
    GoRoute(
      path: '/',
      builder: (context, state) => const FloatingBotWidget(),
    ),

    // RUTA 2: GATEWAY DE ACCESO
    // Nueva URL: tudominio.com/historial?bot_id=...
    GoRoute(
      path: '/historial',
      builder: (context, state) {
        final botId = state.uri.queryParameters['bot_id'] ?? '';
        return NexusGateView(initialBotId: botId);
      },
    ),

    // RUTA 3: PANEL DE CONTROL
    GoRoute(
      path: '/historial/panel',
      builder: (context, state) {
        final botId = state.extra as String?;
        if (botId == null) return const NexusGateView(initialBotId: '');
        return NexusDashboardView(botId: botId);
      },
    ),
  ],
);