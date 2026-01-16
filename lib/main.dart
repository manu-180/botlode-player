// Archivo: lib/main.dart
import 'dart:html' as html; 
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_bot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart'; // Importación necesaria

final currentBotIdProvider = Provider<String>((ref) {
  return AppConfig.fallbackBotId;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICIALIZACIÓN OBLIGATORIA PARA 0.14.x
  await RiveNative.init();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Error cargando .env: $e");
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
    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';

    Future.delayed(const Duration(milliseconds: 500), () {
        html.window.parent?.postMessage('CMD_READY', '*');
    });
    
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