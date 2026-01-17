// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingBotWidget extends ConsumerStatefulWidget {
  const FloatingBotWidget({super.key});

  @override
  ConsumerState<FloatingBotWidget> createState() => _FloatingBotWidgetState();
}

class _FloatingBotWidgetState extends ConsumerState<FloatingBotWidget> {
  
  @override
  void initState() {
    super.initState();
    html.window.onMessage.listen((event) {
      final data = event.data;
      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(chatOpenProvider);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600; 
    final panelHeight = isMobile ? screenSize.height : (screenSize.height - 100).clamp(400.0, 700.0);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent, 
      onHover: (event) {
        ref.read(pointerPositionProvider.notifier).state = event.position;
      },
      onExit: (event) {
        ref.read(pointerPositionProvider.notifier).state = null;
      },
      child: Stack(
        fit: StackFit.expand, 
        alignment: Alignment.bottomRight,
        children: [
          
          // 1. CAPA "BACKDROP" (NUEVO): Detecta clics fuera del chat
          if (isOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent, // Atrapa clics en lo transparente
                onTap: () {
                  // Acción: Cerrar el chat
                  ref.read(chatOpenProvider.notifier).set(false);
                },
                child: const SizedBox.expand(), // Ocupa todo el espacio
              ),
            ),

          // 2. CHAT PANEL (Sobre el backdrop)
          if (isOpen)
            isMobile 
              ? Positioned.fill(child: const ChatPanelView().animate().fadeIn())
              : Positioned(
                  bottom: 20, right: 20,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: panelHeight, maxWidth: 380),
                    child: const ChatPanelView().animate().scale(curve: Curves.easeOutBack, alignment: Alignment.bottomRight).fadeIn(),
                  ),
                ),

          // 3. BOTÓN FLOTANTE (Solo si está cerrado)
          if (!isOpen)
             Positioned(
              bottom: 10, right: 10,
              child: FloatingActionButton(
                mini: false,
                backgroundColor: const Color(0xFFFFC000),
                elevation: 0,
                shape: const CircleBorder(),
                onPressed: () {
                  ref.read(chatOpenProvider.notifier).set(true);
                },
                child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black, size: 28),
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOut), 
        ],
      ),
    );
  }
}