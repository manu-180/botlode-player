// Archivo: lib/features/player/presentation/widgets/chat_bubble.dart
import 'package:botlode_player/features/player/domain/models/chat_message.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color botThemeColor;
  final bool isDarkMode; 

  const ChatBubble({
    super.key, 
    required this.message,
    required this.botThemeColor, 
    this.isDarkMode = true, 
  });

  // MAGIA MATEMÁTICA: Decide si el texto debe ser BLANCO o NEGRO
  Color _getContrastingTextColor(Color background) {
    // Calcula si el color de fondo es oscuro o claro
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white  // Fondo oscuro (Rojo, Azul) -> Texto Blanco
        : Colors.black; // Fondo claro (Amarillo, Blanco) -> Texto Negro
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    
    // DEFINICIÓN DE COLORES
    Color bgColor;
    Color textColor;
    BoxBorder? border;

    if (isUser) {
      // USUARIO
      bgColor = botThemeColor;
      // Aquí aplicamos la corrección: Texto inteligente
      textColor = _getContrastingTextColor(botThemeColor); 
      border = null;
    } else {
      // BOT
      if (isDarkMode) {
        bgColor = Colors.white.withOpacity(0.10); // Un poco más sutil
        textColor = Colors.white;
        border = Border.all(color: Colors.white.withOpacity(0.08));
      } else {
        bgColor = Colors.white;
        textColor = const Color(0xFF2D3748); // Gris oscuro elegante (no negro puro)
        border = Border.all(color: Colors.black.withOpacity(0.05)); 
      }
    }
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // Margen vertical más ajustado
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 340), // Evita que sean demasiado anchas
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: border,
          // Sombra muy suave solo para mensajes del usuario para dar "pop"
          boxShadow: isUser 
             ? [BoxShadow(color: botThemeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
             : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: textColor,
            height: 1.4,
            fontSize: 14,
            fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}