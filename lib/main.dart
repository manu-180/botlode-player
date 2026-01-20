// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CONTROL DE VERSIÓN ---
const String DEPLOY_VERSION = "INTENTO 1"; 

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. LOG DE VERSIÓN (Para confirmar que se actualizó en Vercel)
    print("==========================================");
    print("🛑 VERSIÓN DE DESPLIEGUE: $DEPLOY_VERSION");
    print("==========================================");

    // 2. LOG DE CREDENCIALES
    final url = AppConfig.supabaseUrl;
    final key = AppConfig.supabaseAnonKey;
    print("🔍 [DEBUG] URL Length: ${url.length}");
    print("🔍 [DEBUG] KEY Length: ${key.length}");

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

    final uri = Uri.base;
    final urlBotId = uri.queryParameters['bot_id'];
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;
    print("🤖 [INFO] Bot ID detectado: $finalBotId");

    runApp(
      ProviderScope(
        overrides: [
          currentBotIdProvider.overrideWithValue(finalBotId),
        ],
        child: const BotPlayerApp(),
      ),
    );

  }, (error, stack) {
    print("🔥 CRASH FATAL ($DEPLOY_VERSION): $error");
  });
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
    
    // Forzar transparencia en el HTML (contenedor padre)
    try {
      html.document.body!.style.backgroundColor = 'transparent';
      html.document.documentElement!.style.backgroundColor = 'transparent';
      print("🎨 [DEBUG] Fondo HTML forzado a transparente.");
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();
      if (data == 'CMD_OPEN') ref.read(chatOpenProvider.notifier).set(true);
      if (data == 'CMD_CLOSE') ref.read(chatOpenProvider.notifier).set(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) html.window.parent?.postMessage('CMD_CLOSE', '*');
    });

    return MaterialApp(
      title: 'BotLode Player ($DEPLOY_VERSION)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        canvasColor: Colors.transparent, 
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) => Scaffold(
        backgroundColor: Colors.transparent, 
        body: child,
      ),
      home: const FloatingBotWidget(),
    );
  }
}