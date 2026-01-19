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
    final isHovered = ref.watch(isHoveredExternalProvider);

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600; 
    final panelHeight = isMobile ? screenSize.height : (screenSize.height).clamp(400.0, 800.0);

    return Stack(
      fit: StackFit.loose, 
      // CORRECCIÓN CLAVE 1: Alineación CENTRADA.
      // Como el HTML centra el iframe sobre el botón invisible, 
      // nosotros debemos centrar el botón visual en el iframe.
      alignment: Alignment.center,
      
      children: [
        // --- CAPA DE CIERRE ---
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
          Positioned(
            bottom: 0, right: 0,
            left: isMobile ? 0 : null, top: isMobile ? 0 : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: panelHeight, 
                maxWidth: isMobile ? double.infinity : 380
              ),
              child: const ChatPanelView().animate().scale(curve: Curves.easeOutBack, alignment: Alignment.bottomRight, duration: 300.ms).fadeIn(),
            ),
          ),

        // --- BOTÓN FLOTANTE ---
        if (!isOpen)
          // CORRECCIÓN CLAVE 2: Quitamos el Padding.
          // El botón debe flotar libremente en el centro exacto del iframe fantasma.
          botConfigAsync.when(
            loading: () => _buildFloatingButton(isHovered: false, name: "...", color: Colors.grey, subtext: "Cargando...", isDarkMode: true),
            error: (err, stack) => _buildFloatingButton(isHovered: false, name: "OFFLINE", color: Colors.red, subtext: "Error", isDarkMode: true),
            data: (config) => _buildFloatingButton(
              isHovered: isHovered, 
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
    // Dimensiones
    const double closedSize = 72.0; 
    const double headSize = 58.0;   
    const double openWidth = 260.0; 

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    // CORRECCIÓN CLAVE 3: Sombras Minimalistas (Estilo Vercel)
    final List<BoxShadow> shadowList = isDarkMode
        ? [
            // Sombra ambiental muy suave y pegada
            BoxShadow(
              color: Colors.black.withOpacity(0.25), 
              blurRadius: 10, 
              offset: const Offset(0, 4) // Sombra solo hacia abajo
            ),
            // Sutil brillo interior (opcional)
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 0,
              spreadRadius: 1, // Borde muy fino del color del tema
            )
          ]
        : [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic, 
      
      width: isHovered ? openWidth : closedSize, 
      height: closedSize, 
      
      clipBehavior: Clip.antiAlias, 
      
      decoration: BoxDecoration(
        // Gradiente más sólido y menos transparente
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            color, // Color puro arriba
            Color.lerp(color, Colors.black, 0.1)!, // Apenas oscurecido abajo
          ],
        ),
        borderRadius: BorderRadius.circular(closedSize / 2),
        // Borde sutil para definición
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
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
            width: headSize, height: headSize,
            margin: const EdgeInsets.all(7), 
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const ClipOval(child: FloatingHeadWidget()), 
          ),
        ],
      ),
    ).animate().scale(
      // Efecto de escala muy sutil al hover (Latido)
      end: isHovered ? const Offset(1.02, 1.02) : const Offset(1.0, 1.0), 
      duration: 300.ms, curve: Curves.easeOutBack
    );
  }
}