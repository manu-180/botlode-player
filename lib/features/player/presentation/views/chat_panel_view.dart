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
    
    // ⬅️ CRÍTICO: Marcar este chat como activo INMEDIATAMENTE y de forma SÍNCRONA
    // Esto debe hacerse ANTES de enviar el mensaje para que el chat viejo deje de mostrar "EN LÍNEA"
    final chatState = ref.read(chatControllerProvider);
    final currentSessionId = chatState.sessionId;
    
    // ⬅️ Actualizar activeSessionId SÍNCRONAMENTE (no async)
    ref.read(activeSessionIdProvider.notifier).state = currentSessionId;
    print("🟡 [ChatPanelView] _sendMessage() - activeSessionId actualizado a: $currentSessionId (este chat es ahora el activo)");
    
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    
    // ⬅️ Verificar que el activeSessionId sigue siendo el correcto después de enviar
    // (por si se creó un nuevo chat durante el envío)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stateAfterSend = ref.read(chatControllerProvider);
      final activeSessionId = ref.read(activeSessionIdProvider);
      
      // Si el sessionId cambió durante el envío (nuevo chat creado), actualizar activeSessionId
      if (stateAfterSend.sessionId != activeSessionId) {
        print("🟡 [ChatPanelView] _sendMessage() - sessionId cambió durante envío: ${stateAfterSend.sessionId} != $activeSessionId");
        ref.read(activeSessionIdProvider.notifier).state = stateAfterSend.sessionId;
        print("🟡 [ChatPanelView] _sendMessage() - activeSessionId actualizado al nuevo: ${stateAfterSend.sessionId}");
      }
    });
    
    // ⬅️ NUEVO: El input se bloqueará automáticamente porque isLoading será true
    // Y se desbloqueará y enfocará automáticamente cuando isLoading vuelva a false
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
    final Color borderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.black12; // ⬅️ Borde general
    // ⬅️ NUEVO: Input con diseño profesional y elegante
    final Color inputFill = isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
    final Color inputBorder = isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade300;
    final Color inputBorderFocused = isDarkMode ? const Color(0xFF4A4A4A) : Colors.grey.shade500;

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
                                child: StatusIndicator(
                                  isLoading: chatState.isLoading, 
                                  isOnline: isOnline, 
                                  mood: chatState.currentMood, 
                                  isDarkMode: isDarkMode,
                                  currentSessionId: chatState.sessionId, // ⬅️ SessionId del chat actual (opcional)
                                  // ⬅️ isChatOpen y activeSessionId ahora se obtienen directamente de los providers en StatusIndicator
                                ),
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

                                  if (index == 0) return Padding(
                                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20), 
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 12, 
                                          height: 12, 
                                          child: CircularProgressIndicator(strokeWidth: 2, color: themeColor)
                                        ), 
                                        const SizedBox(width: 8), 
                                        _ThinkingIndicator(isDarkMode: isDarkMode)
                                      ]
                                    )
                                  );
                                  final msg = reversedMessages[index - 1];
                                  return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                                } 
                                return ChatBubble(message: reversedMessages[index], botThemeColor: themeColor, isDarkMode: isDarkMode);
                              },
                            ),
                          ),
                        ),
                        
                        // ⬅️ INPUT AREA REDISEÑADO - Estilo profesional y moderno
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                          decoration: BoxDecoration(
                            color: solidBgColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: _ProfessionalInputField(
                            isLoading: chatState.isLoading, // ⬅️ NUEVO: Pasar estado de carga
                            controller: _textController,
                            isOnline: isOnline,
                            isDarkMode: isDarkMode,
                            themeColor: themeColor,
                            inputFill: inputFill,
                            inputBorder: inputBorder,
                            inputBorderFocused: inputBorderFocused,
                            onSend: _sendMessage,
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

// ⬅️ INPUT PROFESIONAL - Diseño moderno y elegante
class _ProfessionalInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool isOnline;
  final bool isLoading; // ⬅️ NUEVO: Para bloquear mientras el bot responde
  final bool isDarkMode;
  final Color themeColor;
  final Color inputFill;
  final Color inputBorder;
  final Color inputBorderFocused;
  final VoidCallback onSend;

  const _ProfessionalInputField({
    required this.controller,
    required this.isOnline,
    required this.isLoading,
    required this.isDarkMode,
    required this.themeColor,
    required this.inputFill,
    required this.inputBorder,
    required this.inputBorderFocused,
    required this.onSend,
  });

  @override
  State<_ProfessionalInputField> createState() => _ProfessionalInputFieldState();
}

class _ProfessionalInputFieldState extends State<_ProfessionalInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    
    widget.controller.addListener(() {
      setState(() => _hasText = widget.controller.text.trim().isNotEmpty);
    });
    
    // ⬅️ NUEVO: Enfocar automáticamente cuando el widget se inicializa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isOnline && !widget.isLoading) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(_ProfessionalInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ⬅️ NUEVO: Cuando isLoading cambia de true a false, enfocar automáticamente
    if (oldWidget.isLoading && !widget.isLoading && widget.isOnline) {
      // Pequeño delay para asegurar que la UI se actualizó
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInputEnabled = widget.isOnline && !widget.isLoading; // ⬅️ NUEVO: Bloquear mientras carga
    final borderColor = _isFocused ? widget.inputBorderFocused : widget.inputBorder;
    final inputOpacity = isInputEnabled ? 1.0 : 0.6; // ⬅️ NUEVO: Reducir opacidad cuando está bloqueado
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inputOpacity,
      child: Container(
        decoration: BoxDecoration(
          color: widget.inputFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
          boxShadow: _isFocused ? [
            BoxShadow(
              color: widget.themeColor.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: isInputEnabled, // ⬅️ NUEVO: Bloquear cuando isLoading es true
                readOnly: widget.isLoading, // ⬅️ NUEVO: Bloquear escritura mientras el bot responde
                onSubmitted: (_) => isInputEnabled && _hasText ? widget.onSend() : null,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
                cursorColor: widget.themeColor,
                decoration: InputDecoration(
                  hintText: widget.isLoading 
                      ? "El bot está respondiendo..." 
                      : (widget.isOnline ? "Escribe un mensaje..." : "Sin conexión"),
                  hintStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ⬅️ BOTÓN DE ENVIAR - Estilo minimalista y elegante
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.all(6),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: (isInputEnabled && _hasText)
                    ? LinearGradient(
                        colors: [
                          widget.themeColor,
                          widget.themeColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: (isInputEnabled && _hasText) ? null : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: (isInputEnabled && _hasText) ? [
                  BoxShadow(
                    color: widget.themeColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: (isInputEnabled && _hasText) ? widget.onSend : null,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: (isInputEnabled && _hasText) ? Colors.white : Colors.grey.shade600,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
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

// ⬅️ NUEVO: Widget que muestra mensajes progresivos mientras el bot piensa
class _ThinkingIndicator extends StatefulWidget {
  final bool isDarkMode;
  
  const _ThinkingIndicator({required this.isDarkMode});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> {
  String _currentMessage = "Procesando...";
  DateTime? _startTime;
  
  // Mensajes progresivos con sentido
  final List<String> _messages = [
    "Procesando...",
    "Escribiendo...",
    "Analizando...",
    "Casi listo...",
  ];
  
  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _updateMessage();
  }
  
  void _updateMessage() {
    if (_startTime == null) return;
    
    final elapsed = DateTime.now().difference(_startTime!);
    final seconds = elapsed.inSeconds;
    
    // Cambiar mensaje cada 3 segundos
    int messageIndex = 0;
    if (seconds >= 9) {
      messageIndex = 3; // "Casi listo..."
    } else if (seconds >= 6) {
      messageIndex = 2; // "Analizando..."
    } else if (seconds >= 3) {
      messageIndex = 1; // "Escribiendo..."
    } else {
      messageIndex = 0; // "Procesando..."
    }
    
    if (mounted && _currentMessage != _messages[messageIndex]) {
      setState(() {
        _currentMessage = _messages[messageIndex];
      });
    }
    
    // Continuar actualizando cada segundo
    if (mounted && seconds < 12) {
      Future.delayed(const Duration(seconds: 1), _updateMessage);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Text(
        _currentMessage,
        key: ValueKey(_currentMessage),
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white38 : Colors.black38, 
          fontSize: 11,
        ),
      ),
    );
  }
}