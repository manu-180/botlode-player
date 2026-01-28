// Archivo: lib/features/player/domain/models/bot_config.dart
import 'dart:ui';

class BotConfig {
  final String name;
  final Color themeColor;
  final String systemPrompt;
  final bool isDarkMode; 
  final bool showOfflineAlert; 
  final String? initialMessage; // ⬅️ Mensaje inicial del bot

  BotConfig({
    required this.name,
    required this.themeColor,
    required this.systemPrompt,
    required this.isDarkMode,
    required this.showOfflineAlert,
    this.initialMessage,
  });

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    return BotConfig(
      name: json['name'] ?? 'Unit 01',
      themeColor: _parseColor(json['tech_color']),
      systemPrompt: json['system_prompt'] ?? '',
      // Mapeo seguro: Si es null o 'dark', es Dark Mode.
      isDarkMode: (json['theme_mode'] ?? 'dark') == 'dark',
      // Mapeo seguro: Si es null, muestra alerta por defecto.
      showOfflineAlert: json['show_offline_alert'] ?? true,
      // ⬅️ Mensaje inicial: si no existe, usar el por defecto
      initialMessage: json['initial_message'] as String?,
    );
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