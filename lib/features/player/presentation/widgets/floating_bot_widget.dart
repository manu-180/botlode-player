// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'package:botlode_player/features/player/domain/models/bot_config.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/floating_head_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingBotWidget extends ConsumerStatefulWidget {
  const FloatingBotWidget({super.key});

  @override
  ConsumerState<FloatingBotWidget> createState() => _FloatingBotWidgetState();
}

class _FloatingBotWidgetState extends ConsumerState<FloatingBotWidget> {
  bool _isHovered = false;

  Color _getContrastingTextColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(chatOpenProvider);
    final botConfigAsync = ref.watch(botConfigProvider);

    final screenSize = MediaQuery.of(context).size;
    
    // DETECCIÓN INTELIGENTE:
    // Si la altura es pequeña (iframe cerrado o hover), usamos layout centrado.
    final isIframeCompact = screenSize.height < 200; 
    
    final isMobile = screenSize.width < 600; 
    // Altura máxima del panel dentro del iframe
    final panelHeight = isMobile ? screenSize.height : (screenSize.height).clamp(400.0, 800.0);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent, 
      onHover: (event) {
        if (isOpen) {
             ref.read(pointerPositionProvider.notifier).state = event.position;
        }
      },
      child: Stack(
        fit: StackFit.expand, 
        // Si está compacto, alineamos al centro derecha para permitir expansión a la izquierda
        alignment: isIframeCompact ? Alignment.centerRight : Alignment.bottomRight,
        children: [
          
          if (isOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent, 
                onTap: () => ref.read(chatOpenProvider.notifier).set(false),
                child: const SizedBox.expand(), 
              ),
            ),

          if (isOpen)
            isMobile 
              ? Positioned.fill(child: const ChatPanelView().animate().fadeIn())
              : Positioned(
                  bottom: 0, right: 0, // Pegado a los bordes del iframe expandido
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: panelHeight, maxWidth: 380),
                    child: const ChatPanelView().animate().scale(curve: Curves.easeOutBack, alignment: Alignment.bottomRight).fadeIn(),
                  ),
                ),

          // --- BOTÓN FLOTANTE ---
          if (!isOpen)
            botConfigAsync.when(
              loading: () => _buildLayoutWrapper(
                isIframeCompact, 
                _buildFloatingButton(name: "...", color: Colors.grey, subtext: "Cargando", isDarkMode: true)
              ),
              error: (err, stack) => _buildLayoutWrapper(
                isIframeCompact,
                _buildFloatingButton(name: "OFFLINE", color: Colors.red, subtext: "Error", isDarkMode: true)
              ),
              data: (config) => _buildLayoutWrapper(
                isIframeCompact,
                _buildFloatingButton(
                  name: config.name.toUpperCase(), 
                  color: config.themeColor,
                  subtext: "¿En qué te ayudo?",
                  isDarkMode: config.isDarkMode,
                )
              ),
            ),
        ],
      ),
    );
  }

  // WRAPPER DE LAYOUT
  Widget _buildLayoutWrapper(bool isCompact, Widget child) {
    if (isCompact) {
      // MODO BURBUJA: Padding derecho para que no se pegue al borde del iframe
      return Padding(
        padding: const EdgeInsets.only(right: 10.0), 
        child: child
      );
    } else {
      // MODO ABIERTO (Transición): Posición normal
      return Positioned(
        bottom: 25, 
        right: 25,
        child: child,
      );
    }
  }

  Widget _buildFloatingButton({
    required String name, 
    required Color color, 
    required String subtext,
    required bool isDarkMode,
  }) {
    // --- DIMENSIONES AJUSTADAS (MÁS COMPACTO) ---
    const double closedSize = 64.0; // Reducido de 70 a 64 para dar aire
    const double headSize = 58.0;   // Aumentado proporción para llenar el círculo
    const double openWidth = 260.0; 

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    final List<BoxShadow> shadowList = isDarkMode
        ? [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 15, spreadRadius: 1, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
          ]
        : [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
          ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(chatOpenProvider.notifier).set(true);
          setState(() => _isHovered = false); 
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic, 
          
          width: _isHovered ? openWidth : closedSize, 
          height: closedSize, 
          
          clipBehavior: Clip.antiAlias, 
          // ELIMINADO EL PADDING INTERNO QUE CAUSABA EL ESPACIO RARO
          // padding: const EdgeInsets.all(2), 
          
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.95), // Más sólido
                Color.lerp(color, Colors.black, 0.15)!, 
              ],
            ),
            borderRadius: BorderRadius.circular(closedSize / 2),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
            boxShadow: shadowList, 
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: _isHovered 
                      ? Padding(
                          padding: const EdgeInsets.only(left: 20, right: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end, 
                            children: [
                              Text(name, textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5, height: 1.1)),
                              const SizedBox(height: 2),
                              Text(subtext, textAlign: TextAlign.right, style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 10)),
                            ],
                          ),
                        )
                      : const SizedBox(), 
                  ), 
                ),
              ),
              
              // CABEZA ROBOT
              // Eliminado margen derecho excesivo para que quede bien centrado en modo cerrado
              Container(
                width: headSize,
                height: headSize,
                margin: const EdgeInsets.all(3), // Pequeño margen uniforme
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const ClipOval(child: FloatingHeadWidget()), 
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}