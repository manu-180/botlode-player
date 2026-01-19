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

/// ChatPanelView
/// 
/// Implementación técnica final para resolver anomalías de renderizado en Web (Pantalla Blanca).
/// Arquitectura basada en 'Layer Decoupling':
/// 1. LayoutBuilder: Garantiza restricciones no nulas.
/// 2. ClipRRect: Obligatorio para contener el BackdropFilter en Skia/HTML.
/// 3. Stack: Separa físicamente la capa de renderizado del Filtro (Fondo) 
///    de la capa de Pintura del Contenido (Texto/UI) para evitar conflictos de opacidad.
class ChatPanelView extends ConsumerStatefulWidget {
  const ChatPanelView({super.key});

  @override
  ConsumerState<ChatPanelView> createState() => _ChatPanelViewState();
}

class _ChatPanelViewState extends ConsumerState<ChatPanelView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Estado local para lógica de reconexión visual
  bool _wasOffline = false;

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
    // Scroll al fondo si es necesario
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  @override
  void initState() {
    super.initState();
    // Sincronizar estado inicial del mood
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String moodString = ref.read(chatControllerProvider).currentMood;
      ref.read(botMoodProvider.notifier).state = _getMoodIndex(moodString);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Configuración del Bot
    final botConfigAsync = ref.watch(botConfigProvider);
    final botConfig = botConfigAsync.asData?.value;

    final themeColor = botConfig?.themeColor ?? const Color(0xFFFFC000);
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final showOfflineAlert = botConfig?.showOfflineAlert ?? true;

    // Estado de Red
    final isOnlineAsync = ref.watch(connectivityProvider);
    final isOnline = isOnlineAsync.asData?.value ?? true;

    // --- SISTEMA DE DISEÑO (Colores y Gradientes) ---
    final Color glassBg = isDarkMode 
        ? const Color(0xFF121212).withOpacity(0.85) 
        : const Color(0xFFFFFFFF).withOpacity(0.90);

    final LinearGradient bgGradient = isDarkMode
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E1E2C).withOpacity(0.9), 
              const Color(0xFF000000).withOpacity(0.95)
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF), 
              Color(0xFFF4F6F8)
            ],
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

    // --- LÓGICA DE EVENTOS (Side Effects) ---
    
    // 1. Comunicación con HTML (Toasts de Red)
    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        if (showOfflineAlert) {
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
        }
      });
    });

    // 2. Control de Scroll y Mood
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

    // --- ESTRUCTURA VISUAL ROBUSTA ---
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent, 
      onHover: (event) {
        // Cálculo de posición relativa para los ojos del bot
        final width = MediaQuery.of(context).size.width.clamp(0.0, 380.0);
        final double dx = event.localPosition.dx - (width / 2);
        final double dy = event.localPosition.dy - 100.0; 
        ref.read(pointerPositionProvider.notifier).state = Offset(dx, dy);
      },
      // [FIX 1] LayoutBuilder: Asegura que el panel tenga dimensiones físicas concretas
      // antes de intentar pintar, evitando el colapso a 0px.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            // Importante: clipBehavior none aquí, delegamos el recorte al ClipRRect hijo
            clipBehavior: Clip.none, 
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: panelShadows,
              // [NOTA TÉCNICA] No asignamos color de fondo aquí para permitir 
              // que el BackdropFilter interno funcione correctamente.
            ),
            
            // [FIX 2] ClipRRect: Mandatorio en Flutter Web para contener efectos de filtro
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              
              // [FIX 3] Stack: Desacoplamiento de Capas (Fondo vs UI)
              child: Stack(
                fit: StackFit.expand, 
                children: [
                  // --- CAPA 0: MOTOR DE VIDRIO (FONDO) ---
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: bgGradient, 
                        ),
                      ),
                    ),
                  ),

                  // --- CAPA 1: MOTOR DE INTERFAZ (CONTENIDO) ---
                  // Esta capa flota SOBRE el filtro, no dentro de él.
                  Column(
                    children: [
                      // SECCIÓN A: HEADER
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
                                  _ControlButton(
                                    icon: Icons.refresh_rounded, 
                                    color: iconColor, 
                                    onTap: () => ref.read(chatResetProvider)(), 
                                    tooltip: "Reiniciar"
                                  ),
                                  const SizedBox(width: 8),
                                  _ControlButton(
                                    icon: Icons.close_rounded, 
                                    color: iconColor, 
                                    onTap: () => ref.read(chatOpenProvider.notifier).set(false), 
                                    tooltip: "Cerrar"
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
                      
                      // Separador
                      Container(height: 1, width: double.infinity, color: borderColor),
                      
                      // SECCIÓN B: CUERPO DEL CHAT (MENSAJES)
                      Expanded(
                        child: Container(
                          // Capa de seguridad para legibilidad en modo claro
                          color: isDarkMode ? Colors.transparent : const Color(0xFFFAFAFA).withOpacity(0.3),
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            physics: const BouncingScrollPhysics(),
                            itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Indicador de escritura
                              if (chatState.isLoading) {
                                if (index == 0) {
                                  return Padding(
                                     padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20),
                                     child: Row(
                                       children: [
                                         SizedBox(
                                           width: 12, height: 12, 
                                           child: CircularProgressIndicator(strokeWidth: 2, color: iconColor.withOpacity(0.5))
                                         ),
                                         const SizedBox(width: 8),
                                         Text("Escribiendo...", style: TextStyle(color: hintColor, fontSize: 11)),
                                       ],
                                     ),
                                   );
                                }
                                final msg = reversedMessages[index - 1];
                                return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                              } 
                              // Mensaje normal
                              final msg = reversedMessages[index];
                              return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                            },
                          ),
                        ),
                      ),
                      
                      // SECCIÓN C: ÁREA DE INPUT
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [
                              isDarkMode ? Colors.transparent : const Color(0xFFFAFAFA).withOpacity(0.0), 
                              isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9)
                            ],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: inputFill, 
                            borderRadius: BorderRadius.circular(40), 
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08), 
                                blurRadius: 15, 
                                offset: const Offset(0, 5)
                              )
                            ]
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
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    filled: true, 
                                    fillColor: Colors.transparent, 
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(40), 
                                      borderSide: BorderSide(color: borderColor, width: 1)
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(40), 
                                      borderSide: BorderSide(color: accentColor.withOpacity(0.4), width: 1.0)
                                    ),
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
            ),
          );
        },
      ),
    );
  }
}

// Widget auxiliar para botones del header
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ControlButton({
    required this.icon, 
    required this.color, 
    required this.onTap, 
    required this.tooltip
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(20), 
        child: Padding(
          padding: const EdgeInsets.all(8.0), 
          child: Icon(icon, color: color, size: 20)
        )
      )
    );
  }
}