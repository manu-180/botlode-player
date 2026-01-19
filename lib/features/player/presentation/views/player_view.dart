// Archivo: lib/features/player/presentation/views/player_view.dart
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/chat_bubble.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key});

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _getMoodIndex(String mood) {
    switch (mood.toLowerCase()) {
      case 'angry': return 1;
      case 'happy': return 2;
      case 'sales': return 3;
      case 'confused': return 4;
      case 'tech': return 5;
      case 'neutral':
      default: return 0;
    }
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String moodString = ref.read(chatControllerProvider).currentMood;
      final int moodInt = _getMoodIndex(moodString); 
      ref.read(botMoodProvider.notifier).state = moodInt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    
    // 1. CARGA DE CONFIGURACIÓN
    // Usamos 'when' para manejar los estados de carga correctamente y evitar valores nulos prematuros
    final botConfigAsync = ref.watch(botConfigProvider);
    final botConfig = botConfigAsync.asData?.value;

    // Valores seguros por si está cargando
    final themeColor = botConfig?.themeColor ?? const Color(0xFFFFC000);
    final isDarkMode = botConfig?.isDarkMode ?? true; 
    final showOfflineAlert = botConfig?.showOfflineAlert ?? true;

    final isOnlineAsync = ref.watch(connectivityProvider);
    final isOnline = isOnlineAsync.asData?.value ?? true;

    // --- ESTILOS DINÁMICOS (Light vs Dark) ---
    final Color bgColor = isDarkMode ? Colors.black : const Color(0xFFF0F2F5);
    final Color inputFill = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white;
    final Color inputText = isDarkMode ? Colors.white : Colors.black87;
    final Color placeholderText = isDarkMode ? Colors.white54 : Colors.black45;
    final Color iconColor = isDarkMode ? Colors.white54 : Colors.black54;
    
    // Gradiente superior (Fade)
    final List<Color> gradientColors = isDarkMode 
        ? [Colors.transparent, Colors.black.withOpacity(0.9), Colors.black]
        : [Colors.transparent, const Color(0xFFF0F2F5).withOpacity(0.9), const Color(0xFFF0F2F5)];

    ref.listen(chatControllerProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
      if (previous?.currentMood != next.currentMood) {
        ref.read(botMoodProvider.notifier).state = _getMoodIndex(next.currentMood);
      }
    });

    // LISTENER DE ERROR DE CONEXIÓN
    ref.listen(connectivityProvider, (prev, next) {
      next.whenData((online) {
        // Solo mostramos alerta si NO hay internet Y la configuración lo permite
        if (!online && showOfflineAlert) {
          final snackBg = isDarkMode ? const Color(0xFF1A0505).withOpacity(0.95) : Colors.white;
          final snackBorder = const Color(0xFFFF003C);
          final snackTextBody = isDarkMode ? Colors.white70 : Colors.black87;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.transparent, 
              elevation: 0,
              duration: const Duration(days: 365), 
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: snackBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: snackBorder, width: 1),
                  boxShadow: [
                    BoxShadow(color: snackBorder.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF003C), size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ERROR DE ENLACE",
                            style: TextStyle(color: Color(0xFFFF003C), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Verifique su conexión a la red.",
                            style: TextStyle(color: snackTextBody, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (prev?.value == false && online) {
          // Ocultar siempre al volver, por limpieza
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    });

    return Scaffold(
      backgroundColor: bgColor, // <--- APLICA EL FONDO LIGHT/DARK
      body: Stack(
        children: [
          const Positioned.fill(
            child: BotAvatarWidget(), 
          ),

          // HEADER CONTROLS
          Positioned(
            top: 40, 
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: iconColor, size: 28),
                  tooltip: "Reiniciar",
                  onPressed: () => ref.read(chatResetProvider)(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: iconColor, size: 32),
                  tooltip: "Cerrar",
                  onPressed: () => ref.read(chatOpenProvider.notifier).set(false),
                ),
              ],
            ),
          ),

          // CHAT INTERFACE
          Column(
            children: [
              const Expanded(flex: 3, child: SizedBox()),

              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // LISTA
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Escribiendo...",
                                    style: TextStyle(color: placeholderText, fontSize: 12),
                                  ),
                                ),
                              );
                            }
                            return ChatBubble(
                              message: chatState.messages[index], 
                              botThemeColor: themeColor,
                              isDarkMode: isDarkMode, // <--- PROPAJA EL TEMA
                            );
                          },
                        ),
                      ),

                      // INPUT
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                style: TextStyle(color: inputText),
                                enabled: isOnline,
                                onSubmitted: (_) => isOnline ? _sendMessage() : null,
                                decoration: InputDecoration(
                                  hintText: isOnline ? "Escribe tu mensaje aquí..." : "Esperando conexión...",
                                  hintStyle: TextStyle(color: placeholderText),
                                  filled: true,
                                  fillColor: inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: !isDarkMode ? OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
                                  ) : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Botón Enviar
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isOnline ? 1.0 : 0.5,
                              child: FloatingActionButton(
                                onPressed: isOnline ? _sendMessage : null,
                                backgroundColor: themeColor,
                                elevation: isDarkMode ? 0 : 4,
                                child: const Icon(Icons.send_rounded, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          Positioned(
            bottom: 100, 
            left: 20,
            child: StatusIndicator(
              isLoading: chatState.isLoading, 
              isOnline: isOnline, 
              mood: chatState.currentMood 
            ),
          ),
        ],
      ),
    );
  }
}