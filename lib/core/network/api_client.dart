// Archivo: lib/core/network/api_client.dart
import 'dart:convert';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Obtiene la configuración visual del Bot desde la tabla 'bots'
  Future<BotConfig?> getBotConfig(String botId) async {
    try {
      // [FIX] Usamos nombres de columnas estándar (snake_case) para evitar error 400
      // Ajusta 'theme_color' o 'is_dark_mode' si en tu DB se llaman distinto.
      final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/bots?id=eq.$botId&select=*');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          return BotConfig.fromJson(data.first);
        }
      }
      debugPrint("⚠️ API Error Config ${response.statusCode}: ${response.body}");
      return null;
    } catch (e) {
      debugPrint("🔴 Error crítico de conexión (Config): $e");
      return null;
    }
  }

  /// Envía el mensaje a la Edge Function (chat-brain)
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String sessionId,
    required String botId,
  }) async {
    try {
      // AHORA SÍ FUNCIONARÁ: Lee la URL construida en AppConfig
      final urlString = AppConfig.brainFunctionUrl;
      
      if (urlString.isEmpty) {
        throw Exception("URL de Brain Function vacía. Revisa configuración.");
      }

      final uri = Uri.parse(urlString);
      
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
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint("⚠️ Brain Error ${response.statusCode}: ${response.body}");
        throw Exception('Error del Cerebro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("🔴 Error crítico de conexión (Brain): $e");
      return {'reply': 'Error de conexión con el núcleo.', 'mood': 'confused'};
    }
  }
}