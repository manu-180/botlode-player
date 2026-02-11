// Archivo: lib/features/player/data/repositories/bot_repository_impl.dart
import 'dart:async';
import 'dart:ui';
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:botlode_player/features/player/domain/repositories/bot_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Intervalo de refresco periódico cuando Realtime no emite (fallback para tema light/dark).
const Duration _kConfigRefreshInterval = Duration(seconds: 25);

class BotRepositoryImpl implements BotRepository {
  final SupabaseClient _supabase;

  BotRepositoryImpl(this._supabase);

  BotConfig _defaultConfig() => BotConfig(
        name: "Cargando...",
        themeColor: const Color(0xFFFFC000),
        systemPrompt: "",
        isDarkMode: true,
        showOfflineAlert: true,
        initialMessage: null,
        wpp: false,
        telefono: null,
      );

  /// Fetch único de la fila del bot (para emisión inicial, refresco periódico y payload parcial).
  /// Si Supabase devuelve vacío (p. ej. por RLS) o error, se retorna defaultConfig y se loguea.
  Future<BotConfig> _fetchBotConfig(String botId, {bool isInitial = false}) async {
    final defaultConfig = _defaultConfig();
    try {
      final row = await _supabase
          .from('bots')
          .select()
          .eq('id', botId)
          .maybeSingle();
      if (row == null) {
        debugPrint(
          '⚠️ [BotRepo] SUPABASE NO DEVOLVIÓ DATOS (fila vacía). '
          'Usando DEFAULTS: isDarkMode=true, showOfflineAlert=true. '
          '¿RLS bloqueando? El player usa anon key; necesita política SELECT pública en tabla bots.',
        );
        return defaultConfig;
      }
      final config = BotConfig.fromJson(row);
      if (kDebugMode) {
        final label = isInitial ? 'Fetch inicial' : 'Refresh periódico';
        debugPrint('✅ [BotRepo] $label → theme_mode=${row['theme_mode']} isDarkMode=${config.isDarkMode} showOfflineAlert=${config.showOfflineAlert}');
      }
      return config;
    } catch (e) {
      debugPrint(
        '⚠️ [BotRepo] ERROR al leer Supabase: $e. '
        'Usando DEFAULTS (tema dark, notificaciones activas). Revisar RLS o red.',
      );
      return defaultConfig;
    }
  }

  @override
  Stream<BotConfig> getBotConfigStream(String botId) {
    final defaultConfig = _defaultConfig();
    if (botId.isEmpty) {
      return Stream.value(defaultConfig);
    }

    // Stream 1: Realtime (Supabase emite en INSERT/UPDATE si está habilitado).
    // Realtime: tabla "bots" debe tener UPDATE en Supabase → Database → Replication.
    Stream<BotConfig> realtimeStream;
    try {
      realtimeStream = _supabase
          .from('bots')
          .stream(primaryKey: ['id'])
          .eq('id', botId)
          .asyncMap((List<Map<String, dynamic>> data) async {
            if (kDebugMode) debugPrint('📥 [BotRepo] Realtime: ${data.length} item(s)');
            if (data.isEmpty) {
              debugPrint(
                '⚠️ [BotRepo] Realtime devolvió 0 filas. Usando DEFAULTS. '
                '¿RLS? El anon necesita poder hacer SELECT en bots.',
              );
              return defaultConfig;
            }
            final row = data.first;
            final rawTheme = row['theme_mode'];
            if (kDebugMode) {
              debugPrint('📥 [BotRepo] Payload keys: ${row.keys.join(", ")} | theme_mode(raw)=$rawTheme');
            }
            final bool looksPartial = row.length < 5 || !row.containsKey('name');
            if (looksPartial) {
              if (kDebugMode) debugPrint('📥 [BotRepo] Payload parcial → fetching fila completa...');
              try {
                final full = await _supabase.from('bots').select().eq('id', botId).maybeSingle();
                if (full != null) {
                  final config = BotConfig.fromJson(full);
                  if (kDebugMode) {
                    debugPrint('📥 [BotRepo] Fila completa OK → theme_mode=${full['theme_mode']} isDarkMode=${config.isDarkMode}');
                  }
                  return config;
                }
              } catch (e) {
                if (kDebugMode) debugPrint('📥 [BotRepo] Fetch fila completa falló: $e');
              }
            }
            return BotConfig.fromJson(row);
          })
          .handleError((error) {
            final msg = error.toString().toLowerCase();
            final isConnectionError = msg.contains('realtime') ||
                msg.contains('websocket') ||
                msg.contains('channelerror') ||
                msg.contains('1006') ||
                msg.contains('connection');
            if (isConnectionError && kDebugMode) {
              debugPrint("🟡 Realtime sin conexión: $error");
            } else {
              debugPrint("🔴 Error en stream de configuración: $error");
            }
          });
    } catch (e) {
      debugPrint("🔴 Fallo al crear stream Realtime: $e");
      realtimeStream = Stream.value(defaultConfig);
    }

    // Stream 2: Refresco periódico (fallback si Realtime no emite en UPDATE).
    final refreshStream = Stream.periodic(_kConfigRefreshInterval)
        .asyncMap((_) => _fetchBotConfig(botId, isInitial: false));

    // Emisión inicial inmediata (aquí se verá si Supabase devuelve datos o no).
    final initialStream = Stream.fromFuture(_fetchBotConfig(botId, isInitial: true));

    if (kDebugMode) {
      debugPrint('📥 [BotRepo] getBotConfigStream: Realtime + refresh cada ${_kConfigRefreshInterval.inSeconds}s');
    }

    // Combinar: inicial + Realtime + periódico (dart:async no tiene Stream.merge).
    late StreamSubscription<BotConfig> sub1, sub2, sub3;
    final controller = StreamController<BotConfig>.broadcast();
    controller.onListen = () {
      sub1 = initialStream.listen(
        controller.add,
        onError: controller.addError,
        cancelOnError: false,
      );
      sub2 = realtimeStream.listen(
        controller.add,
        onError: controller.addError,
        cancelOnError: false,
      );
      sub3 = refreshStream.listen(
        controller.add,
        onError: controller.addError,
        cancelOnError: false,
      );
    };
    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    };
    return controller.stream;
  }
}