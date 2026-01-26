// Archivo: lib/features/player/presentation/views/player_screen.dart
// PANTALLA PRINCIPAL que contiene el FloatingBotWidget como overlay
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ⬅️ FONDO SÓLIDO (esto previene la transparencia)
      backgroundColor: Colors.transparent,
      body: const Stack(
        fit: StackFit.expand,
        children: [
          // FONDO SÓLIDO OSCURO (visible cuando el chat está cerrado)
          // Si quieres que sea completamente transparente para el iframe, usa Colors.transparent
          // Si quieres un fondo cuando se abre el chat, usa un color sólido
          SizedBox.expand(),
          
          // FLOATING BOT WIDGET (burbuja + chat)
          FloatingBotWidget(),
        ],
      ),
    );
  }
}
