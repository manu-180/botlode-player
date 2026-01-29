// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/config/configure_web.dart';
import 'package:botlode_player/core/router/app_router.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String DEPLOY_VERSION = "PLAYER PROGRESIVO v5.26 - StatusIndicator usa hasEverBeenOnline (sin cartel en refresh offline)";

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureUrlStrategy();

    // ✅ NUEVO: Configurar esquema de color para evitar fondos opacos forzados
    _setupColorScheme();

    // 1. SUPABASE
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      // Error silenciado
    }

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
    
    // ⬅️ Configurar tracking global DESPUÉS de tener el container
    _setupGlobalMouseTrackingWithProvider(container);
    
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
  // Removida configuración de transparencia para que el chat tenga fondo sólido
  
  Future.delayed(const Duration(milliseconds: 500), () {
      _safePostMessage('CMD_READY');
      try {
        html.window.parent?.postMessage({
          'type': 'DEPLOY_INFO',
          'source': 'botlode_player',
          'version': DEPLOY_VERSION,
        }, '*');
      } catch (e) {
        // Error silenciado
      }
  });
}

// ✅ LISTENER GLOBAL DE MOUSE (JavaScript nativo) + RIVERPOD
void _setupGlobalMouseTrackingWithProvider(ProviderContainer container) {
  try {
    // ⬅️ ESTRATEGIA DUAL: Local + PostMessage (para iframes)
    
    // 1. Listener LOCAL (funciona cuando NO está en iframe o mouse sobre el iframe)
    html.document.onMouseMove.listen((event) {
      final x = event.client.x.toDouble();
      final y = event.client.y.toDouble();
      container.read(pointerPositionProvider.notifier).state = Offset(x, y);
    });
    
    // ⬅️ NUEVO: Detectar cuando el mouse SALE de la pantalla
    html.document.onMouseLeave.listen((event) {
      container.read(pointerPositionProvider.notifier).state = null;
    });
    
    // 2. Listener de MENSAJES del parent (funciona cuando el mouse está FUERA del iframe)
    html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is Map && data['type'] == 'MOUSE_MOVE') {
          final x = (data['x'] as num).toDouble();
          final y = (data['y'] as num).toDouble();
          container.read(pointerPositionProvider.notifier).state = Offset(x, y);
        } else if (data is Map && data['type'] == 'MOUSE_LEAVE') {
          // ⬅️ NUEVO: El HTML padre nos avisa que el mouse salió completamente
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

// ✅ NUEVO: Función para configurar esquema de color
void _setupColorScheme() {
  try {
    // Verificar si el meta tag de color-scheme existe
    var metaColorScheme = html.document.querySelector('meta[name="color-scheme"]');
    if (metaColorScheme == null) {
      // Crear y agregar el meta tag dinámicamente
      metaColorScheme = html.MetaElement()
        ..name = 'color-scheme'
        ..content = 'light dark';
      html.document.head?.append(metaColorScheme);
    }
  } catch (e) {
    // Error silenciado
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
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();
      if (data == 'CMD_OPEN') ref.read(chatOpenProvider.notifier).set(true);
      else if (data == 'CMD_CLOSE') ref.read(chatOpenProvider.notifier).set(false);
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

    return MaterialApp.router(
      title: 'BotLode Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter, 
    );
  }
}