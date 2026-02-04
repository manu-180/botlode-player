// ULTRA SIMPLE - Burbuja + Chat COMPLEJO (chat_panel_view) para testing
import 'dart:html' as html;
import 'package:botlode_player/core/config/supabase_provider.dart';
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/core/services/presence_manager.dart';
import 'package:botlode_player/core/services/presence_manager_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/whatsapp_button.dart';
import 'package:flutter/foundation.dart';
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
  bool _wasNetworkOffline = false; // ⬅️ Para enviar NETWORK_OFFLINE/ONLINE al padre solo una vez por transición
  PresenceManager? _presenceManager; // ⬅️ NUEVO: Mantener referencia al manager
  bool _lastKnownOpenState = false; // ⬅️ NUEVO: Trackear último estado conocido
  
  // ⬅️ ANIMACIÓN PRO: Controlar visibilidad para que la animación de cierre se vea
  bool _shouldRenderChat = false; // Controla si el chat está en el árbol de widgets
  
  // ⬅️ ANIMACIÓN PROFESIONAL: Controller para animación personalizada
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _borderRadiusAnimation;

  @override
  void initState() {
    super.initState();
    
    // ⬅️ ANIMACIÓN PROFESIONAL: Inicializar controller con duración más fluida
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // ⬅️ Animación de escala: Crece sutilmente (no desde burbuja, solo zoom ligero)
    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    
    // ⬅️ Animación de fade: Aparece suavemente
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));
    
    // ⬅️ Animación de slide: Entra desde la DERECHA (fuera de pantalla) hacia la izquierda
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 100% hacia la derecha (fuera de pantalla)
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart, // Curva muy fluida y profesional
    ));
    
    // ⬅️ Animación de borderRadius: Siempre redondeado (sin morphing desde círculo)
    _borderRadiusAnimation = Tween<double>(
      begin: 28.0, // Ya empieza con el radio del chat
      end: 28.0,   // Se mantiene igual
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    
    // ⬅️ Pre-inicializar providers necesarios para PresenceManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // 1. Asegurar que chatControllerProvider esté inicializado (necesario para sessionId)
        ref.read(chatControllerProvider);
        
        // ⬅️ CRÍTICO: Enviar configuración de showOfflineAlert al HTML padre INMEDIATAMENTE
        // Esto asegura que el script botlode-connectivity.js tenga la configuración antes de cualquier evento de conectividad
        Future.microtask(() {
          try {
            final botConfig = ref.read(botConfigProvider).asData?.value;
            if (botConfig != null) {
              html.window.parent?.postMessage({
                'type': 'BOT_CONFIG',
                'showOfflineAlert': botConfig.showOfflineAlert,
              }, '*');
            }
          } catch (e) {
            // Error silenciado
          }
        });
        
        // ⬅️ NUEVO: Si el chat ya está abierto al inicializar, marcar como online y renderizar
        if (ref.read(chatOpenProvider)) {
          setState(() => _shouldRenderChat = true);
          _animationController.value = 1.0; // Saltar animación si ya está abierto
          Future.microtask(() {
            try {
              final manager = ref.read(presenceManagerProvider);
              manager.setOnline();
            } catch (e) {
              // Error silenciado
            }
          });
        }
        
        // ⬅️ Estado inicial de WhatsApp para ajustar tamaño del iframe
        Future.microtask(() => _sendWppVisibility(ref));
      } catch (e) {
        // Error silenciado
      }
    });
  }

  @override
  void dispose() {
    // ⬅️ NUEVO: Asegurar que se marque como offline al dispose del widget
    _presenceManager?.setOffline();
    _animationController.dispose();
    super.dispose();
  }

  void _sendWppVisibility(WidgetRef ref) {
    try {
      final isOpen = ref.read(chatOpenProvider);
      final botConfig = ref.read(botConfigProvider).asData?.value;
      final showWpp = !isOpen && 
          botConfig != null && 
          botConfig.wpp && 
          botConfig.telefono != null && 
          botConfig.telefono!.isNotEmpty;
      html.window.parent?.postMessage(
        showWpp ? 'CMD_WPP_VISIBLE' : 'CMD_WPP_HIDDEN',
        '*',
      );
    } catch (_) {}
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
    
    // ⬅️ Enviar CMD_WPP_VISIBLE/HIDDEN para que el HTML ajuste el tamaño del iframe
    ref.listen(chatOpenProvider, (prev, isOpen) {
      _sendWppVisibility(ref);
    });
    ref.listen(botConfigProvider, (prev, next) {
      _sendWppVisibility(ref);
    });
    
    // ⬅️ Enviar showOfflineAlert al HTML cuando la config del bot esté disponible (widget activo = UltraSimpleBot).
    // Así la página padre puede ocultar los snackbars si el bot tiene show_offline_alert = false.
    ref.listen(botConfigProvider, (prev, next) {
      final show = next.asData?.value.showOfflineAlert ?? false;
      try {
        html.window.parent?.postMessage({
          'type': 'BOT_CONFIG',
          'showOfflineAlert': show,
        }, '*');
        
        if (kDebugMode) {
          print('🛰 [Config] Enviado BOT_CONFIG al HTML padre: showOfflineAlert=$show');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [Config] Error al enviar BOT_CONFIG: $e');
        }
      }
    });

    // ⬅️ LISTENER GLOBAL: Conectividad (se ejecuta aunque el chat esté cerrado).
    // Solo envía NETWORK_OFFLINE/NETWORK_ONLINE al padre si en la tabla del bot show_offline_alert = true.
    // ⚠️ CRÍTICO: Este listener funciona tanto en modo burbuja como con chat abierto
    ref.listen(connectivityProvider, (prev, online) {
      final showOfflineAlert = ref.read(botConfigProvider).asData?.value.showOfflineAlert ?? false;
      
      // ⬅️ DEBUG: Log para verificar detección de cambio de conectividad
      if (kDebugMode) {
        print('🛰 [Conectividad] Estado: ${online ? "ONLINE" : "OFFLINE"}, showOfflineAlert: $showOfflineAlert, chatOpen: $isOpen');
      }
      
      if (!showOfflineAlert) return;
      
      try {
        if (!online) {
          if (_wasNetworkOffline) return;
          _wasNetworkOffline = true;
          
          // ⬅️ CRÍTICO: Enviar mensaje al HTML padre para que muestre el snackbar
          // Esto funciona incluso cuando el iframe es pequeño (modo burbuja 140x140px)
          // ⬅️ Solo enviar un mensaje para evitar llamadas duplicadas
          html.window.parent?.postMessage({
            'type': 'connectivity',
            'online': false,
            'source': 'botlode_player',
          }, '*');
          
          if (kDebugMode) {
            print('🛰 [Conectividad] Enviado mensaje NETWORK_OFFLINE al HTML padre');
          }
        } else {
          if (!_wasNetworkOffline) return;
          _wasNetworkOffline = false;
          
          // ⬅️ Solo enviar un mensaje para evitar llamadas duplicadas a showOnline()
          html.window.parent?.postMessage({
            'type': 'connectivity',
            'online': true,
            'source': 'botlode_player',
          }, '*');
          
          if (kDebugMode) {
            print('🛰 [Conectividad] Enviado mensaje NETWORK_ONLINE al HTML padre');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [Conectividad] Error al enviar mensaje al HTML padre: $e');
        }
      }
    });

    // ⬅️ Sincronizar estado online/offline con el historial
    ref.listen(chatOpenProvider, (previous, current) {
      // ⬅️ Solo procesar si el estado realmente cambió
      if (previous == current) return;
      
      // ⬅️ ANIMACIÓN PRO: Controlar cuándo el chat está en el árbol de widgets
      if (current) {
        // Abrir: inmediatamente renderizar para que la animación de entrada se vea
        setState(() => _shouldRenderChat = true);
        // Iniciar animación de apertura
        _animationController.forward();
      } else {
        // Cerrar: iniciar animación de cierre
        _animationController.reverse();
        // Esperar a que termine la animación (500ms) antes de quitar del árbol
        Future.delayed(const Duration(milliseconds: 500), () {
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
          // ⬅️ ANIMACIÓN PROFESIONAL: Morphing desde burbuja hasta chat completo
          if (_shouldRenderChat)
          Positioned(
              bottom: 0,
              right: 0,
              left: isMobile ? 0 : null, // ⬅️ En móvil, ocupar todo el ancho disponible
              child: Padding(
                padding: EdgeInsets.only(
                  right: horizontalPadding, 
                  bottom: verticalPadding,
                  left: isMobile ? horizontalPadding : 0,
                  top: isMobile ? 40.0 : 0,
                ),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          alignment: Alignment.centerRight, // ⬅️ Crece desde el centro-derecha (fluido)
                          child: IgnorePointer(
                            ignoring: !isOpen || _animationController.isAnimating,
                            child: GestureDetector(
                              onTap: () {}, // Detener propagación
                              child: Container(
                                width: chatWidth,
                                height: chatHeight,
                                constraints: BoxConstraints(
                                  maxWidth: chatWidth,
                                  maxHeight: chatHeight,
                                  minWidth: isMobile ? 320.0 : 380.0,
                                  minHeight: 400.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181818),
                                  // ⬅️ BorderRadius animado: morfea de círculo a rectángulo redondeado
                                  borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4 * _fadeAnimation.value),
                                      blurRadius: 25 * _fadeAnimation.value,
                                      offset: Offset(-5 * _fadeAnimation.value, 0),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  // ⬅️ BorderRadius animado también en el clip
                                  borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
                                  child: Opacity(
                                    // ⬅️ Fade del contenido interno: aparece gradualmente con un pequeño delay
                                    opacity: ((_animationController.value - 0.2) / 0.8).clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const ChatPanelView(),
                ),
              ),
          ),

          // BURBUJA FLOTANTE + cartel "Sin conexión" encima cuando chat cerrado y offline
            Positioned(
              bottom: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              right: isMobile ? 16.0 : 40.0, // ⬅️ RESPONSIVE: Menos espacio en móvil
              child: AnimatedScale(
                scale: isOpen ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: isOpen ? Curves.easeInCubic : Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: isOpen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
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
              ),
            ),

          // ⬅️ BOTÓN DE WHATSAPP (arriba de la burbuja del bot)
          Consumer(
            builder: (context, ref, _) {
              final botConfig = ref.watch(botConfigProvider).asData?.value;
              
              // Solo mostrar si wpp está habilitado, hay un teléfono y el chat está cerrado
              if (botConfig == null || 
                  !botConfig.wpp || 
                  botConfig.telefono == null || 
                  botConfig.telefono!.isEmpty ||
                  isOpen) {
                return const SizedBox.shrink();
              }
              
              // ⬅️ Posicionar arriba de la burbuja del bot con separación generosa
              // Burbuja bot: bottom: 40px, size: 80px
              // Separación: 16px entre burbujas
              // WhatsApp button: size: 64px
              // Cálculo: 40 (base) + 80 (burbuja) + 16 (separación) = 136px
              return Positioned(
                bottom: isMobile ? 112.0 : 136.0, 
                right: isMobile ? 24.0 : 48.0, // Centrado con la burbuja
                child: AnimatedScale(
                  scale: isOpen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: isOpen ? Curves.easeInCubic : Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: isOpen ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Visibility(
                      visible: !isOpen,
                      maintainState: true,
                      child: WhatsAppButton(
                        phoneNumber: botConfig.telefono!,
                        isDarkMode: botConfig.isDarkMode,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ⬅️ OVERLAY DESHABILITADO: Solo usamos el snackbar del HTML padre (centro de pantalla)
          // El GlobalConnectivityOverlay era redundante con el snackbar
          // const GlobalConnectivityOverlay(),
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
        
        const double bubbleSize = 80.0; // Tamaño fijo de la burbuja
        const double headSize = 68.0; // Tamaño del avatar
        
        // ⬅️ NUEVA ESTRATEGIA: Scale en lugar de expandir horizontalmente
        final double targetScale = _isHovered ? 1.1 : 1.0; // 10% más grande en hover
        final double targetBlur = _isHovered ? 15.0 : 10.0; // Shadow más pronunciado en hover
        
        // ⬅️ COLORES ADAPTATIVOS según tema
        final bubbleColor = isDarkMode 
            ? const Color(0xFF2A2A3E)
            : const Color(0xFF4A4A5E);
        
        final borderColor = isDarkMode
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.2);
        
        return AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: () => ref.read(chatOpenProvider.notifier).set(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: bubbleSize,
              height: bubbleSize,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(bubbleSize / 2),
                border: Border.all(
                  color: borderColor,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.15),
                    blurRadius: targetBlur,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(bubbleSize / 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(bubbleSize / 2),
                  onTap: () => ref.read(chatOpenProvider.notifier).set(true),
                  child: Center(
                    child: Container(
                      width: headSize,
                      height: headSize,
                      child: ClipOval(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final riveLoader = ref.watch(riveHeadFileLoaderProvider); 
                            
                            return riveLoader.when(
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
                  ),
                ),
              ),
            ),
          ),
        );

      },
    );
  }
}