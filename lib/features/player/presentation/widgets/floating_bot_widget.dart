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
    // DETECCIÓN INTELIGENTE: ¿Estamos comprimidos en el iframe pequeño?
    // Si la altura es menor a 150px, asumimos modo "Burbuja Iframe"
    final isIframeSmall = screenSize.height < 150; 
    
    final isMobile = screenSize.width < 600; 
    final panelHeight = isMobile ? screenSize.height : (screenSize.height - 100).clamp(400.0, 700.0);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent, 
      // El tracking interno sigue funcionando, pero el externo (main.dart) tendrá prioridad
      onHover: (event) {
        // Solo actualizamos si NO estamos en modo iframe pequeño cerrado,
        // porque ahí dependemos del tracking externo del HTML padre.
        if (isOpen) {
             ref.read(pointerPositionProvider.notifier).state = event.position;
        }
      },
      child: Stack(
        fit: StackFit.expand, 
        alignment: Alignment.bottomRight,
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
                  bottom: 20, right: 20,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: panelHeight, maxWidth: 380),
                    child: const ChatPanelView().animate().scale(curve: Curves.easeOutBack, alignment: Alignment.bottomRight).fadeIn(),
                  ),
                ),

          // --- BOTÓN FLOTANTE ---
          if (!isOpen)
            botConfigAsync.when(
              loading: () => _buildLayoutWrapper(
                isIframeSmall, 
                _buildFloatingButton(name: "...", color: Colors.grey, subtext: "Cargando", isDarkMode: true)
              ),
              error: (err, stack) => _buildLayoutWrapper(
                isIframeSmall,
                _buildFloatingButton(name: "OFFLINE", color: Colors.red, subtext: "Error", isDarkMode: true)
              ),
              data: (config) => _buildLayoutWrapper(
                isIframeSmall,
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

  // WRAPPER DE LAYOUT: Soluciona el problema de "Desfazado"
  Widget _buildLayoutWrapper(bool isSmall, Widget child) {
    if (isSmall) {
      // SI ES PEQUEÑO: Centramos el botón en el espacio disponible (el iframe 80x80)
      // Eliminamos padding 'bottom' y 'right'
      return Center(child: child);
    } else {
      // SI ES GRANDE (Modo Chat abierto o Pantalla completa): Posición normal
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
    const double closedSize = 70.0; 
    const double headSize = 56.0;   
    const double openWidth = 260.0; 

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    final List<BoxShadow> shadowList = isDarkMode
        ? [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
          ]
        : [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
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
          padding: const EdgeInsets.all(2), 
          
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.9), 
                Color.lerp(color, Colors.black, 0.2)!, 
              ],
            ),
            borderRadius: BorderRadius.circular(closedSize / 2),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
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
                          padding: const EdgeInsets.only(left: 20, right: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end, 
                            children: [
                              Text(name, textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8, height: 1.1)),
                              const SizedBox(height: 2),
                              Text(subtext, textAlign: TextAlign.right, style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 11)),
                            ],
                          ),
                        )
                      : const SizedBox(), 
                  ), 
                ),
              ),
              Container(
                width: headSize,
                height: headSize,
                margin: const EdgeInsets.only(right: 4), 
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