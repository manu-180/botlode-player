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

// ⬅️ MEJORADO: Reload inicia un NUEVO chat (nuevo sessionId + estado limpio)
final chatResetProvider = Provider((ref) {
  return () {
    // ⬅️ Iniciar un chat completamente nuevo (nuevo sessionId = nuevo contexto)
    final controller = ref.read(chatControllerProvider.notifier);
    controller.clearChat();
    print("🔄 Nuevo chat iniciado: sessionId nuevo, estado limpio, bot empieza desde cero");
  };
});