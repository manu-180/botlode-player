// Archivo: lib/features/player/presentation/providers/bot_state_provider.dart
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ID del bot (Leído de la URL o Configuración)
final currentBotIdProvider = Provider<String>((ref) {
  return AppConfig.fallbackBotId;
});

// Estado de ánimo (Controlado por la respuesta del Chat)
final botMoodProvider = StateProvider<int>((ref) => 0);

// --- PROVIDER DE CONFIGURACIÓN (REFACTORIZADO) ---
// Ahora delega la lógica de datos al Repositorio.
final botConfigProvider = StreamProvider<BotConfig>((ref) {
  final botId = ref.watch(currentBotIdProvider);
  final repository = ref.read(botRepositoryProvider);
  
  return repository.getBotConfigStream(botId);
});