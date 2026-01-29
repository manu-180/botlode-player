// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:botlode_player/core/network/connectivity_provider.dart';
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

    // LÓGICA DE ESTADOS
    // Solo mostrar "DESCONECTADO" si ALGUNA VEZ hubo conectividad real (hasEverBeenOnline = true).
    // Esto evita mostrar el cartel al refrescar la página sin internet.
    final hasEverBeenOnline = ref.watch(hasEverBeenOnlineProvider);

    if (!isOnline) {
      if (hasEverBeenOnline) {
        text = "DESCONECTADO";
        color = const Color(0xFFFF003C); // Rojo Alerta
      } else {
        // Estado inicial offline (nunca hubo conexión en esta sesión): ocultar indicador.
        text = "";
        color = const Color(0xFFFF003C);
      }
    } else {
      // ⬅️ Cuando isLoading es true, NO mostrar "PROCESANDO..." - mostrar estado normal ("EN LÍNEA", emociones, etc.)
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
            text = "EN LÍNEA"; 
            color = const Color(0xFF00FF94);
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