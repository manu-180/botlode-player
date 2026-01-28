// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';
import 'package:botlode_player/core/config/supabase_provider.dart';
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

// ⬅️ Helper para formatear hora de Argentina (UTC-3) sin zona horaria
String _formatArgentinaTime() {
  final nowLocal = DateTime.now().toLocal();
  final nowArgentina = nowLocal.subtract(const Duration(hours: 3));
  return '${nowArgentina.year}-${nowArgentina.month.toString().padLeft(2, '0')}-${nowArgentina.day.toString().padLeft(2, '0')}T${nowArgentina.hour.toString().padLeft(2, '0')}:${nowArgentina.minute.toString().padLeft(2, '0')}:${nowArgentina.second.toString().padLeft(2, '0')}.${nowArgentina.millisecond.toString().padLeft(3, '0')}';
}

// ⬅️ MEJORADO: Reload limpia pantalla, resetea estado y olvida contexto (sin borrar historial BD)
final chatResetProvider = Provider((ref) {
  return () {
    // ⬅️ PASO 0.5: INVALIDAR activeSessionId para asegurar que ningún chat muestre "EN LÍNEA" temporalmente
    // ⚠️ CRÍTICO: Esto debe hacerse ANTES de clearChat() para evitar que el chat viejo muestre "EN LÍNEA"
    // ⬅️ NOTA: El chat NO se cierra - solo se vacía y se mantiene abierto
    try {
      ref.read(activeSessionIdProvider.notifier).state = null;
    } catch (e) {
      // Error silenciado
    }
    
    // ⬅️ PASO 1: Limpiar chat (pantalla en blanco, nuevo sessionId, estado idle)
    try {
      final controller = ref.read(chatControllerProvider.notifier);
      controller.clearChat();
    } catch (e) {
      // Error silenciado
    }
    
    // ⬅️ PASO 1.5: Verificar estado DESPUÉS de clearChat y actualizar sessionId activo al NUEVO
    // ⚠️ IMPORTANTE: Actualizar activeSessionId con el nuevo sessionId para que el nuevo chat pueda mostrar "EN LÍNEA"
    // ⬅️ CRÍTICO: Como el chat permanece abierto después del reload, necesitamos reclamar la sesión en BD
    try {
      final stateAfterClear = ref.read(chatControllerProvider);
      final currentSessionId = stateAfterClear.sessionId;
      final currentChatId = stateAfterClear.chatId;
      final botId = ref.read(currentBotIdProvider);
      final supabase = ref.read(supabaseClientProvider);
      
      // ⬅️ PASO 1.5.1: Actualizar el sessionId activo al nuevo (síncrono)
      ref.read(activeSessionIdProvider.notifier).state = currentSessionId;
      
      // ⬅️ PASO 1.5.2: Reclamar sesión en BD (asíncrono) - Como el chat permanece abierto, necesitamos reclamar la sesión
      // Esto asegura que solo este chat esté "EN LÍNEA" en la BD
      (() async {
        try {
          // Marcar TODAS las sesiones de este bot como offline
          await supabase
              .from('session_heartbeats')
              .update({'is_online': false})
              .eq('bot_id', botId);
          
          // Esperar un pequeño delay para asegurar que el UPDATE anterior se complete
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Reclamar SOLO la sesión actual como activa
          await supabase
              .from('session_heartbeats')
              .upsert({
                'session_id': currentSessionId,
                'bot_id': botId,
                'is_online': true,
                'last_seen': _formatArgentinaTime(), // ⬅️ Hora de Argentina (UTC-3)
                'chat_id': currentChatId,
              }, onConflict: 'session_id');
          
          // Verificación final y limpieza agresiva
          await Future.delayed(const Duration(milliseconds: 200));
          
          final verification = await supabase
              .from('session_heartbeats')
              .select('session_id, is_online')
              .eq('bot_id', botId)
              .eq('is_online', true);
          
          if (verification.length > 1 || (verification.length == 1 && verification.first['session_id'] != currentSessionId)) {
            // Forzar limpieza nuevamente
            await supabase
                .from('session_heartbeats')
                .update({'is_online': false})
                .eq('bot_id', botId)
                .neq('session_id', currentSessionId);
            
            await Future.delayed(const Duration(milliseconds: 50));
            
            await supabase
                .from('session_heartbeats')
                .upsert({
                  'session_id': currentSessionId,
                  'bot_id': botId,
                  'is_online': true,
                  'last_seen': _formatArgentinaTime(), // ⬅️ Hora de Argentina (UTC-3)
                  'chat_id': currentChatId,
                }, onConflict: 'session_id');
          }
        } catch (e) {
          // Error silenciado
        }
      })();
    } catch (e) {
      // Error silenciado
    }
    
    // ⬅️ PASO 2: Resetear mood del bot a 'neutral' (estado normal = "EN LÍNEA")
    try {
      ref.read(botMoodProvider.notifier).state = 0; // 0 = neutral/idle
    } catch (e) {
      // Error silenciado
    }
  };
});