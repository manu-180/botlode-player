// Archivo: lib/features/player/domain/models/bot_config.dart
import 'dart:ui';

class BotConfig {
  final String name;
  final Color themeColor;
  final String systemPrompt;
  final bool isDarkMode; 
  final bool showOfflineAlert; 
  final String? initialMessage; // ⬅️ Mensaje inicial del bot
  final bool wpp; // ⬅️ Habilitar botón de WhatsApp
  final String? telefono; // ⬅️ Número de WhatsApp (ej: '5491134272488')
  final double bubbleSize; // ⬅️ Tamaño de burbujas flotantes en píxeles (bot + WhatsApp)
  /// Bot activo en la fábrica (botslode). Si false, el embed debe ocultar burbujas y reservar 0 espacio.
  final bool enabled;

  BotConfig({
    required this.name,
    required this.themeColor,
    required this.systemPrompt,
    required this.isDarkMode,
    required this.showOfflineAlert,
    this.initialMessage,
    required this.wpp,
    this.telefono,
    this.bubbleSize = 86.0, // Default 86px
    this.enabled = true,
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    final rawTheme = json['theme_mode'];
    final isDark = (rawTheme ?? 'dark') == 'dark';
    // ignore: avoid_print
    print('🎨 [BotConfig] theme_mode(raw)=$rawTheme → isDarkMode=$isDark');
    final parsedShowOfflineAlert = _parseBool(json['show_offline_alert'], true);
    return BotConfig(
      name: json['name'] ?? 'Unit 01',
      themeColor: _parseColor(json['tech_color']),
      systemPrompt: json['system_prompt'] ?? '',
      isDarkMode: isDark,
      // Mapeo seguro: acepta bool o string "true"/"false". Si falta o es null, default TRUE.
      // ⬅️ CAMBIO: Default TRUE para que funcione aunque Supabase envíe null
      showOfflineAlert: parsedShowOfflineAlert,
      // ⬅️ Mensaje inicial: si no existe, usar el por defecto
      initialMessage: json['initial_message'] as String?,
      // ⬅️ WhatsApp: habilitar botón flotante
      wpp: _parseBool(json['wpp'], false),
      // ⬅️ Teléfono de WhatsApp (ej: '5491134272488')
      telefono: json['telefono'] as String?,
      // ⬅️ Tamaño de burbujas (rango 70–110px; default 86 si no existe en BD)
      bubbleSize: ((json['bubble_size'] as num?)?.toDouble() ?? 86.0).clamp(70.0, 110.0),
      // ⬅️ Bot activo en la fábrica: solo 'active' muestra burbujas; disabled/maintenance/creditSuspended ocultan
      enabled: _parseStatusEnabled(json['status']),
    );
  }

  static bool _parseStatusEnabled(dynamic status) {
    if (status == null) return true;
    if (status is String) {
      return status.toLowerCase() == 'active';
    }
    return true;
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    print('🔍 [_parseBool] value=$value, tipo=${value.runtimeType}, default=$defaultValue');
    if (value == null) {
      print('🔍 [_parseBool] Valor es NULL, usando default: $defaultValue');
      return defaultValue;
    }
    if (value is bool) {
      print('🔍 [_parseBool] Valor es bool: $value');
      return value;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') {
        print('🔍 [_parseBool] String "true" detectado');
        return true;
      }
      if (lower == 'false' || lower == '0') {
        print('🔍 [_parseBool] String "false" detectado');
        return false;
      }
    }
    print('🔍 [_parseBool] Tipo no reconocido, usando default: $defaultValue');
    return defaultValue;
  }

  static Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFFFFC000);
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFFFFC000);
    }
  }
}