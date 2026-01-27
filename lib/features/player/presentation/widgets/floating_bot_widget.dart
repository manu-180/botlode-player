// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
// import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/views/simple_chat_test.dart'; // ⬅️ TEST
import 'package:botlode_player/features/player/presentation/widgets/floating_head_widget.dart';
import 'package:flutter/material.dart';
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
    
    // ⬅️ LISTENER: Manejar estado cuando se abre/cierra el chat
    ref.listen(chatOpenProvider, (previous, next) {
      if (previous == true && next == false) {
        // Chat se cerró: NO resetear mood, solo dejar que "EN LÍNEA" desaparezca
        // El mood se mantiene, pero StatusIndicator lo ocultará porque isChatOpen = false
        // No hacer nada aquí, el StatusIndicator se encargará de ocultar "EN LÍNEA"
      } else if (previous == false && next == true) {
        // Chat se abrió: asegurar que si el mood es 'neutral', se muestre "EN LÍNEA"
        // El StatusIndicator se encargará de mostrarlo automáticamente porque isChatOpen = true
        // No necesitamos hacer nada aquí, el estado ya está correcto
      }
    });

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    // Altura aumentada: casi toda la pantalla, dejando espacio para appbar (80px)
    final double safeHeight = (screenSize.height - 80.0).clamp(600.0, double.infinity);

    const double ghostPadding = 40.0;

    // DEBUG (Como en tu ejemplo)
    print("🎈 [DEBUG BUBBLE] Open: $isOpen | ConfigLoaded: ${botConfigAsync.hasValue}");

    // MouseRegion global que captura el mouse en TODA la pantalla
    // Calcula respecto a diferentes puntos según si el chat está abierto o cerrado
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (event) {
        final double dx;
        final double dy;
        
        if (isOpen) {
          // Chat ABIERTO: calcular respecto al avatar dentro del chat
          // El chat está en top con ancho máximo de 420px (o menos en móvil)
          final double chatWidth = isMobile ? screenSize.width : 420.0;
          
          // Avatar está centrado horizontalmente en el chat y a ~100px del top del chat (80px appbar + 100px)
          final double avatarCenterX = isMobile ? screenSize.width / 2 : screenSize.width - (chatWidth / 2);
          final double avatarCenterY = 80.0 + 100.0; // appbar + offset del avatar
          
          dx = event.position.dx - avatarCenterX;
          dy = event.position.dy - avatarCenterY;
        } else {
          // Chat CERRADO: calcular respecto al botón flotante
          final double headCenterX = screenSize.width - ghostPadding - 36.0;
          final double headCenterY = screenSize.height - ghostPadding - 36.0;
          
          dx = event.position.dx - headCenterX;
          dy = event.position.dy - headCenterY;
        }
        
        ref.read(pointerPositionProvider.notifier).state = Offset(dx, dy);
      },
      onExit: (_) {
        // Resetear cuando el mouse sale completamente
        ref.read(pointerPositionProvider.notifier).state = null;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        // PANEL DE CHAT - SIN ANIMACIONES (causan problema en iframe)
        // Posicionado desde arriba, dejando espacio para appbar (80px)
        if (isOpen)
          Positioned(
            top: 80, // Espacio para appbar
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: safeHeight, 
                maxWidth: isMobile ? double.infinity : 420 // Ancho aumentado
              ),
              child: const SimpleChatTest(), // ⬅️ CHAT COMPLETO (ya tiene su propio Container con fondo)
            ),
          ),

        // ⬅️ OVERLAY: Detectar clicks fuera del chat para cerrarlo
        // Debe estar DESPUÉS del chat en el Stack para estar encima
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                // Calcular si el tap está dentro del área del chat
                final chatWidth = isMobile ? screenSize.width : 420.0;
                final chatLeft = screenSize.width - chatWidth;
                final chatTop = 80.0;
                final chatRight = screenSize.width;
                final chatBottom = chatTop + safeHeight;
                
                final tapX = details.localPosition.dx;
                final tapY = details.localPosition.dy;
                
                // Solo cerrar si el tap está FUERA del área del chat
                final isOutsideChat = tapX < chatLeft || 
                                      tapX > chatRight || 
                                      tapY < chatTop || 
                                      tapY > chatBottom;
                
                if (isOutsideChat) {
                  // Cerrar chat (el listener se encargará de resetear el mood)
                  ref.read(chatOpenProvider.notifier).set(false);
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // BURBUJA FLOTANTE
        Positioned(
          bottom: ghostPadding, right: ghostPadding,
          child: IgnorePointer(
            ignoring: isOpen, 
            child: MouseRegion(
              onEnter: (_) => ref.read(isHoveredExternalProvider.notifier).state = true,
              onExit: (_) => ref.read(isHoveredExternalProvider.notifier).state = false,
              child: AnimatedScale(
                scale: isOpen ? 0.0 : 1.0, 
                duration: const Duration(milliseconds: 300),
                curve: isOpen ? Curves.easeInBack : Curves.easeOutBack, 
                alignment: Alignment.center,
                child: botConfigAsync.when(
                  loading: () => _buildFloatingButton(isHovered: false, name: "...", color: Colors.grey, subtext: "...", isDarkMode: true),
                  error: (err, stack) => _buildFloatingButton(isHovered: false, name: "ERROR", color: Colors.red, subtext: "Offline", isDarkMode: true),
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
        ),
      ],
      ),
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
    
    int maxChars = math.max(name.length, subtext.length);
    double calculatedWidth = 120.0 + (maxChars * 9.0);
    double targetWidth = isHovered ? calculatedWidth.clamp(220.0, 380.0) : closedSize;

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic, 
        width: targetWidth, 
        height: closedSize, 
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(closedSize / 2),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ], 
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(closedSize / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(closedSize / 2),
            onTap: () {
              ref.read(chatOpenProvider.notifier).set(true);
              html.window.parent?.postMessage('CMD_OPEN', '*');
            },
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
                            padding: const EdgeInsets.only(left: 25, right: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end, 
                              children: [
                                Text(
                                  name, 
                                  textAlign: TextAlign.right, 
                                  style: TextStyle(
                                    color: textColor, 
                                    fontWeight: FontWeight.w900, 
                                    fontSize: 15
                                  )
                                ),
                                Text(
                                  subtext, 
                                  textAlign: TextAlign.right, 
                                  style: TextStyle(
                                    color: subTextColor, 
                                    fontSize: 10
                                  )
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
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: Icon(Icons.smart_toy_rounded, color: textColor.withOpacity(0.5), size: 30)),
                        const FloatingHeadWidget(), 
                      ],
                    ),
                  ), 
                ),
              ],
            ),
          ),
        ),
    );
  }
}