// Archivo: lib/features/player/presentation/views/player_screen.dart
// PANTALLA PRINCIPAL que contiene el FloatingBotWidget como overlay
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(chatOpenProvider);
    
    return Scaffold(
      // ⬅️ FONDO DINÁMICO: Transparente cuando cerrado, overlay cuando abierto
      backgroundColor: isOpen 
          ? Colors.black.withOpacity(0.5) // Overlay oscuro cuando chat abierto
          : Colors.transparent, // Transparente cuando solo está la burbuja
      body: const Stack(
        fit: StackFit.expand,
        children: [
          // FLOATING BOT WIDGET (burbuja + SimpleChatTest)
          FloatingBotWidget(),
        ],
      ),
    );
  }
}
