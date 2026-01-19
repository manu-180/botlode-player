// Archivo: lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  // [NUEVO] URL para la Edge Function
  // Construye automáticamente: https://tu-proyecto.supabase.co/functions/v1/chat-brain
  static String get brainFunctionUrl {
    final baseUrl = supabaseUrl;
    if (baseUrl.isEmpty) return '';
    // Aseguramos que no haya doble slash o falte slash
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanUrl/functions/v1/chat-brain'; 
  }

  static const String fallbackBotId = "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"; 
}