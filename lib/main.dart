// Archivo: lib/main.dart
import 'dart:html' as html; 
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider para el ID del Bot
final currentBotIdProvider = Provider<String>((ref) {
  return AppConfig.fallbackBotId;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Error cargando .env: $e");
  }

  // 2. Lógica de URL
  final uri = Uri.base;
  final urlBotId = uri.queryParameters['bot_id'];
  final finalBotId = urlBotId ?? AppConfig.fallbackBotId;

  print("🤖 BOTSLODE PLAYER INICIALIZADO");
  print("🆔 BOT ID ACTIVO: $finalBotId");

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
    
    // --- TRUCO 1: Transparencia Forzada ---
    // Obligamos al navegador a que el fondo del iframe sea transparente
    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';

    // --- TRUCO 2: El Saludo (Handshake) ---
    // Avisamos al HTML padre: "¡Ya estoy vivo! Mándame órdenes"
    // Usamos Future.delayed para asegurar que Riverpod esté listo
    Future.delayed(const Duration(milliseconds: 500), () {
        print("📤 Enviando CMD_READY al padre...");
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // --- ESCUCHA DE EVENTOS ---
    html.window.onMessage.listen((event) {
      // Importante: Convertir a String para evitar errores de tipo
      final data = event.data.toString();
      
      if (data == 'CMD_OPEN') {
        print("📥 Recibido CMD_OPEN en Flutter");
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        print("📥 Recibido CMD_CLOSE en Flutter");
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
      // Usamos un Builder para asegurar contexto transparente
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: child,
        );
      },
      home: const FloatingBotWidget(),
    );
  }
}