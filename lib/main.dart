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
// Eliminamos la dependencia directa de dotenv aquí, AppConfig se encarga
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // [CORRECCIÓN FINAL]
    // Eliminamos 'await dotenv.load(...)' porque en producción el archivo no existe.
    // AppConfig ya tiene la lógica para leer las variables del sistema (--dart-define).

    try {
      // Usamos las variables desde AppConfig (que ya son seguras)
      final sbUrl = AppConfig.supabaseUrl;
      final sbKey = AppConfig.supabaseAnonKey;

      if (sbUrl.isEmpty || sbKey.isEmpty) {
        throw Exception("Variables de Supabase vacías. Revisa la config de Vercel.");
      }

      await Supabase.initialize(
        url: sbUrl,
        anonKey: sbKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      print("🔥 Error crítico iniciando Supabase: $e");
      // Si falla, permitimos que la app arranque para mostrar error en UI si es necesario
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
    print("🔥 CRASH NO CONTROLADO: $error");
    // Pantalla de error visible
    runApp(MaterialApp(home: Scaffold(backgroundColor: Colors.red, body: Center(child: Text("ERROR: $error", style: TextStyle(color: Colors.white))))));
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
      ref.read(riveFileLoaderProvider);       
      ref.read(riveHeadFileLoaderProvider);  
    } catch (_) {}

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