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
    print("🟣 [DEBUG] createNewSessionId() - INICIO");
    try {
      final oldSessionId = html.window.localStorage[_sessionIdKey];
      print("🟣 [DEBUG] createNewSessionId() - sessionId anterior: $oldSessionId");
      
      final newSessionId = _uuid.v4();
      print("🟣 [DEBUG] createNewSessionId() - nuevo sessionId generado: $newSessionId");
      
      saveSessionId(newSessionId);
      print("🟣 [DEBUG] createNewSessionId() - sessionId guardado en localStorage");
      
      // Guardar timestamp del reset para que el bot sepa que es un nuevo contexto
      final resetTime = DateTime.now().toIso8601String();
      html.window.localStorage[_lastResetKey] = resetTime;
      print("🟣 [DEBUG] createNewSessionId() - timestamp de reset guardado: $resetTime");
      
      print("🟣 [DEBUG] createNewSessionId() - FIN, retornando: $newSessionId");
      return newSessionId;
    } catch (e) {
      print("🟣 [DEBUG] createNewSessionId() - ERROR: $e");
      final fallbackId = _uuid.v4();
      print("🟣 [DEBUG] createNewSessionId() - usando fallback: $fallbackId");
      return fallbackId;
    }
  }

  // ⬅️ Obtener mensajes guardados
  static List<ChatMessage> getStoredMessages() {
    print("🟦 [DEBUG] getStoredMessages() - INICIO");
    try {
      final stored = html.window.localStorage[_messagesKey];
      print("🟦 [DEBUG] getStoredMessages() - valor en localStorage: ${stored != null ? 'existe (${stored.length} chars)' : 'null'}");
      
      if (stored == null || stored.isEmpty) {
        print("🟦 [DEBUG] getStoredMessages() - localStorage vacío, retornando lista vacía");
        return [];
      }
      
      print("🟦 [DEBUG] getStoredMessages() - decodificando JSON...");
      final List<dynamic> decoded = jsonDecode(stored);
      print("🟦 [DEBUG] getStoredMessages() - JSON decodificado, ${decoded.length} elementos");
      
      final messages = decoded.map((json) => ChatMessage.fromJson(json)).toList();
      print("🟦 [DEBUG] getStoredMessages() - mensajes parseados: ${messages.length}");
      for (var i = 0; i < messages.length; i++) {
        print("🟦 [DEBUG] getStoredMessages() - mensaje $i: ${messages[i].text.substring(0, messages[i].text.length > 30 ? 30 : messages[i].text.length)}...");
      }
      
      print("🟦 [DEBUG] getStoredMessages() - FIN, retornando ${messages.length} mensajes");
      return messages;
    } catch (e) {
      print("🟦 [DEBUG] getStoredMessages() - ERROR: $e");
      return [];
    }
  }

  // ⬅️ Guardar mensajes
  static void saveMessages(List<ChatMessage> messages) {
    print("🟡 [DEBUG] saveMessages() - INICIO, cantidad: ${messages.length}");
    try {
      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      print("🟡 [DEBUG] saveMessages() - JSON generado, longitud: ${encoded.length} caracteres");
      html.window.localStorage[_messagesKey] = encoded;
      print("🟡 [DEBUG] saveMessages() - mensajes guardados en localStorage");
      
      // Verificar que se guardó correctamente
      final stored = html.window.localStorage[_messagesKey];
      if (stored != null) {
        final decoded = jsonDecode(stored) as List;
        print("🟡 [DEBUG] saveMessages() - verificación: ${decoded.length} mensajes en localStorage");
      } else {
        print("🟡 [DEBUG] saveMessages() - ⚠️ ADVERTENCIA: localStorage está vacío después de guardar");
      }
    } catch (e) {
      print("🟡 [DEBUG] saveMessages() - ERROR: $e");
    }
    print("🟡 [DEBUG] saveMessages() - FIN");
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

  // ⬅️ NUEVO: Obtener o crear chatId persistente (NO cambia con reloads)
  // Este ID identifica la conversación completa, mientras que sessionId identifica el contexto actual
  static String getOrCreateChatId() {
    try {
      final stored = html.window.localStorage[_chatIdKey];
      if (stored != null && stored.isNotEmpty) {
        print("🟣 [DEBUG] getOrCreateChatId() - chatId existente: $stored");
        return stored;
      }
      // Crear nuevo chatId (solo la primera vez)
      final newChatId = _uuid.v4();
      html.window.localStorage[_chatIdKey] = newChatId;
      print("🟣 [DEBUG] getOrCreateChatId() - nuevo chatId creado: $newChatId");
      return newChatId;
    } catch (e) {
      print("⚠️ Error obteniendo chatId: $e");
      final fallbackId = _uuid.v4();
      print("🟣 [DEBUG] getOrCreateChatId() - usando fallback: $fallbackId");
      return fallbackId;
    }
  }

  // ⬅️ NUEVO: Obtener chatId actual (sin crear uno nuevo)
  static String? getChatId() {
    try {
      return html.window.localStorage[_chatIdKey];
    } catch (e) {
      print("⚠️ Error obteniendo chatId: $e");
      return null;
    }
  }

  // ⬅️ NUEVO: Resetear chatId (solo cuando se quiere iniciar una conversación completamente nueva)
  // Normalmente NO se usa, ya que el chatId persiste a través de reloads
  static String resetChatId() {
    try {
      final oldChatId = html.window.localStorage[_chatIdKey];
      print("🟣 [DEBUG] resetChatId() - chatId anterior: $oldChatId");
      
      final newChatId = _uuid.v4();
      html.window.localStorage[_chatIdKey] = newChatId;
      print("🟣 [DEBUG] resetChatId() - nuevo chatId creado: $newChatId");
      return newChatId;
    } catch (e) {
      print("⚠️ Error reseteando chatId: $e");
      return _uuid.v4();
    }
  }

}
