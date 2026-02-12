// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/config/configure_web.dart';
import 'package:botlode_player/core/router/app_router.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String DEPLOY_VERSION = "PLAYER PROGRESIVO v5.40 - Animación mejorada: deslizamiento suave sin lag";

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
    
    // ⬅️ Precargar Rive de la burbuja (y cuerpo) para que la primera vez que se abra
    // la burbuja o el chat el archivo ya esté en memoria y no se muestre CircularProgressIndicator.
    await container.read(riveHeadFileLoaderProvider.future);
    await container.read(riveFileLoaderProvider.future);
    
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
    
    // 2. Listener de MENSAJES del parent (cuando estamos embebidos en iframe)
    // El padre envía (x,y) en su viewport; convertimos a coordenadas del iframe
    // para que coincidan con widgetCenter (RenderBox) y el RIV siga bien el cursor.
    html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is Map && data['type'] == 'MOUSE_MOVE') {
          final x = (data['x'] as num).toDouble();
          final y = (data['y'] as num).toDouble();
          final iframeX = data['iframeX'] as num?;
          final iframeY = data['iframeY'] as num?;
          if (iframeX != null && iframeY != null) {
            // Coordenadas en el viewport del iframe (mismo sistema que RenderBox)
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
    // 📱 BLINDAJE v2.8: Manejar comandos del HTML padre
    // Acepta CMD_OPEN, CMD_CLOSE y HITZONE_CLICK_BOT (String fallback)
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final data = event.data;
      // Solo procesar Strings (las Maps se procesan en UltraSimpleBot._messageSubscription)
      if (data is! String) return;
      if (data == 'CMD_OPEN') ref.read(chatOpenProvider.notifier).set(true);
      else if (data == 'CMD_CLOSE') ref.read(chatOpenProvider.notifier).set(false);
      else if (data == 'CMD_FOCUS_INPUT') {
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
      // Enviar mensaje inmediatamente sin delay
      // Usar scheduleMicrotask para asegurar que se envíe en el próximo frame
      scheduleMicrotask(() {
        if (!isOpen) _safePostMessage('CMD_CLOSE');
        else _safePostMessage('CMD_OPEN');
      });
    });

    return MaterialApp.router(
      title: 'BotLode Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter, 
    );
  }
}