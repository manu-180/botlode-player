// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'dart:html' as html; // Necesario para hablar con el HTML
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

class _ChatPanelViewState extends ConsumerState<ChatPanelView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String moodString = ref.read(chatControllerProvider).currentMood;
      final int moodInt = _getMoodIndex(moodString); 
      ref.read(botMoodProvider.notifier).state = moodInt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Configuración
    final botConfigAsync = ref.watch(botConfigProvider);
    final botConfig = botConfigAsync.asData?.value;

    final themeColor = botConfig?.themeColor ?? const Color(0xFFFFC000);
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final showOfflineAlert = botConfig?.showOfflineAlert ?? true; // Respetamos la config

    final isOnlineAsync = ref.watch(connectivityProvider);
    final isOnline = isOnlineAsync.asData?.value ?? true;

    // Colores
    final Color glassBg = isDarkMode 
        ? const Color(0xFF121212).withOpacity(0.85) 
        : const Color(0xFFFFFFFF).withOpacity(0.90);

    final LinearGradient bgGradient = isDarkMode
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1E1E2C).withOpacity(0.9), const Color(0xFF000000).withOpacity(0.95)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F6F8)],
          );

    final Color inputFill = isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
    final Color inputText = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final Color hintColor = isDarkMode ? Colors.white38 : Colors.black38;
    final Color borderColor = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final Color iconColor = isDarkMode ? Colors.white60 : const Color(0xFF4A5568);
    final Color accentColor = isDarkMode ? themeColor : const Color(0xFF1A1A1A);

    final List<BoxShadow> panelShadows = isDarkMode 
        ? [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, offset: const Offset(0, 20))]
        : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))];

    final reversedMessages = chatState.messages.reversed.toList();

    // --- PUENTE DE COMUNICACIÓN DE RED ---
    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (showOfflineAlert) {
          if (!online) {
            // SE FUE INTERNET: Avisar al HTML para que muestre el banner global
            html.window.parent?.postMessage('NETWORK_OFFLINE', '*');
          } else if (prev?.value == false && online) {
            // VOLVIÓ INTERNET: Avisar al HTML para quitar el banner
            html.window.parent?.postMessage('NETWORK_ONLINE', '*');
          }
        }
      });
    });

    ref.listen(chatControllerProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
         if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
         }
      }
      if (prev?.currentMood != next.currentMood) {
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
      }
    });

    return Container(
      width: isMobile ? double.infinity : null,
      height: isMobile ? double.infinity : null,
      clipBehavior: Clip.hardEdge, 
      decoration: BoxDecoration(
        gradient: bgGradient, 
        borderRadius: isMobile ? null : BorderRadius.circular(28),
        border: isMobile ? null : Border.all(color: borderColor, width: 1.5),
        boxShadow: panelShadows,
      ),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: glassBg),
          ),
          Column(
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
                          _ControlButton(icon: Icons.refresh_rounded, color: iconColor, onTap: () => ref.read(chatResetProvider)(), tooltip: "Reiniciar"),
                          const SizedBox(width: 8),
                          _ControlButton(icon: Icons.close_rounded, color: iconColor, onTap: () => ref.read(chatOpenProvider.notifier).set(false), tooltip: "Cerrar"),
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

              Container(height: 1, width: double.infinity, color: borderColor),

              // CHAT BODY
              Expanded(
                child: Container(
                  color: isDarkMode ? Colors.transparent : const Color(0xFFFAFAFA).withOpacity(0.5),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chatState.isLoading) {
                        if (index == 0) {
                          return Padding(
                             padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20),
                             child: Row(
                               children: [
                                 SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: iconColor.withOpacity(0.5))),
                                 const SizedBox(width: 8),
                                 Text("Escribiendo...", style: TextStyle(color: hintColor, fontSize: 11)),
                               ],
                             ),
                           );
                        }
                        final msg = reversedMessages[index - 1];
                        return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                      } 
                      final msg = reversedMessages[index];
                      return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                    },
                  ),
                ),
              ),

              // INPUT FLOTANTE
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [isDarkMode ? Colors.transparent : const Color(0xFFFAFAFA).withOpacity(0.0), isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08), blurRadius: 15, offset: const Offset(0, 5))]),
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
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            filled: true, fillColor: Colors.transparent, 
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: borderColor, width: 1)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: accentColor.withOpacity(0.4), width: 1.0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isOnline ? 1.0 : 0.5,
                        child: IconButton(
                          onPressed: isOnline ? _sendMessage : null, 
                          icon: Icon(Icons.send_rounded, color: accentColor, size: 28),
                          tooltip: "Enviar", 
                          splashRadius: 24
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ControlButton({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, color: color, size: 20))));
  }
}