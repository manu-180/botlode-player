// Archivo: lib/core/services/presence_manager.dart
import 'dart:async';
import 'dart:html' as html; // Necesario para detectar el cierre de pestaña
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceManager {
  final SupabaseClient _supabase;
  final String sessionId;
  final String botId;
  
  Timer? _heartbeatTimer;
  StreamSubscription? _tabCloseSubscription;

  PresenceManager(this._supabase, {required this.sessionId, required this.botId});

  /// 🟢 ENTRA EN LÍNEA + ACTIVA MONITOR
  Future<void> setOnline() async {
    // 1. Enviar señal inicial INMEDIATA
    await _sendSignal(true);

    // 2. Iniciar "Latido" (Heartbeat)
    // Actualizamos el estado cada 20 segundos para decir "Sigo aquí"
    // Esto asegura que si el navegador crashea, el dashboard notará la ausencia de latido.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendSignal(true);
    });

    // 3. Escuchar cierre de pestaña (La "X" del navegador)
    // Esto intenta enviar la señal de apagado justo antes de morir.
    _tabCloseSubscription?.cancel();
    _tabCloseSubscription = html.window.onBeforeUnload.listen((event) {
      // Intentamos una despedida rápida
      _sendSignal(false);
      // Nota: En algunos navegadores modernos esto puede no completarse si es muy lento,
      // por eso el _heartbeatTimer es nuestro respaldo de seguridad.
    });
    
    // print("🟢 Presencia: ONLINE (Latido activado)");
  }

  /// 🔴 SALE DE LÍNEA + LIMPIEZA
  Future<void> setOffline() async {
    _heartbeatTimer?.cancel();
    _tabCloseSubscription?.cancel();
    await _sendSignal(false);
    // print("🔴 Presencia: OFFLINE (Latido detenido)");
  }

  /// Método interno para hablar con Supabase
  Future<void> _sendSignal(bool isOnline) async {
    try {
      await _supabase.from('session_heartbeats').upsert({
        'session_id': sessionId,
        'bot_id': botId,
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');
    } catch (e) {
      // Silencioso para no ensuciar logs en cierre de app
      // print("⚠️ Error de señal: $e");
    }
  }
}