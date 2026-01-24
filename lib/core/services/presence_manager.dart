// Archivo: lib/core/services/presence_manager.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceManager {
  final SupabaseClient _supabase;
  final String sessionId;
  final String botId;
  
  Timer? _heartbeatTimer;
  StreamSubscription? _tabCloseSubscription;
  
  // GUARDIA DE SEGURIDAD:
  // Esta variable es la "Verdad Absoluta". Si es false, no sale ni un byte.
  bool _shouldBeOnline = false;

  PresenceManager(this._supabase, {required this.sessionId, required this.botId});

  /// 🟢 ENTRA EN LÍNEA
  Future<void> setOnline() async {
    // 1. Establecemos la intención oficial
    _shouldBeOnline = true;
    
    // 2. Limpiamos cualquier timer anterior para evitar duplicados
    _stopHeartbeat();

    // 3. Enviamos señal inicial YA
    await _sendSignal(true);

    // 4. Iniciamos el Latido Seguro
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      // VERIFICACIÓN CRÍTICA:
      // Si por alguna razón el jefe dijo "Offline" y este timer sigue vivo...
      if (!_shouldBeOnline) {
        timer.cancel(); // Se suicida
        return;         // No envía nada
      }
      _sendSignal(true);
    });

    // 5. Escuchar cierre de pestaña
    _tabCloseSubscription?.cancel();
    _tabCloseSubscription = html.window.onBeforeUnload.listen((event) {
      _sendSignal(false);
    });
  }

  /// 🔴 SALE DE LÍNEA
  Future<void> setOffline() async {
    // 1. Cambiamos la intención oficial INMEDIATAMENTE
    _shouldBeOnline = false;
    
    // 2. Matamos los procesos
    _stopHeartbeat();
    _tabCloseSubscription?.cancel();
    
    // 3. Enviamos la señal final de adiós
    await _sendSignal(false);
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendSignal(bool isOnline) async {
    // CAPA DE SEGURIDAD FINAL:
    // Si intentamos enviar "Online" (true), pero la bandera dice que deberíamos estar "Offline"...
    // BLOQUEAMOS EL ENVÍO. Esto evita que un request viejo llegue tarde y prenda la luz.
    if (isOnline && !_shouldBeOnline) return;

    try {
      await _supabase.from('session_heartbeats').upsert({
        'session_id': sessionId,
        'bot_id': botId,
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');
    } catch (e) {
      // Silencio en errores de red al cerrar
    }
  }
}