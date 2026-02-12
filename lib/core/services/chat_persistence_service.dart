// Archivo: lib/core/services/chat_persistence_service.dart
// Servicio para persistir el estado del chat en localStorage

import 'dart:html' as html;
import 'dart:convert';
import 'package:botlode_player/features/player/domain/models/chat_message.dart';
import 'package:uuid/uuid.dart';

class ChatPersistenceService {
  static const String _sessionIdKey = 'botlode_chat_session_id';
  static const String _chatIdKey = 'botlode_chat_id'; // ⬅️ NUEVO: ID persistente del chat (no cambia con reloads)
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
    } catch (_) {
      return _uuid.v4();
    }
  }

  // ⬅️ Guardar sessionId
  static void saveSessionId(String sessionId) {
    try {
      html.window.localStorage[_sessionIdKey] = sessionId;
    } catch (_) {}
  }

  // ⬅️ Crear nuevo sessionId (para reload)
  static String createNewSessionId() {
    try {
      final newSessionId = _uuid.v4();
      saveSessionId(newSessionId);
      final resetTime = DateTime.now().toIso8601String();
      html.window.localStorage[_lastResetKey] = resetTime;
      return newSessionId;
    } catch (_) {
      return _uuid.v4();
    }
  }

  // ⬅️ Obtener mensajes guardados
  static List<ChatMessage> getStoredMessages() {
    try {
      final stored = html.window.localStorage[_messagesKey];
      if (stored == null || stored.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(stored);
      return decoded.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  // ⬅️ Guardar mensajes
  static void saveMessages(List<ChatMessage> messages) {
    try {
      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      html.window.localStorage[_messagesKey] = encoded;
    } catch (_) {}
  }

  // ⬅️ Limpiar persistencia (solo para reload - NO borra mensajes de BD)
  // ⚠️ NOTA: Este método ya no se usa directamente, se usa createNewSessionId() + saveMessages([])
  // Se mantiene por compatibilidad pero el flujo correcto es crear nuevo sessionId y limpiar mensajes
  static void clearContext() {
    try {
      // Crear nuevo sessionId (el bot "olvida" el contexto anterior)
      createNewSessionId();
      // Limpiar mensajes del localStorage (pero NO de la BD)
      html.window.localStorage.remove(_messagesKey);
    } catch (_) {}
  }

  // ⬅️ Obtener timestamp del último reset
  static DateTime? getLastResetTime() {
    try {
      final stored = html.window.localStorage[_lastResetKey];
      if (stored == null || stored.isEmpty) {
        return null;
      }
      return DateTime.parse(stored);
    } catch (_) {
      return null;
    }
  }

  // ⬅️ NUEVO: Obtener o crear chatId persistente (NO cambia con reloads)
  // Este ID identifica la conversación completa, mientras que sessionId identifica el contexto actual
  static String getOrCreateChatId() {
    try {
      final stored = html.window.localStorage[_chatIdKey];
      if (stored != null && stored.isNotEmpty) return stored;
      final newChatId = _uuid.v4();
      html.window.localStorage[_chatIdKey] = newChatId;
      return newChatId;
    } catch (_) {
      return _uuid.v4();
    }
  }

  // ⬅️ NUEVO: Obtener chatId actual (sin crear uno nuevo)
  static String? getChatId() {
    try {
      return html.window.localStorage[_chatIdKey];
    } catch (_) {
      return null;
    }
  }

  // ⬅️ NUEVO: Resetear chatId (solo cuando se quiere iniciar una conversación completamente nueva)
  // Normalmente NO se usa, ya que el chatId persiste a través de reloads
  static String resetChatId() {
    try {
      final newChatId = _uuid.v4();
      html.window.localStorage[_chatIdKey] = newChatId;
      return newChatId;
    } catch (_) {
      return _uuid.v4();
    }
  }

}
