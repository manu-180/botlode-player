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

  // ⬅️ NUEVO: Serialización para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.bot,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}