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
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    return BotConfig(
      name: json['name'] ?? 'Unit 01',
      themeColor: _parseColor(json['tech_color']),
      systemPrompt: json['system_prompt'] ?? '',
      // Mapeo seguro: Si es null o 'dark', es Dark Mode.
      isDarkMode: (json['theme_mode'] ?? 'dark') == 'dark',
      // Mapeo seguro: acepta bool o string "true"/"false". Si falta, default false (cada página puede tener su sistema).
      showOfflineAlert: _parseBool(json['show_offline_alert'], false),
      // ⬅️ Mensaje inicial: si no existe, usar el por defecto
      initialMessage: json['initial_message'] as String?,
      // ⬅️ WhatsApp: habilitar botón flotante
      wpp: _parseBool(json['wpp'], false),
      // ⬅️ Teléfono de WhatsApp (ej: '5491134272488')
      telefono: json['telefono'] as String?,
      // ⬅️ Tamaño de burbujas (rango 60–100px; default 86 si no existe en BD)
      bubbleSize: ((json['bubble_size'] as num?)?.toDouble() ?? 86.0).clamp(60.0, 100.0),
    );
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
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