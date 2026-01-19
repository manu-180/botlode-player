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

  /// Obtiene la configuración del Bot
  Future<BotConfig?> getBotConfig(String botId) async {
    try {
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
      debugPrint("⚠️ API Config Error: ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("🔴 API Client Error (Config): $e");
      return null;
    }
  }

  /// Envía mensaje al cerebro (Edge Function)
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String sessionId,
    required String botId,
  }) async {
    try {
      // Ahora usamos la URL generada en AppConfig
      final urlString = AppConfig.brainFunctionUrl;
      if (urlString.isEmpty) throw Exception("URL de Brain vacía");

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
        throw Exception('Error del Cerebro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("🔴 API Client Error (Brain): $e");
      return {'reply': 'Error de conexión: $e', 'mood': 'confused'};
    }
  }
}