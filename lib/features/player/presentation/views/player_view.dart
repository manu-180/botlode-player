// Archivo: lib/features/player/presentation/views/player_view.dart
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/chat_bubble.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
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

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    _textController.clear();
    // Llamamos al provider para enviar
    ref.read(chatControllerProvider.notifier).sendMessage(text);
  }

  // Auto-scroll al fondo cuando llegan mensajes
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Un poco extra
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);

    // Efecto secundario: Scroll al fondo cuando la lista crece
    ref.listen(chatControllerProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO / AVATAR (Capa Trasera)
          Positioned.fill(
            child: RiveAvatar(mood: chatState.currentMood),
          ),

          // 2. CHAT UI (Capa Frontal - Flotante)
          Column(
            children: [
              // Espacio transparente arriba para ver al bot
              const Expanded(flex: 3, child: SizedBox()),

              // Área de Chat
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Lista de Mensajes
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length) {
                              // Indicador de "Escribiendo..."
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "PizzaBot está escribiendo...",
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                              );
                            }
                            final msg = chatState.messages[index];
                            return ChatBubble(message: msg);
                          },
                        ),
                      ),

                      // Input Bar
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                style: const TextStyle(color: Colors.white),
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: "Escribe tu mensaje aquí...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FloatingActionButton(
                              onPressed: _sendMessage,
                              backgroundColor: const Color(0xFFFFC000),
                              child: const Icon(Icons.send_rounded, color: Colors.black),
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
        ],
      ),
    );
  }
}