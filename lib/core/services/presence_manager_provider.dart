// Archivo: lib/core/services/presence_manager_provider.dart
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/services/presence_manager.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider que crea y gestiona el PresenceManager
/// 
/// Este provider inyecta el SupabaseClient desde el provider centralizado
/// y obtiene los datos necesarios (sessionId, botId) de los providers de estado.
final presenceManagerProvider = Provider.autoDispose<PresenceManager>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final botId = ref.watch(currentBotIdProvider);
  final chatState = ref.read(chatControllerProvider);

  final manager = PresenceManager(
    client,
    sessionId: chatState.sessionId,
    botId: botId,
  );
  
  // Cleanup cuando el provider se dispose
  ref.onDispose(() {
    print("🧹 PresenceManager disposed, enviando OFFLINE");
    manager.setOffline();
  });

  return manager;
});
