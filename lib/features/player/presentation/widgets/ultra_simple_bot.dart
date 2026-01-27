// ULTRA SIMPLE - Burbuja + Chat COMPLEJO (chat_panel_view) para testing
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider simple
final isOpenSimpleProvider = StateProvider<bool>((ref) => false);

class UltraSimpleBot extends ConsumerStatefulWidget {
  const UltraSimpleBot({super.key});

  @override
  ConsumerState<UltraSimpleBot> createState() => _UltraSimpleBotState();
}

class _UltraSimpleBotState extends ConsumerState<UltraSimpleBot> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(isOpenSimpleProvider);
    final screenSize = MediaQuery.of(context).size;
    
    // ⬅️ RESPONSIVE: Detectar móvil y calcular dimensiones seguras
    final bool isMobile = screenSize.width < 600;
    final double chatWidth = isMobile 
        ? (screenSize.width - 16).clamp(320.0, 380.0) // Móvil: ancho disponible - padding, min 320px
        : 380.0; // Desktop: fijo 380px
    
    final double horizontalPadding = isMobile ? 8.0 : 28.0; // Menos padding en móvil
    final double verticalPadding = isMobile ? 8.0 : 28.0;
    
    // ⬅️ Altura segura: 92% de pantalla, máximo 800px, mínimo 400px
    final double chatHeight = (screenSize.height * 0.92 - verticalPadding * 2)
        .clamp(400.0, 800.0);
    
    // ⬅️ FIX: Fondo totalmente transparente
    // ✅ TRACKING GLOBAL: Manejado por JavaScript nativo en main.dart
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: GestureDetector(
        // ⬅️ NUEVO: Cerrar chat al hacer clic fuera
        onTap: () {
          if (isOpen) {
            ref.read(isOpenSimpleProvider.notifier).state = false;
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            
            // CHAT COMPLEJO (Panel)
            Positioned(
              bottom: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                offset: isOpen ? Offset.zero : const Offset(1.2, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isOpen ? 1.0 : 0.0,
                  child: Visibility(
                    visible: isOpen,
                    maintainState: true,
                    child: GestureDetector(
                      // ⬅️ NUEVO: Detener propagación de clics dentro del chat
                      onTap: () {}, // No hacer nada, solo detener propagación
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: horizontalPadding, 
                          bottom: verticalPadding,
                          left: isMobile ? horizontalPadding : 0, // ⬅️ Padding izquierdo en móvil
                          top: isMobile ? verticalPadding : 0, // ⬅️ Padding superior en móvil
                        ),
                        child: Container(
                        width: chatWidth, // ⬅️ RESPONSIVE: Ancho adaptativo
                        height: chatHeight, // ⬅️ RESPONSIVE: Altura segura
                        constraints: BoxConstraints(
                          maxWidth: chatWidth, // ⬅️ Asegurar que nunca exceda el ancho calculado
                          maxHeight: chatHeight, // ⬅️ Asegurar que nunca exceda la altura calculada
                          minWidth: isMobile ? 320.0 : 380.0, // ⬅️ Ancho mínimo
                          minHeight: 400.0, // ⬅️ Altura mínima
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(-5, 0),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            children: [
                              const ChatPanelView(), // ⬅️ Aquí usa BotAvatarWidget(isBubble: false) por defecto
                              Positioned(
                                top: 16,
                                right: 16,

                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final botConfig = ref.watch(botConfigProvider);
                                    final isDarkMode = botConfig.asData?.value.isDarkMode ?? true;
                                    
                                    // ⬅️ Color adaptativo según tema
                                    final iconColor = isDarkMode 
                                        ? Colors.white 
                                        : Colors.black87;
                                    
                                    return Material(
                                      color: Colors.transparent,
                                      child: IconButton(
                                        icon: Icon(Icons.close_rounded, color: iconColor),
                                        onPressed: () => ref.read(isOpenSimpleProvider.notifier).state = false,
                                        tooltip: 'Cerrar chat',
                                        style: IconButton.styleFrom(
                                          backgroundColor: isDarkMode 
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.black.withOpacity(0.05),
                                          hoverColor: isDarkMode
                                              ? Colors.white.withOpacity(0.2)
                                              : Colors.black.withOpacity(0.1),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // BURBUJA FLOTANTE
            Positioned(
              bottom: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              right: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              child: Visibility(
                visible: !isOpen,
                maintainState: true,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final botConfig = ref.watch(botConfigProvider);
                      
                      return botConfig.when(
                        data: (config) => _buildExpandableBubble(
                          name: config.name.toUpperCase(),
                          subtext: "¿En qué te ayudo?",
                        ),
                        loading: () => _buildExpandableBubble(
                          name: "CARGANDO...",
                          subtext: "",
                        ),
                        error: (_, __) => _buildExpandableBubble(
                          name: "BOT",
                          subtext: "Haz click para abrir",
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildExpandableBubble({
    required String name,
    required String subtext,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final botConfig = ref.watch(botConfigProvider);
        final isDarkMode = botConfig.asData?.value.isDarkMode ?? true;
        
        const double closedSize = 80.0; // ⬅️ Aumentado de 72 a 80
        const double headSize = 68.0; // ⬅️ Aumentado de 58 a 68
        const double padding = 25.0; 
        const double extraSpace = 40.0; 
        
        double textWidth = _calculateTextWidth(name, const TextStyle(fontSize: 15, fontWeight: FontWeight.w900));
        double subtextWidth = _calculateTextWidth(subtext, const TextStyle(fontSize: 10));
        double maxTextWidth = textWidth > subtextWidth ? textWidth : subtextWidth;
        
        double expandedWidth = headSize + padding + maxTextWidth + extraSpace;
        double targetWidth = _isHovered ? expandedWidth : closedSize;
        
        // ⬅️ COLORES ADAPTATIVOS según tema (sutil pero profesional)
        final bubbleColor = isDarkMode 
            ? const Color(0xFF2A2A3E)  // Dark: Mantener el color actual (te gusta)
            : const Color(0xFF3A3A4E); // Light: Ligeramente más claro pero mantiene identidad
        
        final borderColor = isDarkMode
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.1);
        
        return GestureDetector(
          onTap: () => ref.read(isOpenSimpleProvider.notifier).state = true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: targetWidth,
            height: closedSize,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(closedSize / 2),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(closedSize / 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(closedSize / 2),
                onTap: () => ref.read(isOpenSimpleProvider.notifier).state = true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isHovered)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: padding, right: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtext.isNotEmpty)
                                Text(
                                  subtext,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: isDarkMode 
                                        ? Colors.white.withOpacity(0.85)
                                        : Colors.black87.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    
                    Container(
                      width: headSize,
                      height: headSize,
                      margin: const EdgeInsets.all(7),
                      child: ClipOval(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final riveLoader = ref.watch(riveHeadFileLoaderProvider); 
                            
                            return riveLoader.when(
                              // ⬅️ PASO 2: Aquí pasamos isBubble: true
                              data: (_) => const BotAvatarWidget(isBubble: true),
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, __) => const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      },
    );
  }

  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    
    return textPainter.width;
  }
}