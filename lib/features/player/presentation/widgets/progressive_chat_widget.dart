// PROGRESSIVE CHAT - Construcción incremental del chat
// PASO 2: Chat simple + Botón cerrar funcional + Input mejorado
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider para estado del chat
final progressiveChatOpenProvider = StateProvider<bool>((ref) => false);

class ProgressiveChatWidget extends ConsumerWidget {
  const ProgressiveChatWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(progressiveChatOpenProvider);
    
    return Stack(
      children: [
        // CHAT PANEL
        Positioned(
          bottom: 0,
          right: 0,
          child: Visibility(
            visible: isOpen,
            maintainState: true,
            child: _ChatPanel(),
          ),
        ),
        
        // BURBUJA FLOTANTE
        Positioned(
          bottom: 40,
          right: 40,
          child: Visibility(
            visible: !isOpen,
            maintainState: true,
            child: _FloatingBubble(),
          ),
        ),
      ],
    );
  }
}

// === BURBUJA FLOTANTE ===
class _FloatingBubble extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(progressiveChatOpenProvider.notifier).state = true,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0066FF), // Azul
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

// === PANEL DE CHAT ===
class _ChatPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 380,
      height: 600,
      color: const Color(0xFF181818), // Fondo oscuro directo
      child: Column(
        children: [
          // HEADER
          _ChatHeader(),
          
          // ÁREA DE MENSAJES (Por ahora vacía)
          Expanded(
            child: Container(
              color: const Color(0xFF181818),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF3C3C3C)),
                  SizedBox(height: 16),
                  Text(
                    'PASO 2: Chat Funcional',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Botón cerrar ✅',
                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          // INPUT AREA
          _ChatInput(),
        ],
      ),
    );
  }
}

// === HEADER DEL CHAT ===
class _ChatHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 80,
      color: const Color(0xFF2C2C2C),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info del bot
          Row(
            children: const [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF0066FF),
                child: Icon(Icons.smart_toy, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BotLode Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'En línea',
                    style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Botón cerrar
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => ref.read(progressiveChatOpenProvider.notifier).state = false,
            tooltip: 'Cerrar chat',
          ),
        ],
      ),
    );
  }
}

// === INPUT DE CHAT ===
class _ChatInput extends StatefulWidget {
  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    // TODO: Aquí conectaremos el envío real en pasos futuros
    print('📤 Mensaje enviado: $text');
    _controller.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C2C2C),
      child: Row(
        children: [
          // Campo de texto
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(color: Color(0xFF808080)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Botón enviar
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF0066FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
