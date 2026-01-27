// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatusIndicator extends StatelessWidget {
  final bool isLoading;
  final bool isOnline;
  final String mood;
  final bool isDarkMode;
  final bool isChatOpen; // ⬅️ Estado del chat (abierto/cerrado)
  final String? currentSessionId; // ⬅️ NUEVO: SessionId del chat actual
  final String? activeSessionId; // ⬅️ NUEVO: SessionId activo (el más reciente)

  const StatusIndicator({
    super.key,
    required this.isLoading,
    required this.isOnline,
    required this.mood,
    required this.isChatOpen,
    this.currentSessionId, // ⬅️ Opcional: si no se proporciona, siempre mostrará si está abierto
    this.activeSessionId, // ⬅️ Opcional: si no se proporciona, siempre mostrará si está abierto
    this.isDarkMode = true, 
  });

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    // LÓGICA DE ESTADOS
    if (!isOnline) {
      text = "DESCONECTADO";
      color = const Color(0xFFFF003C); // Rojo Alerta
    } else if (isLoading) {
      text = "PROCESANDO...";
      color = const Color(0xFF00FF94); 
    } else {
      switch (mood.toLowerCase()) {
        case 'angry': text = "ENOJADO"; color = const Color(0xFFFF2A00); break;
        case 'happy': text = "FELIZ"; color = const Color(0xFFFF00D6); break;
        case 'sales': text = "VENDEDOR"; color = const Color(0xFFFFC000); break;
        case 'confused': text = "CONFUNDIDO"; color = const Color(0xFF7B00FF); break;
        case 'tech': text = "TÉCNICO"; color = const Color(0xFF00F0FF); break;
        case 'neutral':
        case 'idle':
        default: 
          // ⬅️ "EN LÍNEA" se muestra como las otras emociones cuando el mood es neutral
          // Pero solo si este es el chat activo (no el histórico) Y el chat está abierto
          
          // Determinar si este es el chat activo:
          // - Si no hay activeSessionId establecido, considerar activo solo si hay currentSessionId
          // - Si hay activeSessionId, solo es activo si coinciden
          final isActiveChat = (activeSessionId == null && currentSessionId != null) ||
                               (activeSessionId != null && currentSessionId != null && currentSessionId == activeSessionId);
          
          // Mostrar "EN LÍNEA" solo si es el chat activo Y el chat está abierto
          if (isActiveChat && isChatOpen) {
            text = "EN LÍNEA"; 
            color = const Color(0xFF00FF94);
          } else {
            // Chat histórico, cerrado, o no activo: no mostrar "EN LÍNEA" (ocultar widget)
            text = ""; 
            color = const Color(0xFF00FF94);
          }
          break;
      }
    }

    // --- DISEÑO ADAPTATIVO (Industrial Light/Dark) ---
    final Color bgColor = isDarkMode 
        ? const Color(0xFF0A0A0A).withOpacity(0.95) 
        : const Color(0xFFFFFFFF).withOpacity(0.95); 
    
    final Color textColor = isDarkMode 
        ? Colors.white.withOpacity(0.9) 
        : const Color(0xFF2D2D2D); 

    final Color borderColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

    // WIDGET DEL REACTOR (La barra de luz)
    final Widget reactorBar = Container(
      width: 4, 
      height: 14,
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(2),
        boxShadow: isDarkMode 
            ? [
                // MODO DARK: GLOW ATMOSFÉRICO (Tu efecto favorito actual)
                // Se ve iluminado y expansivo sobre fondo negro.
                BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 3),
              ]
            : [
                // MODO LIGHT: LED SÓLIDO (Corrección solicitada)
                // Eliminamos el blur excesivo. Ahora es nítido y saturado.
                // Solo un pequeño brillo muy pegado para que no se vea plano, pero sin manchar.
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 2, spreadRadius: 0),
              ],
      ),
    );

    // ⬅️ Si el texto está vacío (chat cerrado + mood neutral), ocultar el widget
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(left: 6, right: 12, top: 6, bottom: 6),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: borderColor, width: 1), 
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            bottomRight: Radius.circular(10), // Corte característico
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.6 : 0.1), 
            blurRadius: 10, 
            offset: const Offset(2, 4)
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ANIMACIÓN SECUENCIAL PURA
          reactorBar.animate(onPlay: (c) => c.repeat()) // Bucle infinito
            .fadeIn(duration: 200.ms, curve: Curves.easeOut) // 1. IGNICIÓN
            .then(delay: isOnline ? 1300.ms : 200.ms)        // 2. HOLD (TIEMPO PRENDIDO REAL)
            .fadeOut(duration: 800.ms, curve: Curves.easeIn) // 3. APAGADO
            .then(delay: 150.ms),                            // 4. TIEMPO APAGADO

          const SizedBox(width: 10),

          // TEXTO TÉCNICO
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Courier', 
              fontWeight: FontWeight.w800, 
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}