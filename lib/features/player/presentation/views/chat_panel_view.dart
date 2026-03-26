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
  late final ValueNotifier<int> _focusInputTriggerNotifier;
  bool _wasOffline = false;
  bool _isInputFocused = false; // ⬅️ NUEVO: Detectar foco del input para ocultar Rive en móvil

  @override
  void initState() {
    _focusInputTriggerNotifier = ValueNotifier(0);
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
        // Error silenciado
      }
    });
  }

  @override
  void dispose() {
    // El PresenceManager se limpia automáticamente via su provider.onDispose
    WidgetsBinding.instance.removeObserver(this);
    _focusInputTriggerNotifier.dispose();
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
      // Error silenciado
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

  /// Cerrar chat: (Rive EXIT desactivado temporalmente) cierra tras 300ms.
  void _closeChat() {
    ref.read(isClosingChatProvider.notifier).state = true;
    ref.read(hideRiveForSpaceProvider.notifier).state = false;
    ref.read(isHoveredExternalProvider.notifier).state = false;
    ref.read(avatarHoveredProvider.notifier).state = false;
    ref.read(userIsTypingProvider.notifier).state = false;
    // ref.read(riveExitTriggerProvider.notifier).state++;
    // debugPrint('[Rive Hello] riveExitTriggerProvider++ (click X cerrar chat)');
    try {
      ref.read(presenceManagerProvider).setOffline();
    } catch (e) {
      // Error silenciado
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (ref.read(isClosingChatProvider)) {
        ref.read(chatOpenProvider.notifier).set(false);
        ref.read(isClosingChatProvider.notifier).state = false;
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(userIsTypingProvider.notifier).state = false;
    ref.read(moodDecayProvider).cancelDecay();

    FocusManager.instance.primaryFocus?.unfocus();
    
    // ⬅️ CRÍTICO: Marcar este chat como activo INMEDIATAMENTE y de forma SÍNCRONA
    // Esto debe hacerse ANTES de enviar el mensaje para que el chat viejo deje de mostrar "EN LÍNEA"
    final chatState = ref.read(chatControllerProvider);
    final currentSessionId = chatState.sessionId;
    
    // ⬅️ Actualizar activeSessionId SÍNCRONAMENTE (no async)
    ref.read(activeSessionIdProvider.notifier).state = currentSessionId;
    
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    
    // ⬅️ Verificar que el activeSessionId sigue siendo el correcto después de enviar
    // (por si se creó un nuevo chat durante el envío)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stateAfterSend = ref.read(chatControllerProvider);
      final activeSessionId = ref.read(activeSessionIdProvider);
      
      // Si el sessionId cambió durante el envío (nuevo chat creado), actualizar activeSessionId
      if (stateAfterSend.sessionId != activeSessionId) {
        ref.read(activeSessionIdProvider.notifier).state = stateAfterSend.sessionId;
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
    final showOfflineAlert = botConfig?.showOfflineAlert ?? false;
    final isOnline = ref.watch(connectivityProvider);

    // COLORES
    final Color solidBgColor = isDarkMode ? const Color(0xFF181818) : const Color(0xFFF9F9F9); 
    final Color borderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.black12; // ⬅️ Borde general
    // ⬅️ NUEVO: Input con diseño profesional y elegante
    final Color inputFill = isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
    final Color inputBorder = isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade300;
    // ⬅️ Color neutro clásico para el borde enfocado (funciona bien en ambos modos)
    final Color inputBorderFocused = isDarkMode 
        ? Colors.grey.shade600  // Gris medio para dark mode
        : Colors.grey.shade400;  // Gris claro para light mode

    final reversedMessages = chatState.messages.reversed.toList();

    // ⬅️ Padding horizontal responsive + detección de teclado
    final mq = MediaQuery.of(context);
    final double horizontalPadding = isMobile
        ? (20.0 + (mq.padding.left > mq.padding.right ? mq.padding.left : mq.padding.right)).clamp(24.0, 40.0)
        : 20.0;
    
    // ⬅️ Header compacto SOLO cuando el usuario tocó el input o el Rive (hideRiveForSpace).
    // Si el bot responde y enfocamos el input automáticamente, NO ocultamos el Rive.
    // IMPORTANTE: Cuando isLoading, SIEMPRE mostrar Rive para ver la animación de carga.
    final hideRiveForSpace = ref.watch(hideRiveForSpaceProvider);
    final isKeyboardLikely = isMobile &&
        !chatState.isLoading &&
        hideRiveForSpace;
    // ⬅️ 48px compacto: solo status + botones. ~130px completo: avatar (112) + poco padding abajo
    final double headerHeight = isKeyboardLikely ? 48.0 : 130.0;

    // --- ESCUCHA DE APERTURA/CIERRE ---
    ref.listen(chatOpenProvider, (previous, isOpen) {
      try {
        final manager = ref.read(presenceManagerProvider);
        if (isOpen) {
          manager.setOnline();
        } else {
          manager.setOffline();
        }
      } catch (e) {
        // Error silenciado
      }
    });
    // ----------------------------------

    ref.listen(connectivityProvider, (prev, online) {
      if (!showOfflineAlert) return;
      if (!online) {
        if (!_wasOffline) {
          _wasOffline = true;
          html.window.parent?.postMessage('NETWORK_OFFLINE', '*');
        }
      } else {
        if (_wasOffline) {
          _wasOffline = false;
          html.window.parent?.postMessage('NETWORK_ONLINE', '*');
        }
      }
    });

    ref.listen(chatControllerProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) && _scrollController.hasClients) _scrollController.jumpTo(0.0);
      if (prev?.currentMood != next.currentMood) {
        // 'thinking' es el estado de carga interna, no un mood real: ignorarlo para que el
        // avatar mantenga la emoción anterior mientras el bot procesa la respuesta.
        if (next.currentMood != 'thinking') {
          ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
        }
      }
      if (next.isLoading) {
        ref.read(hideRiveForSpaceProvider.notifier).state = false;
      }
    });

    // ⬅️ BLINDAJE INPUT: HTML padre envía CMD_FOCUS_INPUT al abrir el chat; forzar focus en el input
    ref.listen(focusChatInputTriggerProvider, (prev, next) {
      _focusInputTriggerNotifier.value = next;
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
        ),
        child: Material(
          color: Colors.transparent,
          // ⬅️ SIN LISTENER LOCAL: El tracking global lo maneja UltraSimpleBot
          child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: solidBgColor)),
                    Column(
                      children: [
                        // HEADER - Se adapta al teclado:
                        // ⬅️ Teclado visible (48px): barra compacta [Status] ... [🔄] [✖]
                        // ⬅️ Teclado oculto (200px): Rive avatar + status abajo-izq + botones arriba-der
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          height: headerHeight,
                          width: double.infinity,
                          clipBehavior: Clip.hardEdge, // ⬅️ Recortar Rive durante la animación de altura
                          decoration: BoxDecoration(
                             color: solidBgColor,
                             borderRadius: const BorderRadius.only(
                               topLeft: Radius.circular(28),
                               topRight: Radius.circular(28),
                             ),
                             border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                          ),
                          child: isKeyboardLikely
                            // ══════════════════════════════════════════════════════
                            // ⬅️ HEADER COMPACTO: Status izquierda, botones derecha
                            // Sin Rive (sacado del árbol para liberar espacio)
                            // ══════════════════════════════════════════════════════
                            ? Padding(
                                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                child: Row(
                                  children: [
                                    StatusIndicator(
                                      isLoading: chatState.isLoading, 
                                      isOnline: isOnline, 
                                      mood: chatState.currentMood, 
                                      isDarkMode: isDarkMode,
                                      currentSessionId: chatState.sessionId,
                                    ),
                                    const Spacer(),
                                    _HeaderActionsPill(
                                      isDarkMode: isDarkMode,
                                      onReload: () => ref.read(chatResetProvider)(),
                                      onClose: _closeChat,
                                    ),
                                  ],
                                ),
                              )
                            // ══════════════════════════════════════════════════════
                            // ⬅️ HEADER COMPLETO: Avatar izq (más pequeño) + nombre + indicador | botones der
                            // ══════════════════════════════════════════════════════
                            : Padding(
                                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Hover en avatar (Rive): desactivado temporalmente para producción.
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        ref.read(avatarListeningTriggerProvider.notifier).state++;
                                      },
                                      child: const BotAvatarWidget(size: 112),
                                    ),
                                    const SizedBox(width: 0),
                                    // Nombre arriba del indicador
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            botConfig?.name ?? 'Bot',
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          StatusIndicator(
                                            isLoading: chatState.isLoading,
                                            isOnline: isOnline,
                                            mood: chatState.currentMood,
                                            isDarkMode: isDarkMode,
                                            currentSessionId: chatState.sessionId,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: _HeaderActionsPill(
                                        isDarkMode: isDarkMode,
                                        onReload: () => ref.read(chatResetProvider)(),
                                        onClose: _closeChat,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                        
                        // BODY (CHAT) - Tap en el área muestra el Rive si estaba oculto por abrir desde burbuja
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (ref.read(hideRiveForSpaceProvider)) {
                                ref.read(hideRiveForSpaceProvider.notifier).state = false;
                              }
                            },
                            child: Container(
                              color: solidBgColor, 
                              child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                // reverse: true → index 0 se dibuja al final = abajo (donde aparece el próximo mensaje). Indicador ahí.
                                if (chatState.isLoading && index == 0) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20),
                                      child: _ThinkingIndicator(isDarkMode: isDarkMode),
                                    ),
                                  );
                                }
                                final msgIndex = chatState.isLoading ? index - 1 : index;
                                final msg = reversedMessages[msgIndex];
                                return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                              },
                            ),
                            ),
                          ),
                        ),
                        
                        // ⬅️ INPUT AREA REDISEÑADO - Estilo profesional y moderno
                        Container(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 20 + (isMobile ? mq.padding.bottom : 0)),
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
                            focusInputTrigger: _focusInputTriggerNotifier,
                            isLoading: chatState.isLoading,
                            controller: _textController,
                            isOnline: isOnline,
                            isDarkMode: isDarkMode,
                            themeColor: themeColor,
                            inputFill: inputFill,
                            inputBorder: inputBorder,
                            inputBorderFocused: inputBorderFocused,
                            onSend: _sendMessage,
                            onFocusChanged: (focused, isProgrammatic) {
                              if (_isInputFocused != focused) {
                                setState(() => _isInputFocused = focused);
                              }
                              // Bot siempre visible: no ocultar Rive al tocar el input
                            },
                            onInputTapped: () {
                              // No ocultar el bot al tocar el input
                            },
                            onTextChanged: (hasText) {
                              ref.read(userIsTypingProvider.notifier).state = hasText;
                            },
                          ),
                        ),
                      ],
                    ),
                    // ⬅️ Banner interno eliminado: ahora la alerta es global (overlay full-screen).
                  ],
                ),
        ),
    );
  }
}

// ⬅️ INPUT PROFESIONAL - Diseño moderno y elegante
class _ProfessionalInputField extends StatefulWidget {
  /// Cuando cambia (p. ej. CMD_FOCUS_INPUT del HTML padre), fuerza requestFocus en el input.
  final ValueNotifier<int>? focusInputTrigger;
  final TextEditingController controller;
  final bool isOnline;
  final bool isLoading;
  final bool isDarkMode;
  final Color themeColor;
  final Color inputFill;
  final Color inputBorder;
  final Color inputBorderFocused;
  final VoidCallback onSend;
  /// Notifica (focused, isProgrammatic). isProgrammatic true cuando el foco se dio por respuesta del bot.
  final void Function(bool focused, bool isProgrammatic)? onFocusChanged;
  /// Se llama cuando el usuario hace tap en el input (aunque ya esté enfocado), para ocultar el Rive.
  final VoidCallback? onInputTapped;
  /// Se llama cuando el texto del input pasa a tener contenido o a estar vacío (para "está escribiendo").
  final void Function(bool hasText)? onTextChanged;

  const _ProfessionalInputField({
    this.focusInputTrigger,
    required this.controller,
    required this.isOnline,
    required this.isLoading,
    required this.isDarkMode,
    required this.themeColor,
    required this.inputFill,
    required this.inputBorder,
    required this.inputBorderFocused,
    required     this.onSend,
    this.onFocusChanged,
    this.onInputTapped,
    this.onTextChanged,
  });

  @override
  State<_ProfessionalInputField> createState() => _ProfessionalInputFieldState();
}

class _ProfessionalInputFieldState extends State<_ProfessionalInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;
  bool _programmaticFocusRequested = false;

  void _onFocusTriggered() {
    if (mounted && _focusNode.canRequestFocus) {
      final enabled = widget.isOnline && !widget.isLoading;
      if (enabled) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.focusInputTrigger?.addListener(_onFocusTriggered);

    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      setState(() => _isFocused = hasFocus);
      widget.onFocusChanged?.call(hasFocus, _programmaticFocusRequested);
      if (hasFocus) _programmaticFocusRequested = false;
    });
    
    widget.controller.addListener(() {
      final hasText = widget.controller.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
        widget.onTextChanged?.call(hasText);
      }
    });
  }

  @override
  void didUpdateWidget(_ProfessionalInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cuando el bot termina de responder: enfocar input para poder escribir; el padre no ocultará el Rive (programático).
    if (oldWidget.isLoading && !widget.isLoading) {
      _programmaticFocusRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        } else {
          _programmaticFocusRequested = false;
        }
      });
    }
  }

  @override
  void dispose() {
    widget.focusInputTrigger?.removeListener(_onFocusTriggered);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInputEnabled = widget.isOnline && !widget.isLoading; // ⬅️ NUEVO: Bloquear mientras carga
    final borderColor = _isFocused ? widget.inputBorderFocused : widget.inputBorder;
    final inputOpacity = isInputEnabled ? 1.0 : 0.6; // ⬅️ NUEVO: Reducir opacidad cuando está bloqueado
    
    // ⬅️ CRÍTICO: NO envolver con GestureDetector(behavior: HitTestBehavior.opaque)
    // En Flutter web/móvil, el GestureDetector opaque ROBA el tap al TextField,
    // impidiendo que el teclado se abra. El TextField ya maneja su propio focus.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: inputOpacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            color: widget.inputFill,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: widget.isDarkMode 
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ] : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                // 📱 BLINDAJE v3 PRIMER TAP: Listener no participa en gesture arena,
                // captura el pointer a nivel bajo y fuerza foco en el TextField.
                // En iframe, Flutter web a veces no registra el primer tap nativo;
                // esto garantiza que el teclado se abra al primer toque.
                // onPointerUp como fallback: iOS puede consumir pointerDown para
                // dar foco al iframe pero sí entrega pointerUp.
                child: Listener(
                  onPointerDown: (_) {
                    widget.onInputTapped?.call();
                    if (!_focusNode.hasFocus && isInputEnabled) {
                      _focusNode.requestFocus();
                    }
                  },
                  onPointerUp: (_) {
                    widget.onInputTapped?.call();
                    // Segundo intento: iOS Safari en iframes puede consumir
                    // pointerDown pero sí entregar pointerUp al contenido.
                    if (!_focusNode.hasFocus && isInputEnabled) {
                      _focusNode.requestFocus();
                    }
                  },
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
                // ⬅️ Cursor con color neutro (no usa themeColor amarillo)
                cursorColor: widget.isDarkMode ? Colors.white70 : Colors.black87,
                decoration: InputDecoration(
                  hintText: widget.isLoading 
                      ? "Escribe un mensaje..." 
                      : (widget.isOnline ? "Escribe un mensaje..." : "Sin conexión"),
                  hintStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: (!widget.isOnline && !widget.isLoading)
                      ? Icon(
                          Icons.wifi_off_rounded,
                          size: 20,
                          color: widget.isDarkMode
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black.withOpacity(0.4),
                        )
                      : null,
                  border: InputBorder.none,
                  // ⬅️ Asegurar que no haya bordes enfocados del tema global
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  isDense: true,
                ),
              ),
              ), // cierra Listener
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
                    child: Icon(
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

class _ThinkingIndicatorState extends State<_ThinkingIndicator> 
    with SingleTickerProviderStateMixin {
  String _currentMessage = "Procesando...";
  DateTime? _startTime;
  late AnimationController _shimmerController;
  
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
    
    // ⬅️ Animación shimmer (brillo que se mueve en loop)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(); // Repetir infinitamente
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }
  
  void _updateMessage() {
    if (_startTime == null) return;
    
    final elapsed = DateTime.now().difference(_startTime!);
    final seconds = elapsed.inSeconds;
    
    // Cambiar mensaje: "Escribiendo..." después de 2 segundos (1 segundo antes que antes)
    int messageIndex = 0;
    if (seconds >= 9) {
      messageIndex = 3; // "Casi listo..."
    } else if (seconds >= 6) {
      messageIndex = 2; // "Analizando..."
    } else if (seconds >= 2) {
      messageIndex = 1; // "Escribiendo..." (cambia después de 2 segundos en lugar de 3)
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
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (switcherChild, animation) {
            return FadeTransition(
              opacity: animation,
              child: switcherChild,
            );
          },
          child: ShaderMask(
            key: ValueKey(_currentMessage),
            shaderCallback: (bounds) {
              // ⬅️ Crear gradiente que se mueve de izquierda a derecha (efecto shimmer)
              final shimmerPosition = _shimmerController.value * 3.0 - 1.0; // -1.0 a 2.0
              
              // ⬅️ Colores base y brillantes adaptativos
              final baseColor = widget.isDarkMode 
                  ? Colors.white38 
                  : Colors.black38;
              final brightColor = widget.isDarkMode 
                  ? Colors.white 
                  : Colors.black87;
              
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  baseColor,
                  baseColor,
                  brightColor,
                  brightColor,
                  baseColor,
                  baseColor,
                ],
                stops: [
                  0.0,
                  (shimmerPosition - 0.3).clamp(0.0, 1.0),
                  (shimmerPosition - 0.1).clamp(0.0, 1.0),
                  (shimmerPosition + 0.1).clamp(0.0, 1.0),
                  (shimmerPosition + 0.3).clamp(0.0, 1.0),
                  1.0,
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Text(
              _currentMessage,
              style: TextStyle(
                // ⬅️ Color base (será modificado por el shader)
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 11,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pastilla de acciones del header: reload + cerrar. Diseño nivel senior (agrupado, ghost, sutil).
class _HeaderActionsPill extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onReload;
  final VoidCallback onClose;

  const _HeaderActionsPill({
    required this.isDarkMode,
    required this.onReload,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isDarkMode
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);
    final border = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    // Overlay sutil (sin círculo grande): solo un tinte suave al hover/press
    final overlayColor = (isDarkMode ? Colors.white : Colors.black).withOpacity(0.07);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onReload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: iconColor,
            tooltip: 'Nuevo chat',
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashFactory: NoSplash.splashFactory,
              overlayColor: overlayColor,
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: border,
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: iconColor,
            tooltip: 'Cerrar',
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashFactory: NoSplash.splashFactory,
              overlayColor: overlayColor,
            ),
          ),
        ],
      ),
    );
  }
}