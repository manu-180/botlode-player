// Archivo: lib/main.dart
import 'dart:html' as html; 
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart'; 
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';    
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// IMPORTANTE: Paquete oficial para Realtime
import 'package:supabase_flutter/supabase_flutter.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carga de variables de entorno
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Error cargando .env: $e");
  }

  // 2. INICIALIZACIÓN DE SUPABASE (Realtime)
  // Esto conecta el socket para escuchar cambios
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // 3. Obtención de ID desde URL
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
    
    // Pre-carga de assets Rive
    ref.read(riveFileLoaderProvider);      
    ref.read(riveHeadFileLoaderProvider);  

    // Configuración para fondo transparente en Web
    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';

    // Notificar al padre (iframe) que estamos listos
    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // Escuchar comandos externos (JS)
    html.window.onMessage.listen((event) {
      final data = event.data.toString();
      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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