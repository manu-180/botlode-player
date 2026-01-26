// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'dart:html' as html;
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/core/services/presence_manager_provider.dart';
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

class _ChatPanelViewState extends ConsumerState<ChatPanelView> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Configuración inicial de UI solamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final String moodString = ref.read(chatControllerProvider).currentMood;
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(moodString);
        
        // Si el chat arranca abierto (por deep link o recarga), activamos online
        if (ref.read(chatOpenProvider)) {
          ref.read(presenceManagerProvider).setOnline();
        }
      } catch (e) {
        print("⚠️ Error en initState postFrameCallback: $e");
      }
    });
  }

  @override
  void dispose() {
    // El PresenceManager se limpia automáticamente via su provider.onDispose
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
        ref.read(presenceManagerProvider).setOffline();
      } else if (state == AppLifecycleState.resumed) {
        if (ref.read(chatOpenProvider)) {
          ref.read(presenceManagerProvider).setOnline();
        }
      }
    } catch (e) {
      print("⚠️ Error en lifecycle state change: $e");
    }
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
    final showOfflineAlert = botConfig?.showOfflineAlert ?? true;
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    // COLORES
    final Color solidBgColor = isDarkMode ? const Color(0xFF181818) : const Color(0xFFF9F9F9); 
    final Color inputFill = isDarkMode ? const Color(0xFF252525) : const Color(0xFFFFFFFF); // ⬅️ Input más oscuro
    final Color borderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.black12; // ⬅️ Borde más visible
    final Color sendButtonColor = const Color(0xFF2196F3); // ⬅️ Azul estándar profesional

    final reversedMessages = chatState.messages.reversed.toList();

    // --- ESCUCHA DE APERTURA/CIERRE ---
    ref.listen(chatOpenProvider, (previous, isOpen) {
      try {
        final manager = ref.read(presenceManagerProvider);
        if (isOpen) {
          print("🟢 Chat Abierto -> Enviando ONLINE");
          manager.setOnline();
        } else {
          print("🔴 Chat Cerrado -> Enviando OFFLINE");
          manager.setOffline();
        }
      } catch (e) {
        print("⚠️ Error al acceder a PresenceManager (widget disposed): $e");
      }
    });
    // ----------------------------------

    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (showOfflineAlert) {
          if (!online) {
            if (!_wasOffline) { _wasOffline = true; html.window.parent?.postMessage('NETWORK_OFFLINE', '*'); }
          } else {
            if (_wasOffline) { _wasOffline = false; html.window.parent?.postMessage('NETWORK_ONLINE', '*'); }
          }
        }
      });
    });

    ref.listen(chatControllerProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) && _scrollController.hasClients) _scrollController.jumpTo(0.0);
      if (prev?.currentMood != next.currentMood) ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
    });

    // ❌ ELIMINAR Theme wrapper Y LayoutBuilder (simplificar render)
    // IGUAL QUE LA BURBUJA: Container con decoration + Material transparente
    return Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.hardEdge, 
        decoration: BoxDecoration(
          color: solidBgColor, 
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          // ⬅️ SIN LISTENER LOCAL: El tracking global lo maneja UltraSimpleBot
          child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: solidBgColor)),
                    Column(
                      children: [
                        // HEADER
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                             color: solidBgColor,
                             border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                          ),
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
                                      icon: const Icon(Icons.refresh_rounded), 
                                      onPressed: () => ref.read(chatResetProvider)(),
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                      tooltip: "Reiniciar",
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded), 
                                      onPressed: () {
                                        // Cierre manual explícito
                                        try {
                                          ref.read(presenceManagerProvider).setOffline();
                                        } catch (e) {
                                          print("⚠️ Error al setOffline en close button: $e");
                                        }
                                        ref.read(chatOpenProvider.notifier).set(false);
                                      },
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                      tooltip: "Cerrar",
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 12, left: 24,
                                child: StatusIndicator(isLoading: chatState.isLoading, isOnline: isOnline, mood: chatState.currentMood, isDarkMode: isDarkMode),
                              ),
                            ],
                          ),
                        ),
                        
                        // BODY (CHAT)
                        Expanded(
                          child: Container(
                            color: solidBgColor, 
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (chatState.isLoading) {
                                  if (index == 0) return Padding(padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20), child: Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: themeColor)), const SizedBox(width: 8), Text("Escribiendo...", style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, fontSize: 11))]));
                                  final msg = reversedMessages[index - 1];
                                  return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                                } 
                                return ChatBubble(message: reversedMessages[index], botThemeColor: themeColor, isDarkMode: isDarkMode);
                              },
                            ),
                          ),
                        ),
                        
                        // INPUT AREA MEJORADO
                        Container(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                          decoration: BoxDecoration(
                            color: solidBgColor,
                            // ⬅️ Sombra sutil hacia arriba
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: inputFill, 
                              borderRadius: BorderRadius.circular(28), // ⬅️ Radio más suave
                              border: Border.all(
                                color: borderColor,
                                width: 1.5, // ⬅️ Borde más visible
                              ),
                              // ⬅️ Sombra interna sutil
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 18),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    enabled: isOnline,
                                    onSubmitted: (_) => isOnline ? _sendMessage() : null,
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black, 
                                      fontSize: 15, // ⬅️ Texto un poco más grande
                                      fontWeight: FontWeight.w400,
                                    ),
                                    cursorColor: sendButtonColor, // ⬅️ Cursor azul
                                    decoration: InputDecoration(
                                      hintText: isOnline ? "Escribe un mensaje..." : "Sin conexión",
                                      hintStyle: TextStyle(
                                        color: isDarkMode ? Colors.white38 : Colors.black38, 
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // ⬅️ BOTÓN DE ENVIAR MEJORADO
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 150),
                                  scale: isOnline ? 1.0 : 0.9,
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: isOnline
                                          ? const LinearGradient(
                                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isOnline ? null : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: isOnline ? [
                                        BoxShadow(
                                          color: const Color(0xFF2196F3).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ] : null,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: isOnline ? _sendMessage : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Icon(
                                            Icons.send_rounded, 
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _ConnectivityBanner(isOnline: isOnline),
                  ],
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