// Archivo: lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Leemos las variables del archivo .env cargado
  // Usamos '??' para evitar crash si falta la variable, pero idealmente debería estar.
  
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // La URL de la función se construye dinámicamente
  static String get brainFunctionUrl => '$supabaseUrl/functions/v1/botlode-brain';
  
  static String get fallbackBotId => dotenv.env['DEFAULT_BOT_ID'] ?? '';
}