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
              debugPrint('🔍 [BotRepository] Stream data recibido: ${data.length} items');
            }
            if (data.isEmpty) {
              if (kDebugMode) debugPrint('🔍 [BotRepository] Data vacía, usando defaultConfig');
              return defaultConfig;
            }
            final row = data.first;
            // Realtime UPDATE a veces envía solo campos modificados; obtener fila completa para tema y resto de config
            final bool looksPartial = row.length < 5 || !row.containsKey('name');
            if (looksPartial) {
              try {
                final full = await _supabase
                    .from('bots')
                    .select()
                    .eq('id', botId)
                    .maybeSingle();
                if (full != null) {
                  if (kDebugMode) debugPrint('🔍 [BotRepository] Fila completa tras UPDATE (theme_mode en tiempo real)');
                  return BotConfig.fromJson(full);
                }
              } catch (_) {
                // Si falla el select, usar payload parcial (theme_mode puede estar presente)
              }
            }
            return BotConfig.fromJson(row);
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