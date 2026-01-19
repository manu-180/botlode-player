// Archivo: lib/main.dart
import 'dart:html' as html; 
import 'dart:ui'; // Necesario para Offset
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Error cargando .env: $e");
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

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
    
    ref.read(riveFileLoaderProvider);      
    ref.read(riveHeadFileLoaderProvider);  

    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // --- ESCUCHA DE COMANDOS EXTERNOS (JS -> DART) ---
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();

      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      } 
      // NUEVO: Protocolo de Seguimiento de Mouse Remoto
      else if (data.startsWith('MOUSE_MOVE:')) {
        try {
          // Formato esperado: "MOUSE_MOVE:500,300" (x,y relativos a la ventana)
          final parts = data.split(':')[1].split(',');
          final double x = double.parse(parts[0]);
          final double y = double.parse(parts[1]);
          
          // Inyectamos la posición en el sistema de Flutter como si fuera nativa
          // Pero necesitamos ajustar las coordenadas porque el iframe tiene su propio offset
          // TRUCO: Pasamos coordenadas absolutas de pantalla para que el cálculo sea global
          ref.read(pointerPositionProvider.notifier).state = Offset(x, y);
        } catch (e) {
          // Ignorar errores de parseo
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BotLode Player',
      debugShowCheckedModeBanner: false,
      
      // TEMA GLOBAL TRANSPARENTE
      theme: AppTheme.darkTheme.copyWith(
        canvasColor: Colors.transparent, // Importante
        scaffoldBackgroundColor: Colors.transparent, // Importante
      ),
      
      // BUILDER PARA FORZAR TRANSPARENCIA EN CAPAS SUPERIORES
      builder: (context, child) => Scaffold(
        backgroundColor: Colors.transparent, // Fondo base nulo
        body: child,
      ),
      home: const FloatingBotWidget(),
    );
  }
}