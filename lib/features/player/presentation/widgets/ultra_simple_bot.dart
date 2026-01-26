// ULTRA SIMPLE - Burbuja + Chat desde cero
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider simple
final isOpenSimpleProvider = StateProvider<bool>((ref) => false);

class UltraSimpleBot extends ConsumerWidget {
  const UltraSimpleBot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(isOpenSimpleProvider);
    
    return Stack(
      children: [
        // CHAT - SIEMPRE renderizado, solo cambia visibilidad
        Positioned(
          bottom: 0,
          right: 0,
          child: Visibility(
            visible: isOpen,
            maintainState: true,  // Mantener estado
            child: Container(
              width: 380,
              height: 600,
              color: const Color(0xFF181818), // Gris directo
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 80,
                    color: const Color(0xFF2C2C2C),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            'ULTRA SIMPLE CHAT',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => ref.read(isOpenSimpleProvider.notifier).state = false,
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Expanded(
                    child: Container(
                      color: const Color(0xFF181818),
                      alignment: Alignment.center,
                      child: const Text(
                        '✅ SI VES ESTO, GANAMOS',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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
    );
  }
}
