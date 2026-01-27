// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';
import 'package:botlode_player/core/services/chat_persistence_service.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
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

// ⬅️ MEJORADO: Reload limpia el contexto (nuevo sessionId) pero NO borra mensajes de BD
final chatResetProvider = Provider((ref) {
  return () {
    // ⬅️ NUEVO: Limpiar contexto (crea nuevo sessionId, el bot "olvida" lo anterior)
    ChatPersistenceService.clearContext();
    // Invalidar el provider para que se recree con el nuevo sessionId
    ref.invalidate(chatControllerProvider);
    print("🔄 Chat reiniciado: nuevo contexto creado (mensajes de BD se mantienen)");
  };
});