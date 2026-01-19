// Archivo: lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ESTRATEGIA HÍBRIDA:
  // 1. Primero busca variables "Horneadas" (--dart-define) -> Para Producción
  // 2. Si no están, busca en el archivo .env -> Para Desarrollo Local

  static String get supabaseUrl {
    // Intento 1: Producción
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // Intento 2: Desarrollo Local
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    // Intento 1: Producción
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;

    // Intento 2: Desarrollo Local
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  static const String fallbackBotId = "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"; 
}