// Archivo: lib/features/player/presentation/views/player_screen.dart
// PANTALLA PRINCIPAL que contiene el FloatingBotWidget como overlay
import 'package:botlode_player/features/player/presentation/widgets/global_connectivity_overlay.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      // ⬅️ Fondo siempre transparente. El overlay oscuro ahora lo maneja FloatingBotWidget
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // FLOATING BOT WIDGET (burbuja + ChatPanelView + overlay)
          FloatingBotWidget(),

          // ⬅️ ALERTA GLOBAL FULL-SCREEN (conectividad)
          GlobalConnectivityOverlay(),
        ],
      ),
    );
  }
}
