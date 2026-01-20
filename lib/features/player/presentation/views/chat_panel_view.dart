// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'dart:async';
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
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    // --- MODO SÓLIDO DURO (FIX TRANSPARENCIA) ---
    final Color solidBgColor = isDarkMode 
        ? const Color(0xFF101010) // Casi negro total
        : const Color(0xFFFFFFFF); // Blanco total

    final Color inputFill = isDarkMode ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
    final Color borderColor = isDarkMode ? Colors.white24 : Colors.black12;
    final Color sendButtonColor = isDarkMode ? themeColor : Colors.black;

    final reversedMessages = chatState.messages.reversed.toList();

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
                clipBehavior: Clip.hardEdge, 
                decoration: BoxDecoration(
                  color: solidBgColor, // FONDO SÓLIDO
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))
                  ],
                ),
                child: Stack(
                  children: [
                    // CONTENIDO DEL CHAT
                    Column(
                      children: [
                        // HEADER
                        Container(
                          height: 180,
                          width: double.infinity,
                          color: solidBgColor, 
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
                                        icon: const Icon(Icons.refresh), 
                                        onPressed: () => ref.read(chatResetProvider)(),
                                        color: isDarkMode ? Colors.white70 : Colors.black54
                                    ),
                                    IconButton(
                                        icon: const Icon(Icons.close), 
                                        onPressed: () => ref.read(chatOpenProvider.notifier).set(false),
                                        color: isDarkMode ? Colors.white70 : Colors.black54
                                    ),
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
                            color: solidBgColor, 
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
                          color: solidBgColor, 
                          child: Container(
                            decoration: BoxDecoration(
                              color: inputFill, 
                              borderRadius: BorderRadius.circular(40), 
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    enabled: isOnline,
                                    onSubmitted: (_) => isOnline ? _sendMessage() : null,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    decoration: InputDecoration(
                                      hintText: isOnline ? "Escribe aquí..." : "Esperando conexión...",
                                      hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ),
                                IconButton(
                                    onPressed: isOnline ? _sendMessage : null, 
                                    icon: Icon(Icons.send_rounded, color: isOnline ? sendButtonColor : Colors.grey)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // BANNER DE CONECTIVIDAD
                    _ConnectivityBanner(isOnline: isOnline),
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

class _ConnectivityBanner extends StatefulWidget {
  final bool isOnline;
  const _ConnectivityBanner({required this.isOnline});

  @override
  State<_ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<_ConnectivityBanner> {
  bool _showSuccess = false;

  @override
  void didUpdateWidget(covariant _ConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOnline && widget.isOnline) {
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isVisible = !widget.isOnline || _showSuccess;
    final Color bgColor = !widget.isOnline ? Theme.of(context).colorScheme.error : Colors.green;
    final String text = !widget.isOnline ? "Sin conexión a internet" : "Conexión restablecida";
    final IconData icon = !widget.isOnline ? Icons.wifi_off_rounded : Icons.wifi_rounded;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut, 
      top: isVisible ? 20 : -100, 
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                text, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 13,
                  decoration: TextDecoration.none
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}