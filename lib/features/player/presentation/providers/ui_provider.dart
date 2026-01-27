// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';
import 'package:botlode_player/core/services/chat_persistence_service.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui_provider.g.dart';

@riverpod
class ChatOpen extends _$ChatOpen {
  @override
  bool build() {
    return false; // ✅ CHAT CERRADO POR DEFECTO (burbuja visible)
  }

  void set(bool value) {
    state = value;
  }
}

// Provider existente para posición
final pointerPositionProvider = StateProvider<Offset?>((ref) => null);

// --- NUEVO: Provider para Hover Externo (Controlado por HTML) ---
//asdsad
final isHoveredExternalProvider = StateProvider<bool>((ref) => false);

// ⬅️ MEJORADO: Reload limpia pantalla, resetea estado y olvida contexto (sin borrar historial BD)
final chatResetProvider = Provider((ref) {
  return () {
    // ⬅️ PASO 1: Limpiar chat (pantalla en blanco, nuevo sessionId, estado idle)
    final controller = ref.read(chatControllerProvider.notifier);
    controller.clearChat();
    
    // ⬅️ PASO 2: Resetear mood del bot a 'idle' (estado normal)
    ref.read(botMoodProvider.notifier).state = 0; // 0 = idle
    
    // ⬅️ PASO 3: Invalidar provider para forzar rebuild completo
    ref.invalidate(chatControllerProvider);
    
    print("🔄 Reload completo: pantalla en blanco, bot en estado 'idle', nuevo contexto (bot olvidó todo, historial BD intacto)");
  };
});