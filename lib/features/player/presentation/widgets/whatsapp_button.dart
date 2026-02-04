import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Botón flotante de WhatsApp. Tamaño fijo, sin animaciones de escala.
/// Se posiciona arriba de la burbuja del bot.
class WhatsAppButton extends StatelessWidget {
  final String phoneNumber;
  final bool isDarkMode;

  const WhatsAppButton({
    super.key,
    required this.phoneNumber,
    this.isDarkMode = true,
  });

  void _openWhatsApp(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'https://wa.me/$cleanNumber';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 84.0; // Fijo, un poco más grande que la burbuja del bot
    const double iconSize = 34.0;

    final buttonColor = isDarkMode
        ? const Color(0xFF25D366)
        : const Color(0xFF20BA5A);

    final borderColor = Colors.white.withOpacity(0.2);

    return GestureDetector(
      onTap: () => _openWhatsApp(phoneNumber),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(buttonSize / 2),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: buttonColor.withOpacity(0.25),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(buttonSize / 2),
            onTap: () => _openWhatsApp(phoneNumber),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
