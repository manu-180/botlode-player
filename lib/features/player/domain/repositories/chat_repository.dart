// Archivo: lib/features/player/domain/repositories/chat_repository.dart
import 'package:botlode_player/features/player/domain/models/bot_response.dart';

abstract class ChatRepository {
  /// Envía un mensaje al núcleo de IA (Edge Function) y retorna la respuesta procesada.
  Future<BotResponse> sendMessage({
    required String message,
    required String sessionId,
    required String chatId, // ⬅️ NUEVO: ID persistente del chat (no cambia con reloads)
    required String botId,
  });
}