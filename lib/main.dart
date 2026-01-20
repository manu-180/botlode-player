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

    // Inicio de Supabase con configuración segura
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      // Fallo silencioso controlado, la UI mostrará estado offline si es necesario
      print("Supabase Init Error: $e");
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
    print("CRASH: $error");
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
    
    // Configuración visual web
    try {
      html.document.body!.style.backgroundColor = 'transparent';
      html.document.documentElement!.style.backgroundColor = 'transparent';
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
    // Listener de mensajes (Iframe <-> HTML Padre)
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
          // Formato esperado: "MOUSE_MOVE:mouseX,mouseY,screenWidth,screenHeight"
          final content = data.split(':')[1];
          final parts = content.split(',');
          
          if (parts.length >= 2) {
            double mouseX = double.parse(parts[0]);
            double mouseY = double.parse(parts[1]);

            // Si el HTML nos manda el tamaño de pantalla, podemos calcular la posición relativa
            // Asumimos que el bot está abajo a la derecha.
            if (parts.length == 4) {
               // Lógica opcional de normalización si fuera necesaria
               // Por ahora, pasamos las coordenadas crudas, RiveAvatar se encarga
            }

            // Actualizamos el provider que mueve los ojos
            // NOTA: Restamos un offset para centrar la "mirada" en el widget
            ref.read(pointerPositionProvider.notifier).state = Offset(mouseX, mouseY);
            
            // Si el mouse se mueve, asumimos que estamos en "hover" activo
            ref.read(isHoveredExternalProvider.notifier).state = true;
            
            // Debounce para quitar el hover si deja de moverse (opcional)
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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