// Archivo: lib/features/player/presentation/providers/chat_provider.dart
import 'package:botlode_player/core/network/api_client.dart';
import 'package:botlode_player/features/player/domain/models/chat_message.dart';
import 'package:botlode_player/main.dart'; // Importar para acceder a currentBotIdProvider
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
      // Mensaje inicial neutro (ya que ahora puede ser CUALQUIER bot)
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
    // Usamos ref.read para obtener el ID que inyectamos en el main.dart
    final botId = ref.read(currentBotIdProvider);

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

    // 3. Llamar a la Edge Function (Usando el botId dinámico)
    final response = await ApiClient().sendMessage(
      message: text,
      sessionId: _sessionId,
      botId: botId, // <--- AQUÍ ESTÁ EL CAMBIO CLAVE
    );

    // 4. Procesar respuesta
    final botText = response['reply'] ?? '...';
    final botMood = response['mood'] ?? 'idle';

    final botMsg = ChatMessage(
      id: _uuid.v4(),
      text: botText,
      role: MessageRole.bot,
      timestamp: DateTime.now(),
    );

    // 5. Actualizar estado
    state = state.copyWith(
      messages: [...state.messages, botMsg],
      isLoading: false,
      currentMood: botMood,
    );
  }
}