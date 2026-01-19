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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- MAIN ROBUSTO (DIAGNÓSTICO) ---
void main() {
  // VECTOR 4: Captura de errores globales con runZonedGuarded
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. CARGA DE ENTORNO (.ENV) CON FALLBACK
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print("⚠️ Advertencia: No se pudo cargar .env. Usando variables de entorno del sistema.");
    }

    // 2. INICIALIZACIÓN DE SUPABASE (VECTOR 2 - SAFE MODE)
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        // VECTOR 2 FIX: Deshabilitar persistencia para evitar bloqueo de cookies en Iframe
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      print("🔥 Error crítico iniciando Supabase: $e");
      // No detenemos la app, dejamos que cargue para mostrar el error en UI si es necesario
    }

    final uri = Uri.base;
    final urlBotId = uri.queryParameters['bot_id'];
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;

    runApp(
      ProviderScope(
        overrides: [
          currentBotIdProvider.overrideWithValue(finalBotId),
        ],
        child: const BotPlayerApp(),
      ),
    );

  }, (error, stack) {
    // PANTALLA ROJA DE LA MUERTE (CONTROLADA)
    print("🔥 CRASH NO CONTROLADO: $error");
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "ERROR CRÍTICO DEL SISTEMA:\n$error",
                style: const TextStyle(color: Colors.white, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
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
    
    // Precarga de assets
    try {
      ref.read(riveFileLoaderProvider);       
      ref.read(riveHeadFileLoaderProvider);  
    } catch (e) {
      print("⚠️ Error precargando Rive: $e");
    }

    // TRUCO WEB: Forzar transparencia
    try {
      html.document.body!.style.backgroundColor = 'transparent';
      html.document.documentElement!.style.backgroundColor = 'transparent';
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // LISTENERS DE MENSAJES (HTML -> FLUTTER)
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
        } catch (e) {
          // Ignorar error
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos si Flutter decide cerrar el chat
    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) { 
        html.window.parent?.postMessage('CMD_CLOSE', '*');
      }
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