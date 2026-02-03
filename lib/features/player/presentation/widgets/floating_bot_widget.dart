// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/core/services/presence_manager_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart'; // ⬅️ NUEVO: Para acceder a chatControllerProvider
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
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
    final isHoveredRaw = ref.watch(isHoveredExternalProvider);
    final hoverLocked = ref.watch(hoverLockedProvider);
    
    // ⬅️ CRÍTICO: El hover solo debe aplicarse cuando el chat está CERRADO Y no está bloqueado
    final isHovered = !isOpen && isHoveredRaw && !hoverLocked;
    
    // 🔍 DEBUG: Log de estados
    print('🔍 BUILD floating_bot_widget - isOpen: $isOpen, isHoveredRaw: $isHoveredRaw, hoverLocked: $hoverLocked, isHovered: $isHovered');

    final bool showOfflineAlert =
        botConfigAsync.asData?.value.showOfflineAlert ?? false;
    
    // ⬅️ LISTENER: Manejar estado cuando se abre/cierra el chat
    ref.listen(chatOpenProvider, (previous, next) {
      // ⬅️ Notificar al HTML padre para redimensionar el iframe
      if (next) {
        html.window.parent?.postMessage('CMD_OPEN', '*');
      } else {
        html.window.parent?.postMessage('CMD_CLOSE', '*');
      }
      
      // ⬅️ RESETEAR HOVER: Siempre que el chat cambie de estado (abre o cierra), resetear hover
      print('🔍 LISTENER chatOpenProvider - previous: $previous, next: $next, RESETEANDO HOVER a false');
      ref.read(isHoveredExternalProvider.notifier).state = false;
      print('🔍 HOVER después de reset: ${ref.read(isHoveredExternalProvider)}');
      
      // ⬅️ BLOQUEAR HOVER: Cuando el chat se cierra, bloquear hover hasta que el mouse salga
      if (previous == true && next == false) {
        ref.read(hoverLockedProvider.notifier).state = true;
        print('🔒 HOVER BLOQUEADO - El mouse debe salir de la burbuja para reactivar hover');
      }
      
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

    // ⬅️ Enviar showOfflineAlert al HTML cuando la config del bot esté disponible (para que el padre muestre/oculte snackbars).
    ref.listen(botConfigProvider, (prev, next) {
      final show = next.asData?.value.showOfflineAlert ?? false;
      try {
        html.window.parent?.postMessage({
          'type': 'BOT_CONFIG',
          'showOfflineAlert': show,
        }, '*');
      } catch (_) {}
    });

    // ⬅️ LISTENER GLOBAL: Conectividad (se ejecuta incluso con chat cerrado).
    // Propaga el estado hacia el HTML contenedor (parent) para que pueda reaccionar.
    ref.listen(connectivityProvider, (prev, online) {
      if (!showOfflineAlert) return;
      if (!online) {
        if (_wasNetworkOffline) return;
        _wasNetworkOffline = true;
        html.window.parent?.postMessage('NETWORK_OFFLINE', '*');
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

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    
    // ⬅️ NUEVO: Altura completa de pantalla para el chat (sin espacio para appbar)
    final double chatHeight = screenSize.height;
    // ⬅️ NUEVO: Ancho del chat lateral (420px desktop, pantalla completa móvil)
    final double chatWidth = isMobile ? screenSize.width : 420.0;

    const double ghostPadding = 40.0;

    // MouseRegion global: enviamos posición GLOBAL (event.position) al provider.
    // rive_avatar y HeadTrackingController esperan coordenadas globales y calculan
    // el centro del widget con RenderBox; si pasamos deltas aquí, el RIV no sigue bien el mouse.
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (event) {
        ref.read(pointerPositionProvider.notifier).state = event.position;
      },
      onExit: (_) {
        ref.read(pointerPositionProvider.notifier).state = null;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        // ⬅️ OVERLAY OSCURO: Aparece cuando el chat está abierto
        // Cubre toda la pantalla con un fondo semitransparente
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isOpen ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Cerrar chat cuando se hace clic en el overlay
                ref.read(chatOpenProvider.notifier).set(false);
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
        ),

        // PANEL DE CHAT - Deslizamiento lateral desde la derecha
        // ✅ Animación coordinada con el iframe: primero se expande el iframe (200ms), luego desliza el chat
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: isOpen ? Curves.easeOutCubic : Curves.easeInCubic,
          top: 0,
          right: isOpen ? 0 : -chatWidth, // ⬅️ Desliza desde fuera de la pantalla
          child: SizedBox(
            width: chatWidth,
            height: chatHeight,
            child: IgnorePointer(
              ignoring: !isOpen,
              child: const ChatPanelView(),
            ),
          ),
        ),

        // BURBUJA FLOTANTE
        // ✅ NUEVO: Siempre visible en la esquina inferior derecha (oculta cuando el chat está abierto)
        Positioned(
          bottom: ghostPadding, 
          right: ghostPadding,
          child: IgnorePointer(
            ignoring: isOpen, 
            child: MouseRegion(
              onEnter: (_) {
                final hoverLocked = ref.read(hoverLockedProvider);
                print('🔍 MouseRegion ENTER - isOpen: $isOpen, hoverLocked: $hoverLocked');
                // ⬅️ Solo activar hover si no está bloqueado
                if (!hoverLocked) {
                  ref.read(isHoveredExternalProvider.notifier).state = true;
                  print('🔍 MouseRegion ENTER - hover activado: ${ref.read(isHoveredExternalProvider)}');
                } else {
                  print('🔒 MouseRegion ENTER - hover bloqueado, no se activa');
                }
              },
              onExit: (_) {
                final hoverLocked = ref.read(hoverLockedProvider);
                print('🔍 MouseRegion EXIT - isOpen: $isOpen, hoverLocked: $hoverLocked');
                ref.read(isHoveredExternalProvider.notifier).state = false;
                // ⬅️ Desbloquear hover cuando el mouse sale
                if (hoverLocked) {
                  ref.read(hoverLockedProvider.notifier).state = false;
                  print('🔓 HOVER DESBLOQUEADO - Ahora el hover puede activarse nuevamente');
                }
                print('🔍 MouseRegion EXIT - hover ahora: ${ref.read(isHoveredExternalProvider)}');
              },
              child: AnimatedScale(
                scale: isOpen ? 0.0 : 1.0, 
                duration: const Duration(milliseconds: 250),
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
    const double closedSize = 86.0; 
    const double headSize = 70.0;    
    
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