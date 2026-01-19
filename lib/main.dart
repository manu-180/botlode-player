// Archivo: lib/main.dart
import 'dart:async'; // Para runZonedGuarded
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

void main() {
  // ZONA DE GUARDIA GLOBAL: Captura errores que ocurren fuera de los widgets
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. LOG DE INICIO
    print("🚀 [BOOT] Iniciando BotLode Player...");

    // 2. CARGA DE VARIABLES DE ENTORNO
    try {
      await dotenv.load(fileName: ".env");
      print("✅ [BOOT] .env cargado correctamente.");
    } catch (e) {
      print("⚠️ [BOOT] Advertencia: No se pudo cargar .env (Posible entorno de Producción). Error: $e");
    }

    // 3. INICIALIZACIÓN DE SUPABASE
    try {
      print("🔵 [BOOT] Conectando a Supabase: ${AppConfig.supabaseUrl}");
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      print("✅ [BOOT] Supabase inicializado.");
    } catch (e) {
      print("🔥 [FATAL] Error crítico al iniciar Supabase: $e");
      // Aquí podríamos frenar, pero intentamos seguir para mostrar el error en pantalla
    }

    // 4. CONFIGURACIÓN DE ERRORES VISUALES (PANTALLA ROJA)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print("🔥 [FLUTTER ERROR] ${details.exception}");
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.red.shade900,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                "ERROR DE RENDERIZADO:\n${details.exception}",
                style: const TextStyle(color: Colors.yellow, fontSize: 14, fontFamily: 'Courier'),
              ),
            ),
          ),
        ),
      );
    };

    // 5. OBTENER ID DEL BOT
    final uri = Uri.base;
    final urlBotId = uri.queryParameters['bot_id'];
    final finalBotId = urlBotId ?? AppConfig.fallbackBotId;
    print("🤖 [BOOT] Bot ID detectado: $finalBotId");

    runApp(
      ProviderScope(
        overrides: [
          currentBotIdProvider.overrideWithValue(finalBotId),
        ],
        child: const BotPlayerApp(),
      ),
    );
  }, (error, stack) {
    print("🔥 [ASYNC ERROR] Error no controlado: $error");
    print(stack);
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
    print("🎬 [UI] BotPlayerApp initState ejecutado.");
    
    // Precarga de assets
    try {
      ref.read(riveFileLoaderProvider);       
      ref.read(riveHeadFileLoaderProvider);  
      print("✅ [UI] Loaders de Rive activados.");
    } catch (e) {
      print("⚠️ [UI] Error al activar loaders: $e");
    }

    // TRUCO WEB: Forzar transparencia en el DOM real
    try {
      html.document.body!.style.backgroundColor = 'transparent';
      html.document.documentElement!.style.backgroundColor = 'transparent';
    } catch (e) {
      print("⚠️ [UI] No se pudo acceder al DOM (¿No estás en web?): $e");
    }

    Future.delayed(const Duration(milliseconds: 500), () {
        print("📡 [MSG] Enviando CMD_READY al padre.");
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // LISTENERS DE MENSAJES (HTML -> FLUTTER)
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();
      // print("📩 [MSG RECIBIDO] $data"); // Descomentar si hay mucho ruido

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
          // Ignorar error de parseo mouse
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
      debugShowCheckedModeBanner: false, // Quitamos la etiqueta DEBUG para ver limpio
      theme: AppTheme.darkTheme.copyWith(
        // EXTREMA TRANSPARENCIA
        canvasColor: Colors.transparent, 
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) {
        // Envolvemos en un ErrorBoundary global
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Container(
            color: Colors.red,
            child: Text(
              "CRASH: ${errorDetails.exception}",
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textDirection: TextDirection.ltr,
            ),
          );
        };
        return Scaffold(
          backgroundColor: Colors.transparent, 
          body: child,
        );
      },
      home: const FloatingBotWidget(),
    );
  }
}