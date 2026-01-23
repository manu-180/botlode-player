// Archivo: lib/features/player/domain/repositories/bot_repository.dart
import 'package:botlode_player/features/player/domain/models/bot_config.dart';

abstract class BotRepository {
  /// Escucha en tiempo real los cambios de configuración del bot (Color, Prompt, Modo).
  Stream<BotConfig> getBotConfigStream(String botId);
}