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
    
    // ⬅️ FIX: Fondo totalmente transparente (sin overlay oscuro)
    return Scaffold(
      backgroundColor: Colors.transparent, // ⬅️ SIEMPRE TRANSPARENTE
      body: Stack(
        fit: StackFit.expand, // ⬅️ FIX: Llenar todo el espacio
        children: [
        // CHAT COMPLEJO (chat_panel_view) - SIEMPRE renderizado, solo cambia visibilidad
        Positioned(
          bottom: 0,
          right: 0,
          child: Visibility(
            visible: isOpen,
            maintainState: true,
            child: Container(
              width: 380,
              height: MediaQuery.of(context).size.height * 0.85, // ⬅️ 85% altura pantalla
              constraints: const BoxConstraints(
                maxHeight: 700, // ⬅️ Altura máxima
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF181818), // ⬅️ FONDO SÓLIDO
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                // ⬅️ SIN SOMBRA (causaba el borde oscuro)
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: Stack(
                  children: [
                    // ⬅️ CHAT_PANEL_VIEW COMPLETO
                    const ChatPanelView(),
                    // BOTÓN CLOSE ENCIMA
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => ref.read(isOpenSimpleProvider.notifier).state = false,
                          tooltip: 'Cerrar chat',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // BURBUJA CON RIVE AVATAR Y HOVER EXPANSIÓN - SIEMPRE renderizada
        Positioned(
          bottom: 40,
          right: 40,
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
    );
  }

  Widget _buildExpandableBubble({
    required String name,
    required String subtext,
  }) {
    const double closedSize = 72.0;
    const double headSize = 58.0;
    const double padding = 25.0; // Padding lateral
    const double extraSpace = 20.0; // Espacio extra "por las dudas"
    
    // ⬅️ CALCULAR ANCHO REAL DEL TEXTO
    double textWidth = _calculateTextWidth(name, const TextStyle(fontSize: 15, fontWeight: FontWeight.w900));
    double subtextWidth = _calculateTextWidth(subtext, const TextStyle(fontSize: 10));
    double maxTextWidth = textWidth > subtextWidth ? textWidth : subtextWidth;
    
    // ⬅️ ANCHO TOTAL = avatar + padding + texto + extra
    double expandedWidth = headSize + padding + maxTextWidth + extraSpace;
    double targetWidth = _isHovered ? expandedWidth : closedSize;
    
    return GestureDetector(
      onTap: () => ref.read(isOpenSimpleProvider.notifier).state = true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: targetWidth,
        height: closedSize,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(closedSize / 2),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
                // TEXTO (solo visible en hover)
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
                            style: const TextStyle(
                              color: Colors.white,
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
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                
                // AVATAR RIVE
                Container(
                  width: headSize,
                  height: headSize,
                  margin: const EdgeInsets.all(7),
                  child: ClipOval(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final headbotLoader = ref.watch(riveHeadFileLoaderProvider);
                        
                        return headbotLoader.when(
                          data: (_) => const BotAvatarWidget(),
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
  }

  // ⬅️ MÉTODO PARA CALCULAR ANCHO REAL DEL TEXTO
  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    
    return textPainter.width;
  }
}
