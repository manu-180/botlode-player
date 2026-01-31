// ULTRA SIMPLE - Burbuja + Chat COMPLEJO (chat_panel_view) para testing
import 'dart:html' as html;
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/services/presence_manager.dart';
import 'package:botlode_player/core/services/presence_manager_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/global_connectivity_overlay.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider simple - Usar directamente chatOpenProvider para evitar desincronización
// ⬅️ NOTA: isOpenSimpleProvider ahora es solo un alias para chatOpenProvider
final isOpenSimpleProvider = StateProvider<bool>((ref) => false);

// ⬅️ Helper para formatear hora de Argentina (UTC-3) sin zona horaria
String _formatArgentinaTime() {
  final nowLocal = DateTime.now().toLocal();
  final nowArgentina = nowLocal.subtract(const Duration(hours: 3));
  return '${nowArgentina.year}-${nowArgentina.month.toString().padLeft(2, '0')}-${nowArgentina.day.toString().padLeft(2, '0')}T${nowArgentina.hour.toString().padLeft(2, '0')}:${nowArgentina.minute.toString().padLeft(2, '0')}:${nowArgentina.second.toString().padLeft(2, '0')}.${nowArgentina.millisecond.toString().padLeft(3, '0')}';
}

class UltraSimpleBot extends ConsumerStatefulWidget {
  const UltraSimpleBot({super.key});

  @override
  ConsumerState<UltraSimpleBot> createState() => _UltraSimpleBotState();
}

class _UltraSimpleBotState extends ConsumerState<UltraSimpleBot> 
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  PresenceManager? _presenceManager; // ⬅️ NUEVO: Mantener referencia al manager
  bool _lastKnownOpenState = false; // ⬅️ NUEVO: Trackear último estado conocido
  
  // ⬅️ ANIMACIÓN PRO: Controlar visibilidad para que la animación de cierre se vea
  bool _shouldRenderChat = false; // Controla si el chat está en el árbol de widgets

  @override
  void initState() {
    super.initState();
    // ⬅️ Pre-inicializar providers necesarios para PresenceManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // 1. Asegurar que chatControllerProvider esté inicializado (necesario para sessionId)
        ref.read(chatControllerProvider);
        
        // ⬅️ NUEVO: Si el chat ya está abierto al inicializar, marcar como online y renderizar
        if (ref.read(chatOpenProvider)) {
          setState(() => _shouldRenderChat = true);
          Future.microtask(() {
            try {
              final manager = ref.read(presenceManagerProvider);
              manager.setOnline();
            } catch (e) {
              // Error silenciado
            }
          });
        }
      } catch (e) {
        // Error silenciado
      }
    });
  }

  @override
  void dispose() {
    // ⬅️ NUEVO: Asegurar que se marque como offline al dispose del widget
    _presenceManager?.setOffline();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ CRÍTICO: Usar chatOpenProvider directamente para que StatusIndicator funcione correctamente
    final isOpen = ref.watch(chatOpenProvider);
    final screenSize = MediaQuery.of(context).size;
    
    // ⬅️ CRÍTICO: Usar ref.watch() para mantener el provider vivo mientras el widget esté montado
    // Esto evita que se dispose inmediatamente después de usarlo
    final presenceManager = ref.watch(presenceManagerProvider);
    _presenceManager = presenceManager; // Actualizar referencia
    
    // ⬅️ Enviar showOfflineAlert al HTML cuando la config del bot esté disponible (widget activo = UltraSimpleBot).
    // Así la página padre puede ocultar los snackbars si el bot tiene show_offline_alert = false.
    ref.listen(botConfigProvider, (prev, next) {
      final show = next.asData?.value.showOfflineAlert ?? false;
      try {
        html.window.parent?.postMessage({
          'type': 'BOT_CONFIG',
          'showOfflineAlert': show,
        }, '*');
      } catch (_) {}
    });

    // ⬅️ Sincronizar estado online/offline con el historial
    ref.listen(chatOpenProvider, (previous, current) {
      // ⬅️ Solo procesar si el estado realmente cambió
      if (previous == current) return;
      
      // ⬅️ ANIMACIÓN PRO: Controlar cuándo el chat está en el árbol de widgets
      if (current) {
        // Abrir: inmediatamente renderizar para que la animación de entrada se vea
        setState(() => _shouldRenderChat = true);
      } else {
        // Cerrar: esperar a que termine la animación (450ms) antes de quitar del árbol
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && !ref.read(chatOpenProvider)) {
            setState(() => _shouldRenderChat = false);
          }
        });
      }
      
      if (previous == true && current == false) {
        // Chat se cerró: Invalidar activeSessionId SÍNCRONAMENTE y marcar TODOS los chats como offline en BD
        // ⚠️ CRÍTICO: Debe hacerse SÍNCRONAMENTE, no en un Future.microtask
        ref.read(activeSessionIdProvider.notifier).state = null;
        
        // ⬅️ CRÍTICO: Marcar como offline en BD INMEDIATAMENTE (sin debounce)
        // Esto evita que otros chats vean este chat como online cuando se consulta la BD
        try {
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
      } else if (previous == false && current == true) {
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
              // ⚠️ CRÍTICO: Hacer esto PRIMERO antes de que PresenceManager.setOnline() se ejecute
              await supabase
                  .from('session_heartbeats')
                  .update({'is_online': false})
                  .eq('bot_id', botId);
              
              // ⬅️ PASO 2.2: "Reclamar el Trono" - Insertar o Actualizar SOLO la sesión actual como activa
              // Esperar un pequeño delay para asegurar que el UPDATE anterior se complete
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
              
              // ⬅️ PASO 2.3: Verificación final y limpieza agresiva - Asegurar que ningún otro chat esté online
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
      
      // ⬅️ CRÍTICO: NO usar PresenceManager.setOnline() cuando se abre el chat
      // La reclamación de sesión ya se hizo directamente en la BD en el bloque anterior.
      // PresenceManager solo se usa para los heartbeats periódicos, no para activar/desactivar.
      // Esto evita que múltiples PresenceManagers (de chats viejos) interfieran.
      Future.microtask(() async {
        try {
          if (current) {
            // ⬅️ NO llamar a setOnline() aquí - la reclamación de sesión ya se hizo
            // Solo iniciar el heartbeat periódico DESPUÉS de que la reclamación se complete
            await Future.delayed(const Duration(milliseconds: 500));
            
            print("🟢 Chat Abierto (UltraSimple) -> Iniciando heartbeat periódico (reclamación ya completada)");
            // ⬅️ Solo iniciar el heartbeat, pero NO actualizar is_online (ya está actualizado por la reclamación)
            presenceManager.setOnline();
            _lastKnownOpenState = true;
          } else {
            print("🔴 Chat Cerrado (UltraSimple) -> Enviando OFFLINE");
            presenceManager.setOffline();
            _lastKnownOpenState = false;
          }
        } catch (e) {
          print("⚠️ Error al acceder a PresenceManager (UltraSimple): $e");
        }
      });
    });
    
    // ⬅️ NUEVO: Verificar estado inicial - si el chat está abierto y aún no se ha marcado
    if (isOpen && !_lastKnownOpenState) {
      Future.microtask(() {
        try {
          presenceManager.setOnline();
          _lastKnownOpenState = true;
        } catch (e) {
          // Error silenciado
        }
      });
    }
    
    // ⬅️ RESPONSIVE: Detectar móvil y calcular dimensiones seguras
    final bool isMobile = screenSize.width < 600;
    final double chatWidth = isMobile 
        ? (screenSize.width - 16).clamp(320.0, 380.0) // Móvil: ancho disponible - padding, min 320px
        : 380.0; // Desktop: fijo 380px
    
    final double horizontalPadding = isMobile ? 8.0 : 28.0; // Menos padding en móvil
    final double verticalPadding = isMobile ? 8.0 : 28.0;
    
    // ⬅️ Altura generosa: casi toda la pantalla para que el chat no quede petiso
    // - Usa 98% de la altura disponible
    // - Máximo 1400px para pantallas muy altas
    // - Mínimo 480px para pantallas pequeñas
    final double maxAvailableHeight = screenSize.height - 24.0; // Margen mínimo
    final double calculatedHeight = (maxAvailableHeight * 0.98) - (verticalPadding * 2);
    final double chatHeight = calculatedHeight.clamp(480.0, 1400.0);
    
    // ⬅️ Fondo transparente; zona fuera del chat deja pasar scroll/touch para scrollear la página
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zona que deja pasar eventos para scrollear la página de fondo
          Positioned.fill(
            child: IgnorePointer(
              child: const SizedBox.expand(),
            ),
          ),
          // CHAT (solo esta zona absorbe toques; fuera se puede scrollear)
          // ⬅️ ANIMACIÓN PRO: Usar _shouldRenderChat para mantener el widget durante la animación de cierre
          if (_shouldRenderChat)
          Positioned(
              bottom: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                offset: isOpen ? Offset.zero : const Offset(1.2, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  opacity: isOpen ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !isOpen, // ⬅️ Ignorar toques durante animación de cierre
                    child: Visibility(
                    visible: _shouldRenderChat,
                    maintainState: true,
                    child: GestureDetector(
                      // ⬅️ NUEVO: Detener propagación de clics dentro del chat
                      onTap: () {}, // No hacer nada, solo detener propagación
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: horizontalPadding, 
                          bottom: verticalPadding,
                          left: isMobile ? horizontalPadding : 0, // ⬅️ Padding izquierdo en móvil
                          top: isMobile ? 40.0 : 0, // ⬅️ Padding superior en móvil (margen seguro para appbar)
                        ),
                        child: Container(
                        width: chatWidth, // ⬅️ RESPONSIVE: Ancho adaptativo
                        height: chatHeight, // ⬅️ RESPONSIVE: Altura generosa (98% pantalla, max 1400px)
                        constraints: BoxConstraints(
                          maxWidth: chatWidth, // ⬅️ Asegurar que nunca exceda el ancho calculado
                          maxHeight: chatHeight, // ⬅️ Asegurar que nunca exceda la altura calculada
                          minWidth: isMobile ? 320.0 : 380.0, // ⬅️ Ancho mínimo
                          minHeight: 400.0, // ⬅️ Altura mínima (nunca se corta)
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(-5, 0),
                            ),
                          ],
                        ),
                        child: const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(28)),
                          child: ChatPanelView(), // ⬅️ Un solo X de cierre en el header (chat_panel_view)
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ),

          // BURBUJA FLOTANTE
            Positioned(
              bottom: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              right: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              child: Visibility(
                visible: !isOpen,
                maintainState: true,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final botConfig = ref.watch(botConfigProvider);
                      
                      return botConfig.when(
                        data: (config) => _buildExpandableBubble(
                          name: config.name.toUpperCase(),
                          subtext: "¿En qué te ayudo?",
                        ),
                        loading: () => _buildExpandableBubble(
                          name: "CARGANDO...",
                          subtext: "",
                        ),
                        error: (_, __) => _buildExpandableBubble(
                          name: "BOT",
                          subtext: "Haz click para abrir",
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // ⬅️ OVERLAY GLOBAL DE CONECTIVIDAD (full-screen, incluso con chat cerrado)
          const GlobalConnectivityOverlay(),
        ],
      ),
    );
  }

  Widget _buildExpandableBubble({
    required String name,
    required String subtext,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final botConfig = ref.watch(botConfigProvider);
        final isDarkMode = botConfig.asData?.value.isDarkMode ?? true;
        
        const double closedSize = 80.0; // ⬅️ Aumentado de 72 a 80
        const double headSize = 68.0; // ⬅️ Aumentado de 58 a 68
        const double padding = 25.0; 
        const double extraSpace = 40.0; 
        
        double textWidth = _calculateTextWidth(name, const TextStyle(fontSize: 15, fontWeight: FontWeight.w900));
        double subtextWidth = _calculateTextWidth(subtext, const TextStyle(fontSize: 10));
        double maxTextWidth = textWidth > subtextWidth ? textWidth : subtextWidth;
        
        double expandedWidth = headSize + padding + maxTextWidth + extraSpace;
        double targetWidth = _isHovered ? expandedWidth : closedSize;
        
        // ⬅️ COLORES ADAPTATIVOS según tema (sutil pero profesional)
        // ESTRATEGIA: Mantener identidad visual (burbuja oscura) pero optimizar contraste
        final bubbleColor = isDarkMode 
            ? const Color(0xFF2A2A3E)  // Dark: Mantener el color actual (te gusta)
            : const Color(0xFF4A4A5E); // Light: Un poco más claro para mejor contraste, pero mantiene identidad oscura
        
        final borderColor = isDarkMode
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.2); // Light: Borde más visible para definir mejor la burbuja
        
        // ⬅️ CRÍTICO: Texto siempre claro para máximo contraste con burbuja oscura
        // Esto garantiza legibilidad perfecta en ambos modos manteniendo la identidad visual
        final textColor = Colors.white; // Siempre blanco para contraste óptimo
        final subtextColor = Colors.white.withOpacity(0.85); // Subtexto con opacidad sutil
        
        return GestureDetector(
          onTap: () => ref.read(chatOpenProvider.notifier).set(true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: targetWidth,
            height: closedSize,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(closedSize / 2),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(closedSize / 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(closedSize / 2),
                onTap: () => ref.read(chatOpenProvider.notifier).set(true),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isHovered)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: padding, right: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: textColor, // ⬅️ Siempre blanco para contraste óptimo
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtext.isNotEmpty)
                                Text(
                                  subtext,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: subtextColor, // ⬅️ Blanco con opacidad para jerarquía visual
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    
                    Container(
                      width: headSize,
                      height: headSize,
                      margin: const EdgeInsets.all(7),
                      child: ClipOval(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final riveLoader = ref.watch(riveHeadFileLoaderProvider); 
                            
                            return riveLoader.when(
                              // ⬅️ PASO 2: Aquí pasamos isBubble: true
                              data: (_) => const BotAvatarWidget(isBubble: true),
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, __) => const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      },
    );
  }

  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    
    return textPainter.width;
  }
}