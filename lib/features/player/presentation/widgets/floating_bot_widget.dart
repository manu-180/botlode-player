// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/core/services/presence_manager_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart'; // ⬅️ NUEVO: Para acceder a chatControllerProvider
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
// import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/views/simple_chat_test.dart'; // ⬅️ TEST
import 'package:botlode_player/features/player/presentation/widgets/floating_head_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingBotWidget extends ConsumerStatefulWidget {
  const FloatingBotWidget({super.key});

  @override
  ConsumerState<FloatingBotWidget> createState() => _FloatingBotWidgetState();
}

class _FloatingBotWidgetState extends ConsumerState<FloatingBotWidget> {
  bool _wasNetworkOffline = false;
  
  Color _getContrastingTextColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
  
  // ⬅️ Helper para formatear hora de Argentina (UTC-3) sin zona horaria
  String _formatArgentinaTime() {
    final nowLocal = DateTime.now().toLocal();
    final nowArgentina = nowLocal.subtract(const Duration(hours: 3));
    return '${nowArgentina.year}-${nowArgentina.month.toString().padLeft(2, '0')}-${nowArgentina.day.toString().padLeft(2, '0')}T${nowArgentina.hour.toString().padLeft(2, '0')}:${nowArgentina.minute.toString().padLeft(2, '0')}:${nowArgentina.second.toString().padLeft(2, '0')}.${nowArgentina.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(chatOpenProvider);
    final botConfigAsync = ref.watch(botConfigProvider);
    final isHovered = ref.watch(isHoveredExternalProvider);

    final bool showOfflineAlert =
        botConfigAsync.asData?.value.showOfflineAlert ?? true;
    
    // ⬅️ LISTENER: Manejar estado cuando se abre/cierra el chat
    ref.listen(chatOpenProvider, (previous, next) {
      if (previous == true && next == false) {
        // Chat se cerró: Invalidar activeSessionId SÍNCRONAMENTE y marcar TODOS los chats como offline en BD
        // ⚠️ CRÍTICO: Debe hacerse SÍNCRONAMENTE, no en un Future.microtask
        ref.read(activeSessionIdProvider.notifier).state = null;
        
        // ⬅️ CRÍTICO: Marcar como offline en BD INMEDIATAMENTE (sin debounce)
        // Esto evita que otros chats vean este chat como online cuando se consulta la BD
        try {
          final presenceManager = ref.read(presenceManagerProvider);
          presenceManager.setOfflineImmediate();
        } catch (e) {
          // Error silenciado
        }
        
        // ⬅️ NUEVO: Marcar TODOS los chats de este bot como offline en la BD
        // Esto asegura que ningún chat viejo muestre "EN LÍNEA" cuando el chat está cerrado
        Future.microtask(() async {
          try {
            final botId = ref.read(currentBotIdProvider);
            final supabase = ref.read(supabaseClientProvider);
            
            // Actualizar TODOS los chats de este bot a offline
            await supabase
                .from('session_heartbeats')
                .update({'is_online': false})
                .eq('bot_id', botId)
                .eq('is_online', true);
          } catch (e) {
            // Error silenciado
          }
        });
        
        // ⬅️ Forzar un rebuild inmediato para asegurar que el StatusIndicator se actualice
        Future.microtask(() {
          // Verificar que se invalidó correctamente
          final verifyActiveSessionId = ref.read(activeSessionIdProvider);
          if (verifyActiveSessionId != null) {
            ref.read(activeSessionIdProvider.notifier).state = null;
          }
        });
      } else if (previous == false && next == true) {
        // ⬅️ ESTRATEGIA DETERMINISTA: El chat actual es SIEMPRE el activo
        // No consultamos la BD para "adivinar" cuál es más reciente.
        // El chat que el usuario está viendo ES la fuente de verdad.
        try {
          final chatState = ref.read(chatControllerProvider);
          final currentSessionId = chatState.sessionId;
          final currentChatId = chatState.chatId;
          final botId = ref.read(currentBotIdProvider);
          final supabase = ref.read(supabaseClientProvider);
          
          // ⬅️ PASO 1: Actualización Optimista de UI (SÍNCRONA e INMEDIATA)
          // Le decimos a la UI: "Esta sesión es válida AHORA". No esperamos a la BD.
          // Esto elimina el lag percibido y previene condiciones de carrera.
          ref.read(activeSessionIdProvider.notifier).state = currentSessionId;
          
          // ⬅️ PASO 2: Reclamar sesión en BD (ASÍNCRONO pero PRIORITARIO)
          // Ordenamos al servidor imponer esta verdad y eliminar competidores (zombis).
          // Esto implementa el patrón "Mutex de Sesión" descrito en el documento técnico.
          // ⚠️ CRÍTICO: Ejecutar INMEDIATAMENTE sin esperar microtask para evitar condiciones de carrera
          (() async {
            try {
              // ⬅️ PASO 2.1: "Matar a TODOS los Zombis" - Marcar TODAS las sesiones de este bot como offline
              // Esto incluye incluso la sesión actual, para luego marcarla como online de forma limpia
              await supabase
                  .from('session_heartbeats')
                  .update({'is_online': false})
                  .eq('bot_id', botId);
              
              // ⬅️ PASO 2.2: "Reclamar el Trono" - Insertar o Actualizar SOLO la sesión actual como activa
              await Future.delayed(const Duration(milliseconds: 100));
              
              await supabase
                  .from('session_heartbeats')
                  .upsert({
                    'session_id': currentSessionId,
                    'bot_id': botId,
                    'is_online': true,
                    'last_seen': _formatArgentinaTime(), // ⬅️ Hora de Argentina (UTC-3)
                    'chat_id': currentChatId,
                  }, onConflict: 'session_id');
              
              // ⬅️ PASO 2.3: Verificación final y limpieza agresiva
              await Future.delayed(const Duration(milliseconds: 200));
              
              final verification = await supabase
                  .from('session_heartbeats')
                  .select('session_id, is_online')
                  .eq('bot_id', botId)
                  .eq('is_online', true);
              
              if (verification.length > 1 || (verification.length == 1 && verification.first['session_id'] != currentSessionId)) {
                // Forzar limpieza nuevamente - más agresiva
                await supabase
                    .from('session_heartbeats')
                    .update({'is_online': false})
                    .eq('bot_id', botId)
                    .neq('session_id', currentSessionId);
                
                await Future.delayed(const Duration(milliseconds: 50));
                
                await supabase
                    .from('session_heartbeats')
                    .upsert({
                      'session_id': currentSessionId,
                      'bot_id': botId,
                      'is_online': true,
                      'last_seen': _formatArgentinaTime(), // ⬅️ Hora de Argentina (UTC-3)
                      'chat_id': currentChatId,
                    }, onConflict: 'session_id');
              }
            } catch (e) {
              // Error silenciado
            }
          })();
        } catch (e) {
          // Error silenciado
        }
      }
    });

    // ⬅️ LISTENER GLOBAL: Conectividad (se ejecuta incluso con chat cerrado).
    // Propaga el estado hacia el HTML contenedor (parent) para que pueda reaccionar.
    ref.listen(connectivityProvider, (prev, next) {
      if (!showOfflineAlert) return;
      next.whenData((online) {
        if (!online) {
          if (_wasNetworkOffline) return;
          _wasNetworkOffline = true;

          // Compatibilidad: mensaje string (contrato existente).
          html.window.parent?.postMessage('NETWORK_OFFLINE', '*');

          // Nuevo: payload estructurado para integraciones más ricas.
          html.window.parent?.postMessage({
            'source': 'botlode_player',
            'type': 'connectivity',
            'online': false,
            'botId': ref.read(currentBotIdProvider),
            'ts': DateTime.now().toIso8601String(),
          }, '*');
        } else {
          if (!_wasNetworkOffline) return;
          _wasNetworkOffline = false;

          html.window.parent?.postMessage('NETWORK_ONLINE', '*');
          html.window.parent?.postMessage({
            'source': 'botlode_player',
            'type': 'connectivity',
            'online': true,
            'botId': ref.read(currentBotIdProvider),
            'ts': DateTime.now().toIso8601String(),
          }, '*');
        }
      });
    });

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    // Altura aumentada: casi toda la pantalla, dejando espacio para appbar (80px)
    final double safeHeight = (screenSize.height - 80.0).clamp(600.0, double.infinity);

    const double ghostPadding = 40.0;

    // MouseRegion global que captura el mouse en TODA la pantalla
    // Calcula respecto a diferentes puntos según si el chat está abierto o cerrado
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (event) {
        final double dx;
        final double dy;
        
        if (isOpen) {
          // Chat ABIERTO: calcular respecto al avatar dentro del chat
          // El chat está en top con ancho máximo de 420px (o menos en móvil)
          final double chatWidth = isMobile ? screenSize.width : 420.0;
          
          // Avatar está centrado horizontalmente en el chat y a ~100px del top del chat (80px appbar + 100px)
          final double avatarCenterX = isMobile ? screenSize.width / 2 : screenSize.width - (chatWidth / 2);
          final double avatarCenterY = 80.0 + 100.0; // appbar + offset del avatar
          
          dx = event.position.dx - avatarCenterX;
          dy = event.position.dy - avatarCenterY;
        } else {
          // Chat CERRADO: calcular respecto al botón flotante
          final double headCenterX = screenSize.width - ghostPadding - 36.0;
          final double headCenterY = screenSize.height - ghostPadding - 36.0;
          
          dx = event.position.dx - headCenterX;
          dy = event.position.dy - headCenterY;
        }
        
        ref.read(pointerPositionProvider.notifier).state = Offset(dx, dy);
      },
      onExit: (_) {
        // Resetear cuando el mouse sale completamente
        ref.read(pointerPositionProvider.notifier).state = null;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        // PANEL DE CHAT - SIN ANIMACIONES (causan problema en iframe)
        // Posicionado desde arriba, dejando espacio para appbar (80px)
        if (isOpen)
          Positioned(
            top: 80, // Espacio para appbar
            right: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: safeHeight, 
                maxWidth: isMobile ? double.infinity : 420 // Ancho aumentado
              ),
              child: const SimpleChatTest(), // ⬅️ CHAT COMPLETO (ya tiene su propio Container con fondo)
            ),
          ),

        // ⬅️ OVERLAY: Detectar clicks fuera del chat para cerrarlo
        // Debe estar DESPUÉS del chat en el Stack para estar encima
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                // Calcular si el tap está dentro del área del chat
                final chatWidth = isMobile ? screenSize.width : 420.0;
                final chatLeft = screenSize.width - chatWidth;
                final chatTop = 80.0;
                final chatRight = screenSize.width;
                final chatBottom = chatTop + safeHeight;
                
                final tapX = details.localPosition.dx;
                final tapY = details.localPosition.dy;
                
                // Solo cerrar si el tap está FUERA del área del chat
                final isOutsideChat = tapX < chatLeft || 
                                      tapX > chatRight || 
                                      tapY < chatTop || 
                                      tapY > chatBottom;
                
                if (isOutsideChat) {
                  // Cerrar chat (el listener se encargará de resetear el mood)
                  ref.read(chatOpenProvider.notifier).set(false);
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // BURBUJA FLOTANTE
        Positioned(
          bottom: ghostPadding, right: ghostPadding,
          child: IgnorePointer(
            ignoring: isOpen, 
            child: MouseRegion(
              onEnter: (_) => ref.read(isHoveredExternalProvider.notifier).state = true,
              onExit: (_) => ref.read(isHoveredExternalProvider.notifier).state = false,
              child: AnimatedScale(
                scale: isOpen ? 0.0 : 1.0, 
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.center,
                child: botConfigAsync.when(
                  loading: () => _buildFloatingButton(isHovered: false, name: "...", color: Colors.grey, subtext: "...", isDarkMode: true),
                  error: (err, stack) => _buildFloatingButton(isHovered: false, name: "ERROR", color: Colors.red, subtext: "Offline", isDarkMode: true),
                  data: (config) => _buildFloatingButton(
                    isHovered: isHovered, 
                    name: config.name.toUpperCase(), 
                    color: config.themeColor,
                    subtext: "¿En qué te ayudo?",
                    isDarkMode: config.isDarkMode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required bool isHovered,
    required String name, 
    required Color color, 
    required String subtext,
    required bool isDarkMode,
  }) {
    const double closedSize = 72.0; 
    const double headSize = 58.0;    
    
    int maxChars = math.max(name.length, subtext.length);
    double calculatedWidth = 120.0 + (maxChars * 9.0);
    double targetWidth = isHovered ? calculatedWidth.clamp(220.0, 380.0) : closedSize;

    final Color textColor = _getContrastingTextColor(color);
    final Color subTextColor = textColor.withOpacity(0.85);

    return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic, 
        width: targetWidth, 
        height: closedSize, 
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(closedSize / 2),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ], 
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(closedSize / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(closedSize / 2),
            onTap: () {
              ref.read(chatOpenProvider.notifier).set(true);
              html.window.parent?.postMessage('CMD_OPEN', '*');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isHovered ? 1.0 : 0.0, 
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: isHovered 
                        ? Padding(
                            padding: const EdgeInsets.only(left: 25, right: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end, 
                              children: [
                                Text(
                                  name, 
                                  textAlign: TextAlign.right, 
                                  style: TextStyle(
                                    color: textColor, 
                                    fontWeight: FontWeight.w900, 
                                    fontSize: 15
                                  )
                                ),
                                Text(
                                  subtext, 
                                  textAlign: TextAlign.right, 
                                  style: TextStyle(
                                    color: subTextColor, 
                                    fontSize: 10
                                  )
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(), 
                    ), 
                  ),
                ),
                
                Container(
                  width: headSize, height: headSize,
                  margin: const EdgeInsets.all(7), 
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: Icon(Icons.smart_toy_rounded, color: textColor.withOpacity(0.5), size: 30)),
                        const FloatingHeadWidget(), 
                      ],
                    ),
                  ), 
                ),
              ],
            ),
          ),
        ),
    );
  }
}