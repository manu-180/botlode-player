// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'dart:html' as html;
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
    
    // Forzamos modo oscuro por defecto si no hay config
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    // --- COLORES SÓLIDOS DEPURADOS ---
    final Color solidBgColor = isDarkMode 
        ? const Color(0xFF181818)  // Negro Casi Puro (Sólido)
        : const Color(0xFFF9F9F9); // Blanco Casi Puro (Sólido)

    final Color inputFill = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
    final Color borderColor = isDarkMode ? Colors.white24 : Colors.black12;
    
    // DEBUG: Ver qué color se está aplicando
    print("🎨 [DEBUG CHAT] Mode: ${isDarkMode ? 'DARK' : 'LIGHT'} | BG Color: $solidBgColor");

    final reversedMessages = chatState.messages.reversed.toList();

    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: themeColor,
        scaffoldBackgroundColor: Colors.transparent, // El scaffold es transparente, el contenedor NO
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
                clipBehavior: Clip.hardEdge, 
                // AQUÍ ESTÁ LA CLAVE: Decoration sólida
                decoration: BoxDecoration(
                  color: solidBgColor, // <--- ESTO DEBE SER OPACO
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    // HEADER
                    Container(
                      height: 180,
                      width: double.infinity,
                      color: solidBgColor, // Fondo extra por seguridad
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
                                IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(chatResetProvider)()),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(chatOpenProvider.notifier).set(false)),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 10, left: 24,
                            child: StatusIndicator(isLoading: chatState.isLoading, isOnline: isOnline, mood: chatState.currentMood, isDarkMode: isDarkMode),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(height: 1, color: borderColor),
                    
                    // BODY
                    Expanded(
                      child: Container(
                        color: solidBgColor, // Fondo extra por seguridad
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(20),
                          itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (chatState.isLoading && index == 0) {
                              return const Padding(padding: EdgeInsets.all(10), child: Text("Escribiendo...", style: TextStyle(fontSize: 12, color: Colors.grey)));
                            }
                            final msg = reversedMessages[chatState.isLoading ? index - 1 : index];
                            return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                          },
                        ),
                      ),
                    ),
                    
                    // INPUT
                    Container(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                      color: solidBgColor, // Fondo extra por seguridad
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputFill, 
                          borderRadius: BorderRadius.circular(40), 
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                onSubmitted: (_) => isOnline ? _sendMessage() : null,
                                decoration: const InputDecoration(
                                  hintText: "Escribe aquí...",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                            ),
                            IconButton(onPressed: isOnline ? _sendMessage : null, icon: Icon(Icons.send_rounded, color: themeColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}