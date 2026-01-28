// Archivo: lib/features/player/data/repositories/bot_repository_impl.dart
import 'dart:ui';
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:botlode_player/features/player/domain/repositories/bot_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BotRepositoryImpl implements BotRepository {
  final SupabaseClient _supabase;

  BotRepositoryImpl(this._supabase);

  @override
  Stream<BotConfig> getBotConfigStream(String botId) {
    // Configuración "Skeleton" por defecto (Fallback de seguridad)
    final defaultConfig = BotConfig(
      name: "Cargando...",
      themeColor: const Color(0xFFFFC000),
      systemPrompt: "",
      isDarkMode: true,
      showOfflineAlert: true,
      initialMessage: null,
    );

    if (botId.isEmpty) {
      return Stream.value(defaultConfig);
    }

    try {
      return _supabase
          .from('bots')
          .stream(primaryKey: ['id'])
          .eq('id', botId)
          .map((List<Map<String, dynamic>> data) {
            if (data.isEmpty) return defaultConfig;
            return BotConfig.fromJson(data.first);
          })
          .handleError((error) {
            debugPrint("🔴 CRITICAL: Error en stream de configuración: $error");
            // En caso de error, emitimos la config por defecto para no romper la UI
            return defaultConfig; 
          });
    } catch (e) {
      debugPrint("🔴 CRITICAL: Fallo al inicializar stream: $e");
      return Stream.value(defaultConfig);
    }
  }
}