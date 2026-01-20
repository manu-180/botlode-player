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

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // --- ZONA DE DEBUGGING (Verificar en Consola F12) ---
    final url = AppConfig.supabaseUrl;
    final key = AppConfig.supabaseAnonKey;
    
    print("🔍 [DEBUG] Intentando iniciar Supabase...");
    print("🔍 [DEBUG] URL Length: ${url.length} (Debería ser > 10)");
    print("🔍 [DEBUG] KEY Length: ${key.length} (Debería ser > 20)");
    
    if (url.isEmpty || key.isEmpty) {
      print("🔥 [FATAL] Las claves siguen vacías. El hardcode falló o es código viejo.");
    } else {
      print("✅ [DEBUG] Claves detectadas. Iniciando...");
    }
    // ----------------------------------------------------

    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      print("🚀 [EXITO] Supabase se inició correctamente.");
    } catch (e) {
      print("🔥 [ERROR REAL] Falló Supabase: $e");
    }

    final uri = Uri.base;
    final urlBotId = uri.queryParameters['bot_id'];
    // Usamos el ID por defecto si no viene en la URL
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;

    print("🤖 [INFO] Bot ID: $finalBotId");

    runApp(
      ProviderScope(
        overrides: [
          currentBotIdProvider.overrideWithValue(finalBotId),
        ],
        child: const BotPlayerApp(),
      ),
    );

  }, (error, stack) {
    print("🔥 CRASH FINAL: $error");
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
    
    // Precarga silenciosa
    try {
      ref.read(riveFileLoaderProvider);       
      ref.read(riveHeadFileLoaderProvider);  
    } catch (_) {}

    // Transparencia
    try {
      html.document.body!.style.backgroundColor = 'transparent';
      html.document.documentElement!.style.backgroundColor = 'transparent';
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();

      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      } 
      else if (data == 'HOVER_ENTER') {
        ref.read(isHoveredExternalProvider.notifier).state = true;
      }
      else if (data == 'HOVER_EXIT') {
        ref.read(isHoveredExternalProvider.notifier).state = false;
      }
      else if (data.startsWith('MOUSE_MOVE:')) {
        try {
          final parts = data.split(':')[1].split(',');
          final double x = double.parse(parts[0]);
          final double y = double.parse(parts[1]);
          ref.read(pointerPositionProvider.notifier).state = Offset(x, y);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) html.window.parent?.postMessage('CMD_CLOSE', '*');
    });

    return MaterialApp(
      title: 'BotLode Player',
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