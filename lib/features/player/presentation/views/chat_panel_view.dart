// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'dart:html' as html;
import 'dart:ui';
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/chat_bubble.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatPanelView extends ConsumerStatefulWidget {
  const ChatPanelView({super.key});

  @override
  ConsumerState<ChatPanelView> createState() => _ChatPanelViewState();
}

class _ChatPanelViewState extends ConsumerState<ChatPanelView> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _opacityAnimation;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String moodString = ref.read(chatControllerProvider).currentMood;
      ref.read(botMoodProvider.notifier).state = _getMoodIndex(moodString);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _getMoodIndex(String mood) {
    switch (mood.toLowerCase()) {
      case 'angry': return 1;
      case 'happy': return 2;
      case 'sales': return 3;
      case 'confused': return 4;
      case 'tech': return 5;
      case 'neutral': default: return 0;
    }
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
    ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final themeColor = botConfig?.themeColor ?? const Color(0xFFFFC000);
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    // --- MODO SÓLIDO (VISIBILIDAD TOTAL) ---
    final Color solidBgColor = isDarkMode 
        ? const Color(0xFF1E1E1E)  // Negro Sólido
        : const Color(0xFFFFFFFF); // Blanco Sólido

    final Color inputFill = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final Color inputText = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final Color hintColor = isDarkMode ? Colors.white38 : Colors.black38;
    final Color borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    final Color iconColor = isDarkMode ? Colors.white70 : const Color(0xFF4A5568);
    final Color accentColor = isDarkMode ? themeColor : const Color(0xFF1A1A1A);

    final reversedMessages = chatState.messages.reversed.toList();

    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (!online && !_wasOffline) { _wasOffline = true; html.window.parent?.postMessage('NETWORK_OFFLINE', '*'); }
        if (online && _wasOffline) { _wasOffline = false; html.window.parent?.postMessage('NETWORK_ONLINE', '*'); }
      });
    });

    ref.listen(chatControllerProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
         if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
      }
      if (prev?.currentMood != next.currentMood) {
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
      }
    });

    // Inyección de Tema para asegurar contraste de texto
    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: themeColor,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent, 
        onHover: (event) {
          final width = MediaQuery.of(context).size.width.clamp(0.0, 380.0);
          ref.read(pointerPositionProvider.notifier).state = Offset(event.localPosition.dx - (width/2), event.localPosition.dy - 100);
        },
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                clipBehavior: Clip.none, 
                decoration: BoxDecoration(
                  color: solidBgColor, // <--- EL FIX ESTÁ AQUÍ (Fondo Opaco)
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    children: [
                      // HEADER
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: BotAvatarWidget(), 
                              ),
                            ),
                            Positioned(
                              top: 16, right: 16,
                              child: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: iconColor),
                                    onPressed: () => ref.read(chatResetProvider)(),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: iconColor),
                                    onPressed: () => ref.read(chatOpenProvider.notifier).set(false),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 10, left: 24,
                              child: StatusIndicator(
                                isLoading: chatState.isLoading, 
                                isOnline: isOnline, 
                                mood: chatState.currentMood,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Container(height: 1, color: borderColor),
                      
                      // BODY
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(20),
                          itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (chatState.isLoading) {
                              if (index == 0) return const Padding(padding: EdgeInsets.all(10), child: Text("Escribiendo...", style: TextStyle(fontSize: 12, color: Colors.grey)));
                              return ChatBubble(message: reversedMessages[index - 1], botThemeColor: themeColor, isDarkMode: isDarkMode);
                            } 
                            return ChatBubble(message: reversedMessages[index], botThemeColor: themeColor, isDarkMode: isDarkMode);
                          },
                        ),
                      ),
                      
                      // INPUT
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                        color: solidBgColor, // Fondo sólido también en el input
                        child: Container(
                          decoration: BoxDecoration(
                            color: inputFill, 
                            borderRadius: BorderRadius.circular(40), 
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  style: TextStyle(color: inputText, fontSize: 14),
                                  enabled: isOnline,
                                  onSubmitted: (_) => isOnline ? _sendMessage() : null,
                                  cursorColor: accentColor, 
                                  decoration: InputDecoration(
                                    hintText: isOnline ? "Escribe aquí..." : "Sin conexión",
                                    hintStyle: TextStyle(color: hintColor, fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: isOnline ? _sendMessage : null, 
                                icon: Icon(Icons.send_rounded, color: accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}