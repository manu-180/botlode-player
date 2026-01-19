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

/// ROBUST CHAT PANEL VIEW - EDICIÓN FINAL (HYBRID RENDERER SAFE)
/// 
/// Implementación diseñada para resistir fallos del motor gráfico en Web.
/// Incluye capas de seguridad visual para garantizar legibilidad incluso
/// si el efecto de desenfoque (BackdropFilter) colapsa en iframes.
class ChatPanelView extends ConsumerStatefulWidget {
  const ChatPanelView({super.key});

  @override
  ConsumerState<ChatPanelView> createState() => _ChatPanelViewState();
}

class _ChatPanelViewState extends ConsumerState<ChatPanelView> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Controlador para animación de entrada suave
  late AnimationController _fadeController;
  late Animation<double> _opacityAnimation;

  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    
    // Configuración de animación (400ms para sensación premium)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _opacityAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );

    _fadeController.forward();

    // Sincronizar estado inicial
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
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
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

    // --- SISTEMA DE DISEÑO ROBUSTO ---
    // Colores de seguridad (Safety Tints) por si el Blur falla
    final Color safetyBgColor = isDarkMode 
        ? const Color(0xFF121212).withOpacity(0.95) // Casi opaco en dark mode para evitar white-screen
        : const Color(0xFFFFFFFF).withOpacity(0.95);

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

    // --- SIDE EFFECTS ---
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
      if (next.messages.length > (prev?.messages.length ?? 0)) {
         if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
      }
      if (prev?.currentMood != next.currentMood) {
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
      }
    });

    // Inyección de Tema Local para garantizar contraste
    final ThemeData localTheme = ThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: themeColor,
      scaffoldBackgroundColor: Colors.transparent,
      useMaterial3: true,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF2D3748)),
      ),
    );

    return Theme(
      data: localTheme,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent, 
        onHover: (event) {
          final width = MediaQuery.of(context).size.width.clamp(0.0, 380.0);
          final double dx = event.localPosition.dx - (width / 2);
          final double dy = event.localPosition.dy - 100.0; 
          ref.read(pointerPositionProvider.notifier).state = Offset(dx, dy);
        },
        // Transición de Entrada (Fade)
        child: FadeTransition(
          opacity: _opacityAnimation,
          // LayoutBuilder: Prevención de colapso de geometría
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                clipBehavior: Clip.none, 
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: panelShadows,
                ),
                
                // ClipRRect: Contención del renderizado
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  
                  // STACK DE 3 CAPAS (El secreto de la estabilidad)
                  child: Stack(
                    fit: StackFit.expand, 
                    children: [
                      // --- CAPA 0: MOTOR DE VIDRIO (BLUR) ---
                      // Si falla el renderizado HTML, esta capa puede volverse invisible o blanca.
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 10.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                        builder: (context, sigma, child) {
                          return BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                            child: Container(color: Colors.transparent), // Contenedor vacío para el filtro
                          );
                        },
                      ),

                      // --- CAPA 1: TINTE DE SEGURIDAD (SAFETY TINT) ---
                      // Esta capa es SÓLIDA (con opacidad). Si el Blur de la Capa 0 falla,
                      // esta capa asegura que haya un fondo oscuro/claro para que el texto se lea.
                      Container(
                        color: safetyBgColor, 
                      ),

                      // --- CAPA 2: CONTENIDO (INTERFAZ) ---
                      // Material Ancestor + RepaintBoundary
                      Material(
                        type: MaterialType.transparency,
                        child: RepaintBoundary(
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
                              
                              Container(height: 1, width: double.infinity, color: borderColor),
                              
                              // BODY
                              Expanded(
                                child: Container(
                                  color: Colors.transparent, 
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
                                      final msg = reversedMessages[index];
                                      return ChatBubble(message: msg, botThemeColor: themeColor, isDarkMode: isDarkMode);
                                    },
                                  ),
                                ),
                              ),
                              
                              // INPUT
                              Container(
                                padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5)],
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