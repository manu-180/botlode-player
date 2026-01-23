// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/router/app_router.dart'; // IMPORTAR ROUTER
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CONTROL DE VERSIÓN (REBOOT) ---
const String DEPLOY_VERSION = "NEXUS UPDATE v2.0";

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    print("==========================================");
    print("🛑 VERSIÓN DE DESPLIEGUE: $DEPLOY_VERSION");
    print("==========================================");

    // 2. LOG DE CREDENCIALES
    final url = AppConfig.supabaseUrl;
    final key = AppConfig.supabaseAnonKey;

    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      print("🚀 [EXITO] Supabase conectado.");
    } catch (e) {
      print("🔥 [ERROR] Falló Supabase: $e");
    }

    // --- MANEJO DE IFRAME COMMUNICATION ---
    _setupIframeListeners();

    // LEEMOS BOT ID (Para el modo Player por defecto)
    final uri = Uri.base;
    final urlBotId = uri.queryParameters['bot_id'];
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;

    runApp(
      ProviderScope(
        overrides: [
          currentBotIdProvider.overrideWithValue(finalBotId),
          isHoveredExternalProvider.overrideWith((ref) => false),
        ],
        child: const BotPlayerApp(),
      ),
    );

  }, (error, stack) {
    print("🔥 CRASH FATAL ($DEPLOY_VERSION): $error");
  });
}

// Lógica de comunicación extraída para limpieza
void _setupIframeListeners() {
  try {
    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';
  } catch (_) {}

  Future.delayed(const Duration(milliseconds: 500), () {
      _safePostMessage('CMD_READY');
  });
}

void _safePostMessage(String message) {
  try {
    html.window.parent?.postMessage(message, '*');
  } catch (e) {
    print("⚠️ Error enviando postMessage: $e");
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
    // Escucha de mensajes del padre (Solo relevante para Modo Player)
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();

      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      } 
      // ... resto de lógica de mouse se mantiene si es necesaria ...
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listeners globales
    ref.listen(isHoveredExternalProvider, (prev, isHovered) {
      if (isHovered) _safePostMessage('HOVER_ENTER');
      else _safePostMessage('HOVER_EXIT');
    });

    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) _safePostMessage('CMD_CLOSE');
      else _safePostMessage('CMD_OPEN');
    });

    // --- CAMBIO PRINCIPAL: USAR EL ROUTER ---
    return MaterialApp.router(
      title: 'BotLode Player ($DEPLOY_VERSION)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        canvasColor: Colors.transparent, 
        scaffoldBackgroundColor: Colors.transparent,
      ),
      routerConfig: appRouter, // Inyectamos el router aquí
    );
  }
}