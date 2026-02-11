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
    // Configuración "Skeleton" por defecto (Fallback de seguridad).
    // ⬅️ CAMBIO: showOfflineAlert TRUE por defecto para que funcione aunque falle la carga
    final defaultConfig = BotConfig(
      name: "Cargando...",
      themeColor: const Color(0xFFFFC000),
      systemPrompt: "",
      isDarkMode: true,
      showOfflineAlert: true,
      initialMessage: null,
      wpp: false,
      telefono: null,
    );

    if (botId.isEmpty) {
      return Stream.value(defaultConfig);
    }

    // Realtime: para que el tema (theme_mode) se actualice en tiempo real al cambiar en botslode,
    // la tabla "bots" debe tener habilitado UPDATE en Supabase → Database → Replication.
    try {
      return _supabase
          .from('bots')
          .stream(primaryKey: ['id'])
          .eq('id', botId)
          .asyncMap((List<Map<String, dynamic>> data) async {
            if (kDebugMode) {
              debugPrint('📥 [BotRepo] Stream: ${data.length} item(s)');
            }
            if (data.isEmpty) {
              if (kDebugMode) debugPrint('📥 [BotRepo] Data vacía → defaultConfig (isDarkMode=true)');
              return defaultConfig;
            }
            final row = data.first;
            final rawTheme = row['theme_mode'];
            if (kDebugMode) {
              debugPrint('📥 [BotRepo] Payload keys: ${row.keys.join(", ")} | theme_mode(raw)=$rawTheme');
            }
            // Realtime UPDATE a veces envía solo campos modificados; obtener fila completa para tema y resto de config
            final bool looksPartial = row.length < 5 || !row.containsKey('name');
            if (looksPartial) {
              if (kDebugMode) debugPrint('📥 [BotRepo] Payload parcial → fetching fila completa...');
              try {
                final full = await _supabase
                    .from('bots')
                    .select()
                    .eq('id', botId)
                    .maybeSingle();
                if (full != null) {
                  final config = BotConfig.fromJson(full);
                  if (kDebugMode) {
                    debugPrint('📥 [BotRepo] Fila completa OK → theme_mode=${full['theme_mode']} isDarkMode=${config.isDarkMode}');
                  }
                  return config;
                }
              } catch (e) {
                if (kDebugMode) debugPrint('📥 [BotRepo] Fetch fila completa falló: $e → usando payload parcial');
              }
            }
            final config = BotConfig.fromJson(row);
            if (kDebugMode) {
              debugPrint('📥 [BotRepo] Usando payload directo → theme_mode=$rawTheme isDarkMode=${config.isDarkMode}');
            }
            return config;
          })
          .handleError((error) {
            // Errores de red/WebSocket al estar sin conexión: no loguear como CRITICAL
            final msg = error.toString().toLowerCase();
            final isConnectionError = msg.contains('realtime') ||
                msg.contains('websocket') ||
                msg.contains('channelerror') ||
                msg.contains('1006') ||
                msg.contains('connection');
            if (isConnectionError) {
              if (kDebugMode) {
                debugPrint("🟡 Realtime sin conexión (esperado cuando no hay red): $error");
              }
            } else {
              debugPrint("🔴 CRITICAL: Error en stream de configuración: $error");
            }
            // En caso de error, emitimos la config por defecto para no romper la UI
            return defaultConfig;
          });
    } catch (e) {
      debugPrint("🔴 CRITICAL: Fallo al inicializar stream: $e");
      return Stream.value(defaultConfig);
    }
  }
}