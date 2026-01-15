// Archivo: lib/features/player/domain/models/chat_message.dart

enum MessageRole { user, bot }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
  });
}