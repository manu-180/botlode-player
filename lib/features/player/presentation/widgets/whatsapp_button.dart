import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Botón flotante de WhatsApp épico con efecto WOW
/// Se posiciona arriba de la burbuja del bot
class WhatsAppButton extends StatefulWidget {
  final String phoneNumber;
  final bool isDarkMode;

  const WhatsAppButton({
    super.key,
    required this.phoneNumber,
    this.isDarkMode = true,
  });

  @override
  State<WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<WhatsAppButton> 
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _iconController;
  late Animation<double> _iconRotation;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    
    // ⬅️ Animación épica SOLO del ícono (rotación + escala sutil)
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Rotación muy sutil del ícono
    _iconRotation = Tween<double>(
      begin: -0.05, // -3 grados
      end: 0.05,    // +3 grados
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOut,
    ));
    
    // Escala muy sutil del ícono
    _iconScale = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _openWhatsApp() {
    // Formatear número: remover espacios, guiones, etc.
    final cleanNumber = widget.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // URL de WhatsApp (funciona en web y mobile)
    final url = 'https://wa.me/$cleanNumber';
    
    // Abrir en nueva pestaña
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 64.0; // Tamaño del botón (mismo que la burbuja bot: 80)
    const double iconSize = 28.0; // Tamaño del ícono
    
    // ⬅️ MISMO COMPORTAMIENTO QUE LA BURBUJA DEL BOT: Solo hover, sin pulso automático
    final double targetScale = _isHovered ? 1.1 : 1.0; // 10% más grande en hover (igual que bot)
    final double targetBlur = _isHovered ? 15.0 : 10.0; // Shadow igual que bot
    
    // ⬅️ Color de WhatsApp oficial con adaptación al tema
    final buttonColor = widget.isDarkMode 
        ? const Color(0xFF25D366) // Verde WhatsApp
        : const Color(0xFF20BA5A); // Verde más oscuro para light mode
    
    final borderColor = Colors.white.withOpacity(0.15);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: _openWhatsApp,
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
                // ⬅️ Sombra principal (igual que bot)
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.15),
                  blurRadius: targetBlur,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(buttonSize / 2),
                onTap: _openWhatsApp,
                child: Center(
                  // ⬅️ ANIMACIÓN ÉPICA SOLO DEL ÍCONO (rotación + escala)
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconRotation.value,
                        child: Transform.scale(
                          scale: _iconScale.value,
                          child: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
