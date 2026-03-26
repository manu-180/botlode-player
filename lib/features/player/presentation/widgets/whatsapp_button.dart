import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Botón flotante de WhatsApp (hover/escala desactivados en producción).
/// Se posiciona arriba de la burbuja del bot.
class WhatsAppButton extends StatefulWidget {
  final String phoneNumber;
  final bool isDarkMode;
  final double bubbleSize;

  const WhatsAppButton({
    super.key,
    required this.phoneNumber,
    this.isDarkMode = true,
    this.bubbleSize = 86.0,
  });

  @override
  State<WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<WhatsAppButton> {
  void _openWhatsApp(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'https://wa.me/$cleanNumber';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ Tamaño dinámico desde BD (sync en tiempo real)
    final double buttonSize = widget.bubbleSize;
    final double iconSize = buttonSize * 0.419; // Proporción 36/86 ≈ 0.419

    final buttonColor = widget.isDarkMode
        ? const Color(0xFF25D366)
        : const Color(0xFF20BA5A);

    final borderColor = Colors.white.withOpacity(0.2);
    
    // Hover desactivado (producción), misma sombra base que sin hover.
    const double targetScale = 1.0;
    const double targetBlur = 12.0;

    return AnimatedScale(
      scale: targetScale,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openWhatsApp(widget.phoneNumber),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
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
                color: Colors.black.withOpacity(widget.isDarkMode ? 0.35 : 0.2),
                blurRadius: targetBlur,
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
              onTap: () => _openWhatsApp(widget.phoneNumber),
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
      ),
    );
  }
}
