// Archivo: lib/core/network/api_client.dart
import 'dart:convert';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // Singleton simple
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String sessionId,
    required String botId,
  }) async {
    try {
      final uri = Uri.parse(AppConfig.brainFunctionUrl);
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'botId': botId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        // Éxito: Devolvemos el JSON { "reply": "...", "mood": "..." }
        // Decodificamos utf8 explícitamente para evitar problemas con tildes/eñes
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Error del servidor: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Si falla, devolvemos un error controlado para que la UI no explote
      return {
        'reply': 'Error de conexión con el núcleo: $e',
        'mood': 'confused' // Ponemos al bot en modo confundido
      };
    }
  }
}