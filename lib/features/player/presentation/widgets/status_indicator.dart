// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatusIndicator extends StatelessWidget {
  final bool isLoading;
  final String mood;

  const StatusIndicator({
    super.key,
    required this.isLoading,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    // Definir estado visual según mood/loading
    String text;
    Color color;

    if (isLoading) {
      text = "PROCESANDO...";
      color = const Color(0xFF00F0FF); // Cian tecnológico
    } else {
      switch (mood) {
        case 'angry':
          text = "ENOJADO / DEFENSIVO";
          color = const Color(0xFFFF003C); // Rojo
          break;
        case 'happy':
          text = "FELIZ / VENDEDOR";
          color = const Color(0xFFFFC000); // Amarillo BotLode
          break;
        case 'tech':
          text = "MODO TÉCNICO";
          color = const Color(0xFFB026FF); // Púrpura
          break;
        case 'confused':
          text = "CONFUNDIDO";
          color = Colors.orange;
          break;
        default:
          text = "EN LÍNEA";
          color = const Color(0xFF00FF94); // Verde
      }
    }

    return Row(
      children: [
        // Punto pulsante
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 600.ms)
        .fadeOut(delay: 600.ms, duration: 600.ms), // Efecto de respiración

        const SizedBox(width: 8),

        // Texto
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}