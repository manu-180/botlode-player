// Archivo: lib/features/player/data/repositories/chat_repository_impl.dart
import 'dart:convert';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/features/player/domain/models/bot_response.dart';
import 'package:botlode_player/features/player/domain/repositories/chat_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChatRepositoryImpl implements ChatRepository {
  
  @override
  Future<BotResponse> sendMessage({
    required String message,
    required String sessionId,
    required String chatId, // ⬅️ NUEVO: ID persistente del chat
    required String botId,
  }) async {
    try {
      final urlString = AppConfig.brainFunctionUrl;
      if (urlString.isEmpty) throw Exception("URL de Brain no configurada");

      final uri = Uri.parse(urlString);
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'chatId': chatId, // ⬅️ NUEVO: ID persistente del chat
          'botId': botId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        // Decodificación segura de UTF-8 para caracteres especiales
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonMap = jsonDecode(decodedBody);
        return BotResponse.fromJson(jsonMap);
      } else {
        throw Exception('Error del Cerebro: Código ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("🔴 API Error (Brain): $e");
      // Fallback de seguridad para no romper la UX
      return const BotResponse(
        reply: 'Lo siento, he perdido la conexión con mi núcleo. Intenta de nuevo.',
        mood: 'confused'
      );
    }
  }
}