// PASO 3.7: Mensajes reales + Envío funcional
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/chat_bubble.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleChatTest extends ConsumerStatefulWidget {
  const SimpleChatTest({super.key});

  @override
  ConsumerState<SimpleChatTest> createState() => _SimpleChatTestState();
}

class _SimpleChatTestState extends ConsumerState<SimpleChatTest> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _getMoodIndex(String mood) {
    switch (mood.toLowerCase()) {
      case 'angry': return 1;
      case 'happy': return 2;
      case 'sales': return 3;
      case 'confused': return 4;
      case 'tech': return 5;
      case 'neutral': default: return 0;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    
    // ⬅️ CRÍTICO: Marcar este chat como activo INMEDIATAMENTE y de forma SÍNCRONA
    // Esto debe hacerse ANTES de enviar el mensaje para que el chat viejo deje de mostrar "EN LÍNEA"
    final chatState = ref.read(chatControllerProvider);
    final currentSessionId = chatState.sessionId;
    
    // ⬅️ Actualizar activeSessionId SÍNCRONAMENTE (no async)
    ref.read(activeSessionIdProvider.notifier).state = currentSessionId;
    print("🟡 [SimpleChatTest] _sendMessage() - activeSessionId actualizado a: $currentSessionId (este chat es ahora el activo)");
    
    // ⬅️ Enviar mensaje (esto puede crear un nuevo chat si hay persistencia)
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    
    // ⬅️ Verificar que el activeSessionId sigue siendo el correcto después de enviar
    // (por si se creó un nuevo chat durante el envío)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stateAfterSend = ref.read(chatControllerProvider);
      final activeSessionId = ref.read(activeSessionIdProvider);
      
      // Si el sessionId cambió durante el envío (nuevo chat creado), actualizar activeSessionId
      if (stateAfterSend.sessionId != activeSessionId) {
        print("🟡 [SimpleChatTest] _sendMessage() - sessionId cambió durante envío: ${stateAfterSend.sessionId} != $activeSessionId");
        ref.read(activeSessionIdProvider.notifier).state = stateAfterSend.sessionId;
        print("🟡 [SimpleChatTest] _sendMessage() - activeSessionId actualizado al nuevo: ${stateAfterSend.sessionId}");
      }
      
      // Auto-scroll después de enviar mensaje
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    // DEBUG: Observar el estado del loader
    final riveLoader = ref.watch(riveFileLoaderProvider);
    
    // PRINT CONDICIONAL DETALLADO
    if (riveLoader.hasValue) {
      print('🟢 RIVE LOADER: ✅ LOADED SUCCESSFULLY');
    } else if (riveLoader.isLoading) {
      print('🟡 RIVE LOADER: ⏳ LOADING... (WASM puede estar bloqueado)');
    } else if (riveLoader.hasError) {
      print('🔴 RIVE LOADER: ❌ ERROR: ${riveLoader.error}');
      print('📍 STACK: ${riveLoader.stackTrace}');
    }
    
    // DEBUG CONSOLA WEB
    print('🔍 RIVE LOADER STATE TYPE: ${riveLoader.runtimeType}');
    print('🔍 hasValue: ${riveLoader.hasValue} | isLoading: ${riveLoader.isLoading} | hasError: ${riveLoader.hasError}');
    
    // ✅ CHAT STATE REAL
    final chatState = ref.watch(chatControllerProvider);
    final reversedMessages = chatState.messages.reversed.toList();
    
    // ⬅️ Inicializar activeSessionId si no está establecido (primera vez)
    // ⚠️ IMPORTANTE: Solo inicializar si no hay un activeSessionId establecido
    // Si hay un activeSessionId pero no coincide con el chat actual, NO cambiarlo
    // (esto previene que chats viejos se vuelvan activos automáticamente)
    final activeSessionId = ref.watch(activeSessionIdProvider);
    if (activeSessionId == null || activeSessionId.isEmpty) {
      // Solo inicializar si realmente no hay un chat activo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentActiveSessionId = ref.read(activeSessionIdProvider);
        if (currentActiveSessionId == null || currentActiveSessionId.isEmpty) {
          ref.read(activeSessionIdProvider.notifier).state = chatState.sessionId;
          print("🟡 [SimpleChatTest] build() - activeSessionId inicializado a: ${chatState.sessionId}");
        }
      });
    }
    
    // ✅ LISTENER: Sincronizar mood del avatar con el estado del chat
    ref.listen(chatControllerProvider, (prev, next) {
      if (prev?.currentMood != next.currentMood) {
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
      }
      
      // Auto-scroll cuando llegan mensajes nuevos
      final hasNewMessage = next.messages.length > (prev?.messages.length ?? 0);
      // También hacer scroll cuando termina de cargar (el bot respondió)
      final finishedLoading = prev?.isLoading == true && next.isLoading == false;
      
      if ((hasNewMessage || finishedLoading) && _scrollController.hasClients) {
        // Verificar si el usuario está cerca del final (dentro de 100px)
        // Si está scrolleando hacia arriba viendo mensajes antiguos, no forzar scroll
        final isNearBottom = _scrollController.offset < 100.0;
        
        // Solo hacer auto-scroll si está cerca del final o si es un mensaje del bot (siempre mostrar respuestas del bot)
        final isBotMessage = hasNewMessage && next.messages.isNotEmpty && 
                             next.messages.last.role == 'bot';
        
        if (isNearBottom || isBotMessage || finishedLoading) {
          // Usar addPostFrameCallback para asegurar que el scroll ocurra después del render
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              // Con reverse: true, el índice 0 está al final (abajo), así que scroll a 0.0 muestra el más nuevo
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
    
    // Configuración de colores (hardcoded por ahora)
    const Color bgColor = Color(0xFF181818);
    const Color inputFill = Color(0xFF2C2C2C);
    const Color borderColor = Colors.white24;
    const Color themeColor = Color(0xFFFFC000);
    const bool isDarkMode = true;
    
    // Conectividad real desde provider
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    return GestureDetector(
      // Consumir todos los taps dentro del chat para que no se propaguen al overlay
      onTap: () {
        // No hacer nada, solo consumir el tap
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Material(
        color: bgColor, // ⬅️ FIX: Mismo color que el Container (no transparente)
        child: Column(
          children: [
            // ========== HEADER ==========
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Stack(
                children: [
                  // ✅ RIVE AVATAR (LO MÁS IMPORTANTE)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        child: riveLoader.when(
                          data: (_) {
                            print('✅ DATA CALLBACK: Renderizando BotAvatarWidget');
                            return const BotAvatarWidget();
                          },
                          loading: () {
                            print('⏳ LOADING CALLBACK: Mostrando spinner');
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Color(0xFFFFC000),
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Cargando avatar Rive...',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      '⚠️ Si esto no avanza:\nRive WASM bloqueado por navegador',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.orange, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          error: (error, stack) {
                            print('❌ ERROR CALLBACK: $error');
                            // FALLBACK VISUAL cuando Rive falla
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Avatar fallback animado
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFC000),
                                          const Color(0xFFFF8000),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFC000).withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy_outlined,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          '⚠️ Rive WASM Bloqueado',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          error.toString().substring(0, error.toString().length > 50 ? 50 : error.toString().length),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Botones en esquina superior derecha
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => ref.read(chatResetProvider)(), // ✅ FUNCIONAL
                          color: Colors.white70,
                          tooltip: "Reiniciar",
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => ref.read(chatOpenProvider.notifier).set(false), // ✅ FUNCIONAL
                          color: Colors.white70,
                          tooltip: "Cerrar",
                        ),
                      ],
                    ),
                  ),
                  
                  // ✅ STATUS INDICATOR REAL (con estado dinámico)
                  Positioned(
                    bottom: 12,
                    left: 24,
                    child: StatusIndicator(
                      isLoading: chatState.isLoading,
                      isOnline: isOnline,
                      mood: chatState.currentMood,
                      isDarkMode: isDarkMode,
                      currentSessionId: chatState.sessionId, // ⬅️ SessionId del chat actual (opcional, se puede obtener del provider)
                      // ⬅️ isChatOpen y activeSessionId ahora se obtienen directamente de los providers en StatusIndicator
                    ),
                  ),
                ],
              ),
            ),

            // ========== BODY (CHAT MESSAGES) ========== ✅ REAL
            Expanded(
              child: Container(
                color: bgColor,
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: reversedMessages.length + (chatState.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Loading indicator al principio (index 0)
                    if (chatState.isLoading) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 20),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: themeColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Procesando...",
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white38 : Colors.black38,
                                  fontSize: 11,
                                ),
                              )
                            ],
                          ),
                        );
                      }
                      // Mensajes reales (desplazados por el loading)
                      final msg = reversedMessages[index - 1];
                      return ChatBubble(
                        message: msg,
                        botThemeColor: themeColor,
                        isDarkMode: isDarkMode,
                      );
                    }
                    // Sin loading, solo mensajes
                    return ChatBubble(
                      message: reversedMessages[index],
                      botThemeColor: themeColor,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
              ),
            ),

            // ========== INPUT AREA ==========
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: bgColor,
              child: Container(
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        enabled: isOnline, // ✅ HABILITADO cuando hay conexión
                        onSubmitted: (_) => isOnline ? _sendMessage() : null,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: themeColor,
                        decoration: InputDecoration(
                          hintText: isOnline ? "Escribe un mensaje..." : "Sin conexión",
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isOnline ? 1.0 : 0.5,
                      child: IconButton(
                        onPressed: isOnline ? _sendMessage : null, // ✅ FUNCIONAL
                        icon: Icon(
                          Icons.send_rounded,
                          color: isOnline ? themeColor : Colors.grey,
                        ),
                        tooltip: "Enviar",
                        splashRadius: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
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
