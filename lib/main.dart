// Archivo: lib/main.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/config/app_config.dart';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/config/configure_web.dart';
import 'package:botlode_player/core/router/app_router.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String DEPLOY_VERSION = "PLAYER PURE v1.0";

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureUrlStrategy();

    // 1. SUPABASE
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    } catch (e) {
      print("🔥 Supabase Init Error: $e");
    }

    _setupIframeListeners();

    // LEEMOS BOT ID (Solo URL, sin memoria local compleja)
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

void _setupIframeListeners() {
  try {
    html.document.body!.style.backgroundColor = 'transparent';
    html.document.documentElement!.style.backgroundColor = 'transparent';
  } catch (_) {}

  Future.delayed(const Duration(milliseconds: 500), () {
      _safePostMessage('CMD_READY');
  });
}

void _safePostMessage(String message) {
  try {
    html.window.parent?.postMessage(message, '*');
  } catch (e) {
    print("⚠️ PostMessage Error: $e");
  }
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
    html.window.onMessage.listen((event) {
      if (event.data == null) return;
      final String data = event.data.toString();
      if (data == 'CMD_OPEN') ref.read(chatOpenProvider.notifier).set(true);
      else if (data == 'CMD_CLOSE') ref.read(chatOpenProvider.notifier).set(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isHoveredExternalProvider, (prev, isHovered) {
      if (isHovered) _safePostMessage('HOVER_ENTER');
      else _safePostMessage('HOVER_EXIT');
    });

    ref.listen(chatOpenProvider, (prev, isOpen) {
      if (!isOpen) _safePostMessage('CMD_CLOSE');
      else _safePostMessage('CMD_OPEN');
    });

    return MaterialApp.router(
      title: 'BotLode Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        canvasColor: Colors.transparent, 
        scaffoldBackgroundColor: Colors.transparent,
      ),
      routerConfig: appRouter, 
    );
  }
}