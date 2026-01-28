// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';
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

// ⬅️ Provider para trackear el sessionId activo (el más reciente)
// Solo el chat con este sessionId debe mostrar "EN LÍNEA"
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

// ⬅️ MEJORADO: Reload limpia pantalla, resetea estado y olvida contexto (sin borrar historial BD)
final chatResetProvider = Provider((ref) {
  return () {
    print("🟢 [DEBUG] chatResetProvider() - INICIO DEL RELOAD");
    
    // ⬅️ PASO 0: Verificar estado ANTES del reset
    try {
      final currentState = ref.read(chatControllerProvider);
      print("🟢 [DEBUG] chatResetProvider() - ESTADO ANTES: ${currentState.messages.length} mensajes, sessionId: ${currentState.sessionId}, mood: ${currentState.currentMood}");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - Error leyendo estado antes: $e");
    }
    
    // ⬅️ PASO 0.5: CERRAR EL CHAT PRIMERO para desmontar el widget inmediatamente
    // ⚠️ CRÍTICO: Esto debe hacerse PRIMERO para que el widget se desmonte y no pueda mostrar "EN LÍNEA"
    print("🟢 [DEBUG] chatResetProvider() - PASO 0.5: Cerrando chat PRIMERO (desmonta widget inmediatamente)");
    try {
      ref.read(chatOpenProvider.notifier).set(false);
      print("🟢 [DEBUG] chatResetProvider() - Chat cerrado - widget se desmontará inmediatamente");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - ERROR cerrando chat: $e");
    }
    
    // ⬅️ PASO 0.6: INVALIDAR activeSessionId para asegurar que ningún chat muestre "EN LÍNEA"
    // ⚠️ CRÍTICO: Esto debe hacerse DESPUÉS de cerrar el chat pero ANTES de clearChat()
    print("🟢 [DEBUG] chatResetProvider() - PASO 0.6: Invalidando activeSessionId (ningún chat mostrará 'EN LÍNEA')");
    try {
      ref.read(activeSessionIdProvider.notifier).state = null;
      print("🟢 [DEBUG] chatResetProvider() - activeSessionId invalidado (null)");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - ERROR invalidando activeSessionId: $e");
    }
    
    // ⬅️ PASO 1: Limpiar chat (pantalla en blanco, nuevo sessionId, estado idle)
    print("🟢 [DEBUG] chatResetProvider() - PASO 1: Llamando a clearChat()");
    try {
      final controller = ref.read(chatControllerProvider.notifier);
      print("🟢 [DEBUG] chatResetProvider() - Controller obtenido: ${controller.runtimeType}");
      controller.clearChat();
      print("🟢 [DEBUG] chatResetProvider() - clearChat() completado");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - ERROR en clearChat(): $e");
    }
    
    // ⬅️ PASO 1.5: Verificar estado DESPUÉS de clearChat y actualizar sessionId activo al NUEVO
    // ⚠️ IMPORTANTE: Actualizar activeSessionId con el nuevo sessionId para que el nuevo chat pueda mostrar "EN LÍNEA" cuando se abra
    try {
      final stateAfterClear = ref.read(chatControllerProvider);
      print("🟢 [DEBUG] chatResetProvider() - ESTADO DESPUÉS de clearChat: ${stateAfterClear.messages.length} mensajes, sessionId: ${stateAfterClear.sessionId}, mood: ${stateAfterClear.currentMood}");
      
      // ⬅️ Actualizar el sessionId activo al nuevo (solo este chat mostrará "EN LÍNEA" cuando se abra)
      ref.read(activeSessionIdProvider.notifier).state = stateAfterClear.sessionId;
      print("🟢 [DEBUG] chatResetProvider() - activeSessionId actualizado a: ${stateAfterClear.sessionId} (nuevo chat será el activo)");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - Error leyendo estado después de clearChat: $e");
    }
    
    // ⬅️ PASO 2: Resetear mood del bot a 'neutral' (estado normal = "EN LÍNEA")
    print("🟢 [DEBUG] chatResetProvider() - PASO 2: Reseteando mood a 0 (neutral)");
    try {
      final moodBefore = ref.read(botMoodProvider);
      print("🟢 [DEBUG] chatResetProvider() - Mood ANTES: $moodBefore");
      ref.read(botMoodProvider.notifier).state = 0; // 0 = neutral/idle
      final moodAfter = ref.read(botMoodProvider);
      print("🟢 [DEBUG] chatResetProvider() - Mood DESPUÉS: $moodAfter");
      
      // ⬅️ Asegurar que el estado del chat también esté en 'neutral'
      // El estado ya se resetea a 'neutral' en clearChat(), no necesitamos hacerlo aquí
      print("🟢 [DEBUG] chatResetProvider() - Estado del chat ya está en 'neutral' (reseteado en clearChat)");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - ERROR reseteando mood: $e");
    }
    
    // ⬅️ PASO 3.5: NO invalidar el provider (causa LateInitializationError)
    // En su lugar, forzar un rebuild del estado directamente
    print("🟢 [DEBUG] chatResetProvider() - PASO 3.5: Forzando actualización de estado (sin invalidar provider)");
    try {
      // El estado ya fue actualizado en clearChat(), solo necesitamos que la UI se actualice
      // No invalidamos para evitar el error de LateInitializationError
      print("🟢 [DEBUG] chatResetProvider() - Estado actualizado directamente en clearChat()");
    } catch (e) {
      print("🟢 [DEBUG] chatResetProvider() - ERROR actualizando estado: $e");
    }
    
    // ⬅️ PASO 4: Verificar estado FINAL
    Future.microtask(() {
      try {
        final finalState = ref.read(chatControllerProvider);
        print("🟢 [DEBUG] chatResetProvider() - ESTADO FINAL: ${finalState.messages.length} mensajes, sessionId: ${finalState.sessionId}, mood: ${finalState.currentMood}");
      } catch (e) {
        print("🟢 [DEBUG] chatResetProvider() - Error leyendo estado final: $e");
      }
    });
    
    print("🟢 [DEBUG] chatResetProvider() - FIN DEL RELOAD");
    print("🔄 Reload completo: pantalla en blanco, bot en estado 'idle', nuevo contexto (bot olvidó todo, historial BD intacto)");
  };
});