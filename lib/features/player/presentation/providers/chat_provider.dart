// Archivo: lib/features/player/presentation/providers/chat_provider.dart
import 'package:botlode_player/features/player/domain/models/chat_message.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_provider.g.dart';

// --- ESTADO DEL CHAT ---
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String currentMood;
  final String sessionId; // <--- ESTO ES CRUCIAL

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentMood = 'idle',
    required this.sessionId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentMood,
    String? sessionId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentMood: currentMood ?? this.currentMood,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

// --- PROVIDER (CONTROLLER) ---
@riverpod
class ChatController extends _$ChatController {
  final _uuid = const Uuid();
  // Session ID única por recarga de página
  final _sessionId = const Uuid().v4(); 

  @override
  ChatState build() {
    return ChatState(
      sessionId: _sessionId, // <--- Aquí se inicializa
      messages: [
        ChatMessage(
          id: 'init',
          text: 'Sistema en línea. ¿En qué puedo ayudarte hoy?',
          role: MessageRole.bot,
          timestamp: DateTime.now(),
        )
      ]
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final botId = ref.read(currentBotIdProvider);
    final repository = ref.read(chatRepositoryProvider);

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      text: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true, 
      currentMood: 'thinking', 
    );

    final response = await repository.sendMessage(
      message: text,
      sessionId: _sessionId,
      botId: botId, 
    );

    final botMsg = ChatMessage(
      id: _uuid.v4(),
      text: response.reply,
      role: MessageRole.bot,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, botMsg],
      isLoading: false,
      currentMood: response.mood,
    );
  }
}