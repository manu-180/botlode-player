// Archivo: lib/features/player/presentation/providers/chat_provider.dart
import 'package:botlode_player/core/services/chat_persistence_service.dart';
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
  // ⬅️ NUEVO: Session ID persistente (sobrevive a recargas)
  late final String _sessionId;

  @override
  ChatState build() {
    // ⬅️ NUEVO: Cargar sessionId persistente o crear uno nuevo
    _sessionId = ChatPersistenceService.getOrCreateSessionId();
    
    // ⬅️ NUEVO: Cargar mensajes guardados si existen
    final storedMessages = ChatPersistenceService.getStoredMessages();
    
    // Si hay mensajes guardados, usarlos; si no, mensaje inicial
    final initialMessages = storedMessages.isNotEmpty
        ? storedMessages
        : [
            ChatMessage(
              id: 'init',
              text: 'Sistema en línea. ¿En qué puedo ayudarte hoy?',
              role: MessageRole.bot,
              timestamp: DateTime.now(),
            )
          ];
    
    // Guardar mensajes iniciales
    ChatPersistenceService.saveMessages(initialMessages);
    
    return ChatState(
      sessionId: _sessionId,
      messages: initialMessages,
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
    
    // ⬅️ NUEVO: Guardar mensajes después de agregar el del usuario
    ChatPersistenceService.saveMessages(state.messages);

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

    final updatedMessages = [...state.messages, botMsg];
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: false,
      currentMood: response.mood,
    );
    
    // ⬅️ NUEVO: Guardar mensajes después de recibir respuesta del bot
    ChatPersistenceService.saveMessages(updatedMessages);
  }
}