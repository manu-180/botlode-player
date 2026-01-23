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

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentMood = 'idle',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentMood,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentMood: currentMood ?? this.currentMood,
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
    return ChatState(messages: [
      ChatMessage(
        id: 'init',
        text: 'Sistema en línea. ¿En qué puedo ayudarte hoy?',
        role: MessageRole.bot,
        timestamp: DateTime.now(),
      )
    ]);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. LEER EL ID DINÁMICO
    final botId = ref.read(currentBotIdProvider);
    final repository = ref.read(chatRepositoryProvider);

    // 2. Agregar mensaje del usuario (Optimistic UI)
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

    // 3. Llamar al Repositorio (Clean Architecture)
    final response = await repository.sendMessage(
      message: text,
      sessionId: _sessionId,
      botId: botId, 
    );

    // 4. Procesar respuesta tipada
    final botMsg = ChatMessage(
      id: _uuid.v4(),
      text: response.reply,
      role: MessageRole.bot,
      timestamp: DateTime.now(),
    );

    // 5. Actualizar estado
    state = state.copyWith(
      messages: [...state.messages, botMsg],
      isLoading: false,
      currentMood: response.mood,
    );
  }
}