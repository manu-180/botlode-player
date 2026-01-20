// Archivo: lib/core/config/app_config.dart

class AppConfig {
  // -----------------------------------------------------------
  // 🔐 CREDENCIALES DE PRODUCCIÓN (HARDCODED)
  // Nota: Asegúrate de que tu repositorio en GitHub esté configurado como PRIVADO.
  // -----------------------------------------------------------
  
  static const String _hardcodedUrl = "https://gfvslxtqmjrelrugrcfp.supabase.co";
  
  static const String _hardcodedKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmdnNseHRxbWpyZWxydWdyY2ZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0MzkwMjUsImV4cCI6MjA4NDAxNTAyNX0.sjGjwMXpdA6ztW4D61NViMnJPiI3fgKtt1vXGwLdZm0";

  // -----------------------------------------------------------

  static String get supabaseUrl {
    return _hardcodedUrl;
  }

  static String get supabaseAnonKey {
    return _hardcodedKey;
  }

  // URL automática para la Edge Function (Brain)
  // Genera: https://gfvslxtqmjrelrugrcfp.supabase.co/functions/v1/chat-brain
  static String get brainFunctionUrl {
    final baseUrl = supabaseUrl;
    if (baseUrl.isEmpty) return '';
    final cleanUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    return '$cleanUrl/functions/v1/chat-brain'; 
  }

  // ID del Bot por defecto (si no viene en la URL)
  static const String fallbackBotId = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"; 
}