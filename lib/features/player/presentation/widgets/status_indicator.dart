// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatusIndicator extends StatelessWidget {
  final bool isLoading;
  final bool isOnline;
  final String mood;
  final bool isDarkMode; 

  const StatusIndicator({
    super.key,
    required this.isLoading,
    required this.isOnline,
    required this.mood,
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
      text = "ESCRIBIENDO...";
      color = const Color(0xFF00FF94); 
    } else {
      switch (mood.toLowerCase()) {
        case 'angry': text = "ENOJADO"; color = const Color(0xFFFF2A00); break;
        case 'happy': text = "FELIZ"; color = const Color(0xFFFF00D6); break;
        case 'sales': text = "VENDEDOR"; color = const Color(0xFFFFC000); break;
        case 'confused': text = "CONFUNDIDO"; color = const Color(0xFF7B00FF); break;
        case 'tech': text = "TÉCNICO"; color = const Color(0xFF00F0FF); break;
        case 'neutral': default: text = "EN LÍNEA"; color = const Color(0xFF00FF94); break;
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