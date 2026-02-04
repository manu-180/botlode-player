import 'dart:html' as html;
import 'package:flutter/material.dart';

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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // ⬅️ Animación de pulso sutil para llamar la atención
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    const double buttonSize = 64.0; // Tamaño del botón
    const double iconSize = 32.0; // Tamaño del ícono
    
    // ⬅️ NUEVA ESTRATEGIA: Scale en lugar de expandir
    final double targetScale = _isHovered ? 1.15 : 1.0; // 15% más grande en hover
    final double targetBlur = _isHovered ? 20.0 : 12.0; // Shadow más pronunciado en hover
    
    // ⬅️ Color de WhatsApp oficial con adaptación al tema
    final buttonColor = widget.isDarkMode 
        ? const Color(0xFF25D366) // Verde WhatsApp
        : const Color(0xFF20BA5A); // Verde más oscuro para light mode
    
    final borderColor = Colors.white.withOpacity(0.2);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return AnimatedScale(
            scale: _isHovered ? targetScale : _pulseAnimation.value,
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
                  // ⬅️ Gradiente para efecto más premium
                  gradient: RadialGradient(
                    colors: [
                      buttonColor,
                      buttonColor.withOpacity(0.85),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(buttonSize / 2),
                  border: Border.all(
                    color: borderColor,
                    width: 2.0,
                  ),
                  boxShadow: [
                    // ⬅️ Sombra principal
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: targetBlur,
                      offset: const Offset(0, 4),
                    ),
                    // ⬅️ Glow verde para efecto WOW
                    BoxShadow(
                      color: buttonColor.withOpacity(_isHovered ? 0.5 : 0.3),
                      blurRadius: _isHovered ? 24.0 : 16.0,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(buttonSize / 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(buttonSize / 2),
                    onTap: _openWhatsApp,
                    splashColor: Colors.white.withOpacity(0.2),
                    child: Center(
                      child: Icon(
                        Icons.chat,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
