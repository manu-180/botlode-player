// Archivo: lib/core/services/presence_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:botlode_player/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ⬅️ Helper para formatear hora de Argentina (UTC-3) sin zona horaria
// Función top-level para que se pueda usar en todos los archivos
String _formatArgentinaTimestamp(DateTime dateTime) {
  return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}T${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}.${dateTime.millisecond.toString().padLeft(3, '0')}';
}

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
      
      // ⬅️ Cancelar todos los timers para evitar actualizaciones posteriores
      _heartbeatTimer?.cancel();
      _debounceTimer?.cancel();
      _retryTimer?.cancel();
      
      // ⬅️ Forzar estado offline
      _shouldBeOnline = false;
      
      try {
        final url = '${AppConfig.supabaseUrl}/rest/v1/session_heartbeats?on_conflict=session_id';
        // ⬅️ Hora de Argentina (UTC-3): restar 3 horas y formatear sin zona horaria
        final nowLocal = DateTime.now().toLocal();
        final nowArgentina = nowLocal.subtract(const Duration(hours: 3));
        final timestampString = _formatArgentinaTimestamp(nowArgentina);
        final body = jsonEncode({
          'session_id': sessionId,
          'bot_id': botId,
          'is_online': false,
          'last_seen': timestampString, // ⬅️ Hora de Argentina (UTC-3) sin zona horaria
        });
        
        // ⬅️ ESTRATEGIA DUAL: Intentar sendBeacon primero, luego XHR síncrono como fallback
        // sendBeacon puede fallar en algunos navegadores con JSON, así que siempre tenemos fallback
        
        // 1. Intentar sendBeacon (no bloquea, más confiable)
        try {
          final blob = html.Blob([utf8.encode(body)], 'application/json');
          final beaconSuccess = html.window.navigator.sendBeacon(
            url,
            blob,
          );
          
          if (beaconSuccess) {
            return; // Si sendBeacon funciona, no necesitamos XHR
          }
        } catch (beaconError) {
          // Error silenciado, usar fallback XHR
        }
        
        // 2. Fallback: XHR SÍNCRONO (bloquea pero garantiza envío)
        try {
          final xhr = html.HttpRequest();
          // ⬅️ CRÍTICO: async: false hace que sea síncrono (bloquea hasta completar)
          // En dart:html, open() acepta async como parámetro opcional (por defecto true)
          xhr.open('POST', url, async: false);
          xhr.setRequestHeader('apikey', AppConfig.supabaseAnonKey);
          xhr.setRequestHeader('Authorization', 'Bearer ${AppConfig.supabaseAnonKey}');
          xhr.setRequestHeader('Content-Type', 'application/json');
          xhr.setRequestHeader('Prefer', 'resolution=merge-duplicates');
          
          // ⬅️ Enviar de forma síncrona (bloquea hasta que se complete)
          xhr.send(body);
          
          // ⬅️ Verificar respuesta (solo si la petición se completó)
          final status = xhr.status;
          if (xhr.readyState == html.HttpRequest.DONE && status != null) {
            // Estado enviado o error silenciado
          }
        } catch (xhrError) {
          // Error silenciado
        }
      } catch (e) {
        // Error silenciado
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

  /// 🔴 SALE DE LÍNEA INMEDIATAMENTE (Sin Debounce) - Para cuando se cierra el chat
  /// ⚠️ CRÍTICO: Usar este método cuando se cierra el chat para evitar condiciones de carrera
  Future<void> setOfflineImmediate() async {
    _shouldBeOnline = false;
    // Cancelar todos los timers
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    // Enviar inmediatamente sin debounce
    await _sendToSupabase(false);
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
      // ⬅️ Hora de Argentina (UTC-3): restar 3 horas y asegurar que se guarde como hora local
      final nowLocal = DateTime.now().toLocal();
      final nowArgentina = nowLocal.subtract(const Duration(hours: 3));
      // ⬅️ Formatear como string sin zona horaria para que Supabase lo interprete como hora local
      final timestampString = _formatArgentinaTimestamp(nowArgentina);
      
      // ⬅️ CRÍTICO: Si estamos marcando como online, NO actualizar is_online aquí
      // La reclamación de sesión ya se encargó de eso. Solo actualizamos last_seen para el heartbeat.
      // Si estamos marcando como offline, SÍ actualizamos is_online para desactivar.
      if (status) {
        // Solo actualizar last_seen, NO tocar is_online (la reclamación de sesión ya lo hizo)
        await _supabase.from('session_heartbeats').upsert({
          'session_id': sessionId,
          'bot_id': botId,
          'last_seen': timestampString, // ⬅️ Hora de Argentina (UTC-3) sin zona horaria
          // ⬅️ NO actualizar is_online aquí - la reclamación de sesión ya lo hizo
        }, onConflict: 'session_id');
      } else {
        // Si es offline, SÍ actualizar is_online para desactivar
        await _supabase.from('session_heartbeats').upsert({
          'session_id': sessionId,
          'bot_id': botId,
          'is_online': false,
          'last_seen': timestampString, // ⬅️ Hora de Argentina (UTC-3) sin zona horaria
        }, onConflict: 'session_id');
      }
    } catch (e) {
      // REINTENTO RÁPIDO (Quick Retry Strategy)
      if (_shouldBeOnline == status) {
        _retryTimer = Timer(const Duration(seconds: 2), () {
           if (_shouldBeOnline == status) _sendToSupabase(status);
        });
      }
    }
  }
}