// Archivo: lib/features/player/presentation/providers/bot_state_provider.dart
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Cliente Oficial

// ID del bot
final currentBotIdProvider = Provider<String>((ref) {
  return AppConfig.fallbackBotId;
});

// Estado de ánimo
final botMoodProvider = StateProvider<int>((ref) => 0);

// --- PROVIDER DE CONFIGURACIÓN EN TIEMPO REAL ---
// Usamos StreamProvider para que la UI se reconstruya cada vez que la DB cambie
final botConfigProvider = StreamProvider<BotConfig>((ref) {
  final botId = ref.watch(currentBotIdProvider);
  
  // Configuración "Skeleton" por defecto
  final defaultConfig = BotConfig(
    name: "Cargando...",
    themeColor: const Color(0xFFFFC000), 
    systemPrompt: "",
    isDarkMode: true,       
    showOfflineAlert: true, 
  );

  if (botId.isEmpty) {
    // Si no hay ID, emitimos el default constante
    return Stream.value(defaultConfig);
  }

  // --- MAGIA DE REALTIME ---
  // Escuchamos cambios en la tabla 'bots' donde el ID coincida.
  return Supabase.instance.client
      .from('bots')
      .stream(primaryKey: ['id']) // Importante: Definir la PK para que el stream funcione
      .eq('id', botId)
      .map((List<Map<String, dynamic>> data) {
        // El stream devuelve una lista de filas.
        if (data.isEmpty) {
          return defaultConfig;
        }
        // Convertimos la primera fila (nuestro bot) en el objeto BotConfig
        return BotConfig.fromJson(data.first);
      });
});