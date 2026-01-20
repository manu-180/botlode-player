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
const String DEPLOY_VERSION = "INTENTO 9 (Solid Black Fix)"; 

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    print("==========================================");
    print("🛑 VERSIÓN DE DESPLIEGUE: $DEPLOY_VERSION");
    print("==========================================");

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
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

class BotPlayerApp extends ConsumerStatefulWidget {
  const BotPlayerApp({super.key});
  @override
  ConsumerState<BotPlayerApp> createState() => _BotPlayerAppState();
}

class _BotPlayerAppState extends ConsumerState<BotPlayerApp> {
  @override
  void initState() {
    super.initState();
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
          
          if (parts.length >= 4) {
            double mouseX = double.parse(parts[0]);
            double mouseY = double.parse(parts[1]);
            double screenW = double.parse(parts[2]);
            double screenH = double.parse(parts[3]);

            double botCenterX = screenW - 111.0; 
            double botCenterY = screenH - 111.0;

            double deltaX = mouseX - botCenterX; 
            double deltaY = mouseY - botCenterY;

            ref.read(pointerPositionProvider.notifier).state = Offset(deltaX, deltaY);
            
            bool inBotZone = (mouseX > screenW - 130) && (mouseY > screenH - 130);
            final currentHover = ref.read(isHoveredExternalProvider);
            if (inBotZone && !currentHover) {
               ref.read(isHoveredExternalProvider.notifier).state = true;
            } else if (!inBotZone && currentHover) {
               ref.read(isHoveredExternalProvider.notifier).state = false;
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isHoveredExternalProvider, (prev, isHovered) {
      if (isHovered) {
        html.window.parent?.postMessage('HOVER_ENTER', '*');
      } else {
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