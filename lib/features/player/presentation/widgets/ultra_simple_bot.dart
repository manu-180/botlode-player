// ULTRA SIMPLE - Burbuja + Chat COMPLEJO (chat_panel_view) para testing
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider simple
final isOpenSimpleProvider = StateProvider<bool>((ref) => false);

class UltraSimpleBot extends ConsumerWidget {
  const UltraSimpleBot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(isOpenSimpleProvider);
    
    // ⬅️ FIX: Fondo dinámico según si el chat está abierto o cerrado
    return Scaffold(
      backgroundColor: isOpen 
          ? Colors.black.withOpacity(0.5) // ⬅️ SEMI-TRANSPARENTE cuando chat abierto (overlay)
          : Colors.transparent, // ⬅️ TRANSPARENTE cuando chat cerrado (solo burbuja)
      body: Stack(
        fit: StackFit.expand, // ⬅️ FIX: Llenar todo el espacio
        children: [
        // CHAT COMPLEJO (chat_panel_view) - SIEMPRE renderizado, solo cambia visibilidad
        Positioned(
          bottom: 0,
          right: 0,
          child: Visibility(
            visible: isOpen,
            maintainState: true,  // Mantener estado
            child: Container(
              width: 380,
              height: 600,
              decoration: BoxDecoration(
                color: const Color(0xFF181818), // ⬅️ FONDO SÓLIDO EXPLÍCITO
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: Stack(
                  children: [
                    // ⬅️ CHAT_PANEL_VIEW COMPLETO (el que originalmente funcionaba)
                    const ChatPanelView(),
                    // BOTÓN CLOSE ENCIMA (por si el ChatPanelView no tiene uno visible)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => ref.read(isOpenSimpleProvider.notifier).state = false,
                          tooltip: 'Cerrar chat',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // BURBUJA - SIEMPRE renderizada
        Positioned(
          bottom: 40,
          right: 40,
          child: Visibility(
            visible: !isOpen,
            maintainState: true,
            child: GestureDetector(
              onTap: () => ref.read(isOpenSimpleProvider.notifier).state = true,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.chat_bubble,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
