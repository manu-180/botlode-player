// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'package:botlode_player/features/player/domain/models/bot_config.dart'; // Importar modelo
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

  @override
  void initState() {
    super.initState();
    html.window.onMessage.listen((event) {
      final data = event.data;
      if (data == 'CMD_OPEN') {
        ref.read(chatOpenProvider.notifier).set(true);
      } else if (data == 'CMD_CLOSE') {
        ref.read(chatOpenProvider.notifier).set(false);
      }
    });
  }

  // FUNCIÓN MATEMÁTICA PARA EL COLOR DEL TEXTO
  // Devuelve Negro si el fondo es claro, Blanco si el fondo es oscuro.
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
    final isMobile = screenSize.width < 600; 
    final panelHeight = isMobile ? screenSize.height : (screenSize.height - 100).clamp(400.0, 700.0);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent, 
      onHover: (event) {
        ref.read(pointerPositionProvider.notifier).state = event.position;
      },
      onExit: (event) {
        ref.read(pointerPositionProvider.notifier).state = null;
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
              loading: () => _buildFloatingButton(
                name: "...", 
                color: Colors.grey, 
                subtext: "Cargando",
                isDarkMode: true, // Default
              ),
              error: (err, stack) => _buildFloatingButton(
                name: "OFFLINE", 
                color: Colors.red, 
                subtext: "Error",
                isDarkMode: true,
              ),
              data: (config) => _buildFloatingButton(
                name: config.name.toUpperCase(), 
                color: config.themeColor,
                subtext: "¿En qué te ayudo?",
                isDarkMode: config.isDarkMode, // Pasamos el modo de la DB
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required String name, 
    required Color color, 
    required String subtext,
    required bool isDarkMode,
  }) {
    // Dimensiones
    const double closedSize = 70.0; 
    const double headSize = 56.0;   
    const double openWidth = 260.0; // Un poco más ancho para nombres largos

    // LÓGICA DE COLOR INTELIGENTE
    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85); // Un poco más suave

    // LÓGICA DE SOMBRA SEGÚN TEMA
    // Dark Mode = Glow del color del bot (Cyberpunk)
    // Light Mode = Sombra negra suave (Material Design)
    final List<BoxShadow> shadowList = isDarkMode
        ? [
            BoxShadow(
              color: color.withOpacity(0.6), // Glow intenso
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), // Sombra física
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ];

    return Positioned(
      bottom: 25, right: 25,
      child: MouseRegion(
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
              // FONDO: Degradado sutil para dar volumen 3D
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.9), // Color puro
                  Color.lerp(color, Colors.black, 0.2)!, // Un poco más oscuro abajo a la derecha
                ],
              ),
              borderRadius: BorderRadius.circular(closedSize / 2),
              
              // Borde sutil brillante para destacar sobre fondos oscuros
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5
              ),
              boxShadow: shadowList, // Sombra dinámica
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                
                // TEXTO DESPLEGABLE
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
                                // NOMBRE PRINCIPAL
                                Text(
                                  name, 
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: textColor, // Color inteligente
                                    fontWeight: FontWeight.w800, 
                                    fontSize: 13,
                                    letterSpacing: 0.8, // Espaciado premium
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // SUBTÍTULO
                                Text(
                                  subtext,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: subTextColor, // Opacidad inteligente
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(), 
                    ), 
                  ),
                ),
                
                // CABEZA ROBOT
                Container(
                  width: headSize,
                  height: headSize,
                  margin: const EdgeInsets.only(right: 4), 
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const ClipOval(child: FloatingHeadWidget()), 
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}