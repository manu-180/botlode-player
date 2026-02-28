// Archivo: lib/core/config/app_config.dart

class AppConfig {
  // -----------------------------------------------------------
  // 🔐 CREDENCIALES DE PRODUCCIÓN (HARDCODED)
  // -----------------------------------------------------------
  
  static const String _hardcodedUrl = "https://gfvslxtqmjrelrugrcfp.supabase.co";
  
  // Clave pública (Anon Key)
  static const String _hardcodedKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmdnNseHRxbWpyZWxydWdyY2ZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0MzkwMjUsImV4cCI6MjA4NDAxNTAyNX0.sjGjwMXpdA6ztW4D61NViMnJPiI3fgKtt1vXGwLdZm0";

  // -----------------------------------------------------------

  // Nombre exacto del archivo Rive
  static const String riveFileName = "cabezabot.riv";

  static String get supabaseUrl {
    return _hardcodedUrl;
  }

  static String get supabaseAnonKey {
    return _hardcodedKey;
  }

  // URL de la Edge Function (EL CEREBRO)
  static String get brainFunctionUrl {
    final baseUrl = supabaseUrl;
    if (baseUrl.isEmpty) return '';
    final cleanUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    // CORRECCIÓN: Cambiamos 'chat-brain' por el nombre real 'botlode-brain'
    return '$cleanUrl/functions/v1/botlode-brain'; 
  }

  // Bot por defecto cuando no hay ?botId= en la URL (para probar)
  static const String fallbackBotId = "0038971a-da75-4ddc-8663-d52a6b8f2936"; 
}