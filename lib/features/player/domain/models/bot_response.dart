// Archivo: lib/features/player/domain/models/bot_response.dart

class BotResponse {
  final String reply;
  final String mood;

  const BotResponse({
    required this.reply,
    required this.mood,
  });

  factory BotResponse.fromJson(Map<String, dynamic> json) {
    return BotResponse(
      reply: json['reply'] ?? "Sin respuesta del núcleo.",
      mood: json['mood'] ?? "neutral",
    );
  }
}