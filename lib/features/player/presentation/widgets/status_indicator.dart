// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';

class StatusIndicator extends ConsumerWidget {
  final bool isLoading;
  final bool isOnline;
  final String mood;
  final bool isDarkMode;
  final String? currentSessionId; // ⬅️ SessionId del chat actual (opcional, se puede obtener del provider)

  const StatusIndicator({
    super.key,
    required this.isLoading,
    required this.isOnline,
    required this.mood,
    this.currentSessionId, // ⬅️ Opcional: si no se proporciona, se obtiene del provider
    this.isDarkMode = true, 
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⬅️ Obtener valores directamente de los providers para máxima reactividad
    final isChatOpen = ref.watch(chatOpenProvider);
    final activeSessionId = ref.watch(activeSessionIdProvider);
    
    // ⬅️ PRIORIDAD MÁXIMA: Si el chat está cerrado, ocultar el widget COMPLETAMENTE
    // Esto evita cualquier condición de carrera o estado persistente
    if (!isChatOpen) {
      return const SizedBox.shrink();
    }
    
    // ⬅️ Si no se proporciona currentSessionId, obtenerlo del chatControllerProvider
    final effectiveCurrentSessionId = currentSessionId ?? 
        (ref.watch(chatControllerProvider).sessionId);
    
    String text;
    Color color;
    IconData? statusIcon;
    bool shouldAnimate = false; // Control de animación del punto

    // LÓGICA DE ESTADOS
    if (!isOnline) {
      text = "SIN CONEXIÓN";
      color = const Color(0xFFFF003C);
      statusIcon = Icons.wifi_off_rounded; // WiFi tachado
      shouldAnimate = true; // Punto rojo parpadeante cuando está offline
    } else {
      // ⬅️ Cuando isLoading es true, NO mostrar "PROCESANDO..." - mostrar estado normal ("EN LÍNEA", emociones, etc.)
      switch (mood.toLowerCase()) {
        case 'angry': 
          text = "ENOJADO"; 
          color = const Color(0xFFFF2A00);
          statusIcon = Icons.mood_bad_rounded;
          break;
        case 'happy': 
          text = "FELIZ"; 
          color = const Color(0xFFFF00D6);
          statusIcon = Icons.mood_rounded;
          break;
        case 'sales': 
          text = "VENDEDOR"; 
          color = const Color(0xFFFFC000);
          statusIcon = Icons.attach_money_rounded;
          break;
        case 'confused': 
          text = "CONFUNDIDO"; 
          color = const Color(0xFF7B00FF);
          statusIcon = Icons.help_outline_rounded;
          break;
        case 'tech': 
          text = "TÉCNICO"; 
          color = const Color(0xFF00F0FF);
          statusIcon = Icons.settings_suggest_rounded;
          break;
        case 'neutral':
        case 'idle':
        default: 
          // ⬅️ "EN LÍNEA" se muestra como las otras emociones cuando el mood es neutral
          // Pero solo si este es el chat activo (no el histórico) Y el chat está abierto
          
          // ⬅️ LÓGICA REFACTORIZADA: Determinar si este chat debe mostrar "EN LÍNEA"
          // REGLA FUNDAMENTAL: Solo UN chat puede mostrar "EN LÍNEA" a la vez
          // Condiciones ESTRICTAS (TODAS deben cumplirse):
          // 1. isChatOpen DEBE ser true (el chat está abierto) - PRIORIDAD MÁXIMA
          // 2. activeSessionId NO debe ser null (hay un chat activo definido)
          // 3. currentSessionId NO debe ser null (este chat tiene un sessionId válido)
          // 4. activeSessionId DEBE coincidir EXACTAMENTE con currentSessionId (este ES el chat activo)
          // Si CUALQUIERA de estas condiciones falla, NO mostrar "EN LÍNEA"
          
          final bool shouldShowOnline;
          
          // ⬅️ PRIORIDAD 1: Si el chat está cerrado, NUNCA mostrar "EN LÍNEA" (sin importar nada más)
          if (!isChatOpen) {
            shouldShowOnline = false;
          } else if (activeSessionId == null || activeSessionId.isEmpty) {
            // No hay chat activo definido (durante reload, inicialización, o chat cerrado)
            shouldShowOnline = false;
          } else if (effectiveCurrentSessionId.isEmpty) {
            // Este chat no tiene sessionId válido
            shouldShowOnline = false;
          } else if (activeSessionId != effectiveCurrentSessionId) {
            // Este NO es el chat activo (hay otro chat activo)
            shouldShowOnline = false;
          } else {
            // ✅ TODAS las condiciones se cumplen: chat abierto + este es el chat activo
            shouldShowOnline = true;
          }
          
          if (shouldShowOnline) {
            text = "CONEXIÓN RESTABLECIDA"; 
            color = const Color(0xFF00FF94);
            statusIcon = Icons.check_circle_rounded; // Check cuando se recupera
            shouldAnimate = false; // Sin animación cuando está conectado
          } else {
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

    // WIDGET DEL PUNTO INDICADOR (Reemplaza la barra, más visible)
    final Widget statusDot = Container(
      width: 10, 
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isDarkMode 
            ? [
                // MODO DARK: GLOW ATMOSFÉRICO
                BoxShadow(color: color, blurRadius: 6, spreadRadius: 2),
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 14, spreadRadius: 4),
              ]
            : [
                // MODO LIGHT: LED SÓLIDO
                BoxShadow(color: color.withOpacity(0.7), blurRadius: 3, spreadRadius: 0),
              ],
      ),
    );

    // ⬅️ Si el texto está vacío (chat cerrado / offline / sin estado), ocultar el widget
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 12, top: 8, bottom: 8),
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
          // ICONO DE ESTADO (WiFi tachado / Check / etc)
          if (statusIcon != null) ...[
            Icon(
              statusIcon,
              size: 18,
              color: color,
            ).animate(
              onPlay: shouldAnimate ? (c) => c.repeat() : null,
            )
              .fadeIn(duration: 200.ms, curve: Curves.easeOut)
              .then(delay: 300.ms)
              .fadeOut(duration: 600.ms, curve: Curves.easeIn)
              .then(delay: 100.ms),
            const SizedBox(width: 8),
          ],

          // PUNTO PARPADEANTE (solo cuando está offline)
          if (shouldAnimate) ...[
            statusDot.animate(onPlay: (c) => c.repeat()) // Bucle infinito
              .fadeIn(duration: 200.ms, curve: Curves.easeOut) // 1. IGNICIÓN
              .then(delay: 200.ms)        // 2. HOLD (TIEMPO PRENDIDO)
              .fadeOut(duration: 800.ms, curve: Curves.easeIn) // 3. APAGADO
              .then(delay: 150.ms),       // 4. TIEMPO APAGADO
            const SizedBox(width: 10),
          ],

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