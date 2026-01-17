// Archivo: lib/features/player/presentation/views/chat_panel_view.dart
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/chat_bubble.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatPanelView extends ConsumerStatefulWidget {
  const ChatPanelView({super.key});

  @override
  ConsumerState<ChatPanelView> createState() => _ChatPanelViewState();
}

class _ChatPanelViewState extends ConsumerState<ChatPanelView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- TRADUCTOR DE HUMOR (String -> Int) ---
  // Convierte "angry" en 1, "happy" en 2, etc. para Rive.
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
    // Sincronización Inicial con Traducción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String moodString = ref.read(chatControllerProvider).currentMood;
      final int moodInt = _getMoodIndex(moodString); // <--- Traducimos aquí
      ref.read(botMoodProvider.notifier).state = moodInt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    ref.listen(chatControllerProvider, (prev, next) {
      // Scroll automático
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
      
      // Sincronización Reactiva con Traducción
      if (prev?.currentMood != next.currentMood) {
        final int newMoodInt = _getMoodIndex(next.currentMood); // <--- Traducimos aquí
        ref.read(botMoodProvider.notifier).state = newMoodInt;
      }
    });

    return Container(
      width: isMobile ? double.infinity : null,
      height: isMobile ? double.infinity : null,
      
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: isMobile ? null : BorderRadius.circular(24),
        border: isMobile ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
        child: Column(
          children: [
            // --- HEADER (ZONA DEL ROBOT) ---
            Container(
              height: 160,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  // 1. CAPA FONDO / AVATAR INTERACTIVO
                  const Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: BotAvatarWidget(), 
                    ),
                  ),
                  
                  // 2. BOTONES DE CONTROL
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white24, size: 20),
                          tooltip: "Reiniciar Chat",
                          onPressed: () => ref.read(chatResetProvider)(),
                        ),
                      ],
                    ),
                  ),

                  // 3. INDICADOR DE ESTADO
                  Positioned(
                    bottom: 16,
                    left: 20,
                    child: StatusIndicator(
                      isLoading: chatState.isLoading, 
                      mood: chatState.currentMood // Este sigue usando String, está bien para el texto
                    ),
                  ),
                ],
              ),
            ),

            // --- CHAT BODY ---
            Expanded(
              child: Container(
                color: const Color(0xFF151515),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatState.messages.length) {
                       return const Padding(
                         padding: EdgeInsets.only(left: 16, top: 8),
                         child: Text("Escribiendo...", style: TextStyle(color: Colors.white30, fontSize: 10)),
                       );
                    }
                    return ChatBubble(message: chatState.messages[index]);
                  },
                ),
              ),
            ),

            // --- INPUT ---
            Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + (isMobile ? MediaQuery.of(context).padding.bottom : 0)),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: "Escribe aquí...",
                        hintStyle: TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide.none
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC000),
                      shape: BoxShape.circle,
                      ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}