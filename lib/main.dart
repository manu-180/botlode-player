// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/config/configure_web.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/ultra_simple_bot.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String DEPLOY_VERSION = "PLAYER v5.42 - APEX PURO: Focus solo por tap directo en input";

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureUrlStrategy();

    _setupIframeListeners();

    // LEEMOS BOT ID (Solo URL, sin memoria local compleja)
    final uri = Uri.base;
    // Soporta tanto 'botId' como 'bot_id' para compatibilidad
    final urlBotId = uri.queryParameters['botId'] ?? uri.queryParameters['bot_id'];
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;
    
    final container = ProviderContainer(
      overrides: [
        currentBotIdProvider.overrideWithValue(finalBotId),
      ],
    );

    // Supabase init en background: no bloquea runApp
    unawaited(
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      ).then((_) {
        container.read(supabaseReadyProvider.notifier).state = true;
      }).catchError((_) {}),
    );
    
    // ⬅️ Configurar tracking global DESPUÉS de tener el container
    _setupGlobalMouseTrackingWithProvider(container);
    
    // Rive se carga en background al primer acceso (burbuja/chat). No bloqueamos el arranque.
    
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const BotPlayerApp(),
      ),
    );

  }, (error, stack) {
    // Error silenciado
  });
}

void _setupIframeListeners() {
  var cmdReadySent = false;
  void sendReady() {
    if (cmdReadySent) return;
    cmdReadySent = true;
    _safePostMessage('CMD_READY');
    try {
      html.window.parent?.postMessage({
        'type': 'DEPLOY_INFO',
        'source': 'botlode_player',
        'version': DEPLOY_VERSION,
      }, '*');
    } catch (e) {}
  }
  html.window.addEventListener('flutter-first-frame', (_) => sendReady());
  Future.delayed(const Duration(milliseconds: 300), sendReady);
}

// Throttle: máximo 60 fps para onMouseMove (reduce CPU)
const _mouseThrottleMs = 16;

// ✅ LISTENER GLOBAL DE MOUSE (JavaScript nativo) + RIVERPOD
void _setupGlobalMouseTrackingWithProvider(ProviderContainer container) {
  try {
    // ⬅️ ESTRATEGIA DUAL: Local + PostMessage (para iframes)
    
    // 1. Listener LOCAL (funciona cuando NO está en iframe o mouse sobre el iframe)
    // Throttled a 60fps para reducir carga de CPU
    var lastMouseUpdate = 0;
    html.document.onMouseMove.listen((event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastMouseUpdate < _mouseThrottleMs) return;
      lastMouseUpdate = now;
      final x = event.client.x.toDouble();
      final y = event.client.y.toDouble();
      container.read(pointerPositionProvider.notifier).state = Offset(x, y);
    });
    
    // ⬅️ NUEVO: Detectar cuando el mouse SALE de la pantalla
    html.document.onMouseLeave.listen((event) {
      container.read(pointerPositionProvider.notifier).state = null;
    });
    
    // 2. Listener de MENSAJES del parent (cuando estamos embebidos en iframe)
    // Throttled a 60fps para reducir CPU igual que onMouseMove local
    var lastPostMessageMouseUpdate = 0;
    html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is Map && data['type'] == 'MOUSE_MOVE') {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastPostMessageMouseUpdate < _mouseThrottleMs) return;
          lastPostMessageMouseUpdate = now;
          final x = (data['x'] as num).toDouble();
          final y = (data['y'] as num).toDouble();
          final iframeX = data['iframeX'] as num?;
          final iframeY = data['iframeY'] as num?;
          if (iframeX != null && iframeY != null) {
            final localX = x - iframeX.toDouble();
            final localY = y - iframeY.toDouble();
            container.read(pointerPositionProvider.notifier).state = Offset(localX, localY);
          } else {
            container.read(pointerPositionProvider.notifier).state = Offset(x, y);
          }
        } else if (data is Map && data['type'] == 'MOUSE_LEAVE') {
          container.read(pointerPositionProvider.notifier).state = null;
        }
      } catch (e) {
        // Ignorar mensajes mal formados
      }
    });
  } catch (e) {
    // Error silenciado
  }
}

void _safePostMessage(String message) {
  try {
    html.window.parent?.postMessage(message, '*');
  } catch (e) {
    // Error silenciado
  }
}

/// Placeholder transparente mientras Supabase se inicializa en background
class _SupabaseLoadingPlaceholder extends StatelessWidget {
  const _SupabaseLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0x00000000));
  }
}

class BotPlayerApp extends ConsumerStatefulWidget {
  const BotPlayerApp({super.key});
  @override
  ConsumerState<BotPlayerApp> createState() => _BotPlayerAppState();
}

class _BotPlayerAppState extends ConsumerState<BotPlayerApp> {
  @override
  void initState() {
    super.initState();
    // 📱 BLINDAJE v2.8: Manejar comandos del HTML padre
    // Acepta CMD_OPEN, CMD_CLOSE y HITZONE_CLICK_BOT (String fallback)
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final data = event.data;
      // Solo procesar Strings (las Maps se procesan en UltraSimpleBot._messageSubscription)
      if (data is! String) return;
      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      }
      else if (data == 'CMD_CLOSE') ref.read(chatOpenProvider.notifier).set(false);
      else if (data == 'CMD_FOCUS_INPUT') {
        // Solo cuando el HTML envía el comando explícitamente
        ref.read(focusChatInputTriggerProvider.notifier).state++;
      } else if (data == 'HITZONE_CLICK_BOT') {
        // ⬅️ Fallback: si UltraSimpleBot no procesó el Map, este String lo abre
        ref.read(chatOpenProvider.notifier).set(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isHoveredExternalProvider, (prev, isHovered) {
      if (isHovered) _safePostMessage('HOVER_ENTER');
      else _safePostMessage('HOVER_EXIT');
    });

    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) _safePostMessage('CMD_CLOSE');
      else _safePostMessage('CMD_OPEN');
    });

    final supabaseReady = ref.watch(supabaseReadyProvider);

    return MaterialApp(
      title: 'BotLode Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: supabaseReady ? const UltraSimpleBot() : const _SupabaseLoadingPlaceholder(),
    );
  }
}