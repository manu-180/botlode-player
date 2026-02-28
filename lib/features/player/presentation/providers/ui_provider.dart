// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:async';
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

// ⬅️ NUEVO: Provider para bloquear el hover después de cerrar el chat
// Cuando se cierra el chat, este flag se activa y previene que el hover se active
// hasta que el mouse salga y vuelva a entrar en la burbuja
final hoverLockedProvider = StateProvider<bool>((ref) => false);

// ⬅️ Provider para trackear el sessionId activo (el más reciente)
// Solo el chat con este sessionId debe mostrar "EN LÍNEA"
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

// ⬅️ NUEVO: Ocultar Rive al abrir desde la burbuja (móvil) para ganar espacio.
// Se activa al hacer click en la burbuja; se desactiva al hacer tap en el área del chat.
final hideRiveForSpaceProvider = StateProvider<bool>((ref) => false);

// ═══════════════════════════════════════════════════════════════════════════════
// UX PREMIUM RIVE: Entrada/salida, typing, hover, listening, mood decay, reduced motion
// ═══════════════════════════════════════════════════════════════════════════════

/// Usuario está escribiendo en el input (texto no vacío). El gato puede reaccionar (atento).
final userIsTypingProvider = StateProvider<bool>((ref) => false);

/// Hover sobre el avatar del gato. Para reacción sutil (oreja, parpadeo).
final avatarHoveredProvider = StateProvider<bool>((ref) => false);

/// Incrementar para disparar gesto "te escucho" en Rive (al hacer tap en el gato).
final avatarListeningTriggerProvider = StateProvider<int>((ref) => 0);

/// Incrementar cuando el chat se ABRE para reproducir animación "hola" en Rive.
final riveEntryTriggerProvider = StateProvider<int>((ref) => 0);

/// Incrementar cuando el chat se CIERRA para reproducir animación "hasta luego" en Rive.
final riveExitTriggerProvider = StateProvider<int>((ref) => 0);

/// True mientras se está cerrando el chat (300ms de animación). Evita que el cierre retrasado cierre si el usuario reabrió.
final isClosingChatProvider = StateProvider<bool>((ref) => false);

/// Segundos antes de volver a neutral (0 = no decay). Mínimo 6 recomendado.
final moodDecaySecondsProvider = StateProvider<int>((ref) => 6);

/// Reduced motion para accesibilidad: idle más quieto en Rive.
final reducedMotionProvider = StateProvider<bool>((ref) => false);

/// Incrementar cuando el bot acaba de enviar mensaje (anticipación / "acabo de hablar").
final botJustSpokeTriggerProvider = StateProvider<int>((ref) => 0);

/// Controlador para decay del mood: volver a neutral tras N segundos sin que el usuario escriba de nuevo.
class MoodDecayController {
  MoodDecayController(this._ref);
  final Ref _ref;
  Timer? _timer;

  void startDecay() {
    _timer?.cancel();
    final seconds = _ref.read(moodDecaySecondsProvider);
    if (seconds <= 0) return;
    _timer = Timer(Duration(seconds: seconds), () {
      try {
        _ref.read(botMoodProvider.notifier).state = 0;
      } catch (_) {}
    });
  }

  void cancelDecay() {
    _timer?.cancel();
    _timer = null;
  }
}

final moodDecayProvider = Provider<MoodDecayController>((ref) {
  return MoodDecayController(ref);
});

// ⬅️ BLINDAJE INPUT: Cuando el HTML padre envía CMD_FOCUS_INPUT (chat abierto en iframe),
// se incrementa este valor. ChatPanelView lo escucha y fuerza requestFocus en el input.
final focusChatInputTriggerProvider = StateProvider<int>((ref) => 0);

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