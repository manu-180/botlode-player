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
  
  Color _getContrastingTextColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(chatOpenProvider);
    final botConfigAsync = ref.watch(botConfigProvider);
    
    // --- ESTADO SINCRONIZADO CON HTML ---
    // Ya no usamos un estado local setState(), usamos el provider global
    final isHovered = ref.watch(isHoveredExternalProvider);

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600; 
    final panelHeight = isMobile ? screenSize.height : (screenSize.height).clamp(400.0, 800.0);

    return Stack(
      fit: StackFit.expand, 
      // CENTRADO ABSOLUTO: Esencial para la arquitectura de Iframe Fantasma.
      // El HTML centra el iframe sobre el proxy, así que nosotros centramos el botón en el iframe.
      alignment: Alignment.center,
      children: [
        
        // --- CAPA DE CIERRE (Solo activa si está abierto) ---
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, 
              onTap: () => ref.read(chatOpenProvider.notifier).set(false),
              child: const SizedBox.expand(), 
            ),
          ),

        // --- PANEL DE CHAT ---
        if (isOpen)
          isMobile 
            ? Positioned.fill(child: const ChatPanelView().animate().fadeIn())
            : Positioned(
                bottom: 0, right: 0, 
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelHeight, maxWidth: 380),
                  child: const ChatPanelView().animate().scale(curve: Curves.easeOutBack, alignment: Alignment.bottomRight).fadeIn(),
                ),
              ),

        // --- BOTÓN FLOTANTE (VISUALIZACIÓN PURA) ---
        // Nota: Ya no tiene MouseRegion ni GestureDetector propios para Hover.
        // Solo reacciona visualmente a 'isHovered' y al click que manda el HTML.
        if (!isOpen)
          botConfigAsync.when(
            loading: () => _buildFloatingButton(
              isHovered: false,
              name: "...", color: Colors.grey, subtext: "Cargando", isDarkMode: true
            ),
            error: (err, stack) => _buildFloatingButton(
              isHovered: false,
              name: "OFFLINE", color: Colors.red, subtext: "Error", isDarkMode: true
            ),
            data: (config) => _buildFloatingButton(
              isHovered: isHovered, // ESTADO QUE VIENE DEL HTML
              name: config.name.toUpperCase(), 
              color: config.themeColor,
              subtext: "¿En qué te ayudo?",
              isDarkMode: config.isDarkMode,
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required bool isHovered,
    required String name, 
    required Color color, 
    required String subtext,
    required bool isDarkMode,
  }) {
    // --- DIMENSIONES ---
    const double closedSize = 64.0; 
    const double headSize = 58.0;   
    const double openWidth = 260.0; 

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    final List<BoxShadow> shadowList = isDarkMode
        ? [
            // SOMBRA INTENSA (Ahora no se cortará porque el iframe es gigante)
            BoxShadow(
              color: color.withOpacity(isHovered ? 0.8 : 0.5), // Brilla más al hover
              blurRadius: isHovered ? 25 : 15, 
              spreadRadius: isHovered ? 2 : 1, 
              offset: const Offset(0, 4)
            ),
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
          ]
        : [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
          ];

    // ANIMACIÓN VISUAL PURA
    // Ya no necesita lógica de toque aquí, porque el HTML manda la orden de 'CMD_OPEN'
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic, 
      
      width: isHovered ? openWidth : closedSize, 
      height: closedSize, 
      
      clipBehavior: Clip.antiAlias, 
      
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.95), 
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
              opacity: isHovered ? 1.0 : 0.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: isHovered 
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
          
          Container(
            width: headSize,
            height: headSize,
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const ClipOval(child: FloatingHeadWidget()), 
          ),
        ],
      ),
    ).animate().scale(
      // Efecto sutil de latido al hacer hover
      end: isHovered ? const Offset(1.05, 1.05) : const Offset(1.0, 1.0), 
      duration: 300.ms, 
      curve: Curves.easeOutBack
    );
  }
}