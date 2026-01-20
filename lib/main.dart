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

const String DEPLOY_VERSION = "BURBUJA FIX v1"; 

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    print("==========================================");
    print("🛑 VERSIÓN: $DEPLOY_VERSION");
    print("==========================================");

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      print("🔥 Supabase Error: $e");
    }

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
    print("🔥 CRASH: $error");
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
    
    // Configuración visual
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
      else if (data.startsWith('MOUSE_MOVE:')) {
        try {
          final content = data.split(':')[1];
          final parts = content.split(',');
          
          if (parts.length >= 2) {
            double mouseX = double.parse(parts[0]);
            double mouseY = double.parse(parts[1]);
            
            // 1. Ojos del bot (Global)
            ref.read(pointerPositionProvider.notifier).state = Offset(mouseX, mouseY);
            
            // 2. Detección de Hover (Solo si el mouse está activo fuera del iframe)
            if (parts.length >= 4) {
              double screenW = double.parse(parts[2]);
              double screenH = double.parse(parts[3]);
              
              // ZONA ESTRICTA: 110px desde la esquina (Justo encima del botón)
              bool inBotZone = (mouseX > screenW - 110) && (mouseY > screenH - 110);
              
              final currentHover = ref.read(isHoveredExternalProvider);
              
              // Lógica de entrada y SALIDA
              if (inBotZone && !currentHover) {
                 ref.read(isHoveredExternalProvider.notifier).state = true;
              } else if (!inBotZone && currentHover) {
                 // Si salimos de la zona, desactivamos el hover
                 ref.read(isHoveredExternalProvider.notifier).state = false;
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // SEMÁFORO DE INTERACCIÓN
    // Le decimos al HTML si debe dejar pasar los clicks o no
    ref.listen(isHoveredExternalProvider, (prev, isHovered) {
      if (isHovered) {
        // Entró a la burbuja: HTML, activa el iframe para recibir clicks
        html.window.parent?.postMessage('HOVER_ENTER', '*');
      } else {
        // Salió de la burbuja: HTML, desactiva iframe para que no moleste
        html.window.parent?.postMessage('HOVER_EXIT', '*');
      }
    });

    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) {
         html.window.parent?.postMessage('CMD_CLOSE', '*');
      } else {
         html.window.parent?.postMessage('CMD_OPEN', '*');
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