// Archivo: lib/core/services/presence_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:botlode_player/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceManager {
  final SupabaseClient _supabase;
  final String sessionId;
  final String botId;
  
  // CONTROLADORES DE TIEMPO
  Timer? _heartbeatTimer;      // El pulso constante (cada 30s)
  Timer? _debounceTimer;       // El filtro de "clicks rápidos"
  Timer? _retryTimer;          // El reintento rápido si falla
  StreamSubscription? _tabCloseSubscription;
  
  // ESTADO OBJETIVO (La verdad absoluta)
  bool _shouldBeOnline = false;

  PresenceManager(this._supabase, {required this.sessionId, required this.botId}) {
    // ⬅️ NUEVO: Configurar listener de cierre de pestaña INMEDIATAMENTE al crear
    // Esto asegura que siempre se marque como offline al cerrar, incluso si está online
    _setupTabCloseListener();
  }

  /// ⬅️ NUEVO: Configurar listener de cierre de pestaña
  void _setupTabCloseListener() {
    _tabCloseSubscription?.cancel();
    _tabCloseSubscription = html.window.onBeforeUnload.listen((event) {
      // ⬅️ CRÍTICO: Marcar como offline al cerrar pestaña (síncrono y confiable)
      print("🚪 Pestaña cerrada -> Marcando como OFFLINE");
      try {
        final url = '${AppConfig.supabaseUrl}/rest/v1/session_heartbeats?on_conflict=session_id';
        final body = jsonEncode({
          'session_id': sessionId,
          'bot_id': botId,
          'is_online': false,
          'last_seen': DateTime.now().toIso8601String(),
        });
        
        // ⬅️ Usar sendBeacon (más confiable para cierre de pestaña, no bloquea)
        // sendBeacon garantiza que se envíe incluso si la pestaña se cierra
        final blob = html.Blob([utf8.encode(body)], 'application/json');
        final success = html.window.navigator.sendBeacon(
          url,
          blob,
        );
        
        if (success) {
          print("✅ Estado OFFLINE enviado con sendBeacon antes de cerrar pestaña");
        } else {
          // ⬅️ Fallback: Intentar petición síncrona si sendBeacon falla
          try {
            final xhr = html.HttpRequest();
            xhr.open('POST', url);
            xhr.setRequestHeader('apikey', AppConfig.supabaseAnonKey);
            xhr.setRequestHeader('Authorization', 'Bearer ${AppConfig.supabaseAnonKey}');
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.setRequestHeader('Prefer', 'resolution=merge-duplicates');
            xhr.send(body);
            print("✅ Estado OFFLINE enviado con XHR síncrono");
          } catch (e2) {
            print("⚠️ Fallback XHR también falló: $e2");
          }
        }
      } catch (e) {
        print("⚠️ Error al marcar offline en cierre de pestaña: $e");
      }
    });
  }

  /// 🟢 ENTRA EN LÍNEA (Con Debounce y Retry)
  void setOnline() {
    _shouldBeOnline = true;
    _scheduleUpdate(true);
  }

  /// 🔴 SALE DE LÍNEA (Con Debounce)
  void setOffline() {
    _shouldBeOnline = false;
    _scheduleUpdate(false);
  }

  /// Lógica de "Embudo" para evitar spam de peticiones
  void _scheduleUpdate(bool targetStatus) {
    // 1. Cancelamos cualquier envío pendiente anterior
    _debounceTimer?.cancel();
    _retryTimer?.cancel();

    // 2. Esperamos 500ms antes de disparar. 
    // Si el usuario abre y cierra rápido, solo se ejecuta el último.
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSignal(targetStatus);
    });
  }

  Future<void> _executeSignal(bool isOnline) async {
    // Verificación de seguridad final
    if (isOnline != _shouldBeOnline) return; 

    // GESTIÓN DEL HEARTBEAT (LATIDO)
    _heartbeatTimer?.cancel();
    if (isOnline) {
      // Si estamos online, iniciamos el latido cada 15 segundos (más rápido para asegurar)
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_shouldBeOnline) _sendToSupabase(true);
      });
    }

    // ⬅️ NOTA: El listener de cierre de pestaña ya está configurado en el constructor
    // No necesitamos reconfigurarlo aquí, ya está siempre activo

    // ENVÍO REAL
    await _sendToSupabase(isOnline);
  }

  Future<void> _sendToSupabase(bool status) async {
    try {
      print("📡 Enviando señal a Supabase: ${status ? 'ONLINE' : 'OFFLINE'}");
      await _supabase.from('session_heartbeats').upsert({
        'session_id': sessionId,
        'bot_id': botId,
        'is_online': status,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');
    } catch (e) {
      print("⚠️ Error de red ($e). Reintentando en 2s...");
      // REINTENTO RÁPIDO (Quick Retry Strategy)
      if (_shouldBeOnline == status) {
        _retryTimer = Timer(const Duration(seconds: 2), () {
           if (_shouldBeOnline == status) _sendToSupabase(status);
        });
      }
    }
  }
}