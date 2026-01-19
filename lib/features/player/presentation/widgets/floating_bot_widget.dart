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

    const double ghostPadding = 139.0;

    return Stack(
      fit: StackFit.loose, 
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: panelHeight, 
              maxWidth: isMobile ? double.infinity : 380
            ),
            child: const ChatPanelView()
                .animate()
                // SINCRONIZACIÓN: 400ms para igualar al HTML
                .scale(curve: Curves.easeOutCubic, alignment: Alignment.bottomRight, duration: 400.ms)
                .fadeIn(duration: 200.ms),
          ),

        if (!isOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: ghostPadding, right: ghostPadding),
            child: GestureDetector(
              onTap: () => ref.read(chatOpenProvider.notifier).set(true),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => ref.read(isHoveredExternalProvider.notifier).state = true,
                onExit: (_) => ref.read(isHoveredExternalProvider.notifier).state = false,
                child: botConfigAsync.when(
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
              ),
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
    const double closedSize = 72.0; 
    const double headSize = 58.0;   
    
    // CORRECCIÓN 1: Más ancho para que entren nombres largos
    const double openWidth = 300.0; 

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    final List<BoxShadow> shadowList = isDarkMode
        ? [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 0, spreadRadius: 1)
          ]
        : [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
          ];

    return AnimatedContainer(
      // SINCRONIZACIÓN: 400ms
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic, 
      width: isHovered ? openWidth : closedSize, 
      height: closedSize, 
      clipBehavior: Clip.antiAlias, 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.1)!],
        ),
        borderRadius: BorderRadius.circular(closedSize / 2),
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
                      // CORRECCIÓN 2: Ajuste de padding para que el texto no toque el borde izquierdo
                      padding: const EdgeInsets.only(left: 25, right: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // Alineamos el texto a la derecha (cerca del avatar)
                        crossAxisAlignment: CrossAxisAlignment.end, 
                        children: [
                          Text(name, textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5, height: 1.1)),
                          const SizedBox(height: 2),
                          // Subtítulo con overflow ellipsis por si acaso
                          Text(
                            subtext, 
                            textAlign: TextAlign.right, 
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: subTextColor, fontWeight: FontWeight.w500, fontSize: 10)
                          ),
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
      end: isHovered ? const Offset(1.02, 1.02) : const Offset(1.0, 1.0), 
      duration: 400.ms, curve: Curves.easeOutCubic // Curva más suave
    );
  }
}