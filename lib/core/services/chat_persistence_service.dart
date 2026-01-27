// Archivo: lib/core/services/chat_persistence_service.dart
// Servicio para persistir el estado del chat en localStorage

import 'dart:html' as html;
import 'dart:convert';
import 'package:botlode_player/features/player/domain/models/chat_message.dart';
import 'package:uuid/uuid.dart';

class ChatPersistenceService {
  static const String _sessionIdKey = 'botlode_chat_session_id';
  static const String _messagesKey = 'botlode_chat_messages';
  static const String _lastResetKey = 'botlode_chat_last_reset';
  static const _uuid = Uuid();

  // ⬅️ Obtener o crear sessionId persistente
  static String getOrCreateSessionId() {
    try {
      final stored = html.window.localStorage[_sessionIdKey];
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }
      // Crear nuevo sessionId
      final newSessionId = _uuid.v4();
      html.window.localStorage[_sessionIdKey] = newSessionId;
      return newSessionId;
    } catch (e) {
      print("⚠️ Error obteniendo sessionId: $e");
      return _uuid.v4();
    }
  }

  // ⬅️ Guardar sessionId
  static void saveSessionId(String sessionId) {
    try {
      html.window.localStorage[_sessionIdKey] = sessionId;
    } catch (e) {
      print("⚠️ Error guardando sessionId: $e");
    }
  }

  // ⬅️ Crear nuevo sessionId (para reload)
  static String createNewSessionId() {
    final newSessionId = _uuid.v4();
    saveSessionId(newSessionId);
    // Guardar timestamp del reset para que el bot sepa que es un nuevo contexto
    html.window.localStorage[_lastResetKey] = DateTime.now().toIso8601String();
    return newSessionId;
  }

  // ⬅️ Obtener mensajes guardados
  static List<ChatMessage> getStoredMessages() {
    try {
      final stored = html.window.localStorage[_messagesKey];
      if (stored == null || stored.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(stored);
      return decoded.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      print("⚠️ Error cargando mensajes: $e");
      return [];
    }
  }

  // ⬅️ Guardar mensajes
  static void saveMessages(List<ChatMessage> messages) {
    try {
      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      html.window.localStorage[_messagesKey] = encoded;
    } catch (e) {
      print("⚠️ Error guardando mensajes: $e");
    }
  }

  // ⬅️ Limpiar persistencia (solo para reload - NO borra mensajes de BD)
  static void clearContext() {
    try {
      // Crear nuevo sessionId (el bot "olvida" el contexto anterior)
      createNewSessionId();
      // Limpiar mensajes del localStorage (pero NO de la BD)
      html.window.localStorage.remove(_messagesKey);
    } catch (e) {
      print("⚠️ Error limpiando contexto: $e");
    }
  }

  // ⬅️ Obtener timestamp del último reset
  static DateTime? getLastResetTime() {
    try {
      final stored = html.window.localStorage[_lastResetKey];
      if (stored == null || stored.isEmpty) {
        return null;
      }
      return DateTime.parse(stored);
    } catch (e) {
      print("⚠️ Error obteniendo último reset: $e");
      return null;
    }
  }

}
