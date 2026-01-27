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
    this.currentMood = 'neutral', // ⬅️ Estado inicial: 'neutral' = "EN LÍNEA"
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
  // ⚠️ NO usar late final porque se reinicializa cuando se invalida el provider
  String _sessionId = '';

  @override
  ChatState build() {
    print("🔵 [DEBUG] ChatController.build() - INICIO");
    print("🔵 [DEBUG] ChatController.build() - _sessionId actual: '$_sessionId'");
    
    // ⬅️ NUEVO: Cargar sessionId persistente o crear uno nuevo
    // Solo inicializar si está vacío (primera vez) o si fue reseteado
    if (_sessionId.isEmpty) {
      _sessionId = ChatPersistenceService.getOrCreateSessionId();
      print("🔵 [DEBUG] ChatController.build() - sessionId inicializado: $_sessionId");
    } else {
      // Si ya existe, verificar si hay un reset reciente
      final lastReset = ChatPersistenceService.getLastResetTime();
      if (lastReset != null) {
        final now = DateTime.now();
        final timeSinceReset = now.difference(lastReset);
        if (timeSinceReset.inSeconds < 2) {
          // Reset reciente, crear nuevo sessionId
          print("🔵 [DEBUG] ChatController.build() - Reset detectado (hace ${timeSinceReset.inSeconds}s), creando nuevo sessionId");
          _sessionId = ChatPersistenceService.createNewSessionId();
        } else {
          print("🔵 [DEBUG] ChatController.build() - Usando sessionId existente: $_sessionId");
        }
      } else {
        print("🔵 [DEBUG] ChatController.build() - Usando sessionId existente: $_sessionId");
      }
    }
    
    // ⬅️ NUEVO: Cargar mensajes guardados si existen
    final storedMessages = ChatPersistenceService.getStoredMessages();
    print("🔵 [DEBUG] ChatController.build() - mensajes guardados encontrados: ${storedMessages.length}");
    
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
    
    print("🔵 [DEBUG] ChatController.build() - mensajes iniciales: ${initialMessages.length}");
    for (var i = 0; i < initialMessages.length; i++) {
      print("🔵 [DEBUG] ChatController.build() - mensaje $i: ${initialMessages[i].text.substring(0, initialMessages[i].text.length > 50 ? 50 : initialMessages[i].text.length)}");
    }
    
    // Guardar mensajes iniciales
    ChatPersistenceService.saveMessages(initialMessages);
    print("🔵 [DEBUG] ChatController.build() - mensajes guardados en localStorage");
    
    final state = ChatState(
      sessionId: _sessionId,
      messages: initialMessages,
    );
    
    // ⬅️ Si no hay sessionId activo, establecer este como activo (primera vez)
    // Esto se actualizará cuando se haga reload
    try {
      // No podemos acceder a activeSessionIdProvider aquí porque causaría dependencia circular
      // Se manejará desde ui_provider cuando se inicialice
    } catch (e) {
      // Ignorar errores
    }
    
    print("🔵 [DEBUG] ChatController.build() - estado creado con ${state.messages.length} mensajes, mood: ${state.currentMood}, sessionId: ${state.sessionId}");
    print("🔵 [DEBUG] ChatController.build() - FIN");
    
    return state;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final botId = ref.read(currentBotIdProvider);
    final repository = ref.read(chatRepositoryProvider);

    // ⬅️ NUEVO: Marcar este chat como activo cuando se envía un mensaje
    try {
      // Importar ui_provider aquí causaría dependencia circular, así que lo haremos desde fuera
      // El activeSessionId se actualizará desde simple_chat_test cuando se envía el mensaje
    } catch (e) {
      // Ignorar errores
    }

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

  // ⬅️ NUEVO: Método para iniciar un chat completamente nuevo (reload)
  void clearChat() {
    print("🟠 [DEBUG] clearChat() - INICIO");
    print("🟠 [DEBUG] clearChat() - estado ANTES: ${state.messages.length} mensajes, sessionId: ${state.sessionId}, mood: ${state.currentMood}");
    print("🟠 [DEBUG] clearChat() - _sessionId ANTES: '$_sessionId'");
    
    // ⬅️ PASO 1: Crear un NUEVO sessionId (chat completamente nuevo - el bot olvida todo)
    final oldSessionId = _sessionId;
    _sessionId = ChatPersistenceService.createNewSessionId();
    print("🟠 [DEBUG] clearChat() - PASO 1: sessionId cambiado de '$oldSessionId' a '$_sessionId'");
    print("🟠 [DEBUG] clearChat() - _sessionId DESPUÉS: '$_sessionId'");
    
    // ⬅️ PASO 2: Limpiar mensajes del localStorage (pantalla en blanco)
    final messagesBeforeClear = ChatPersistenceService.getStoredMessages();
    print("🟠 [DEBUG] clearChat() - PASO 2: mensajes ANTES de limpiar: ${messagesBeforeClear.length}");
    ChatPersistenceService.saveMessages([]);
    final messagesAfterClear = ChatPersistenceService.getStoredMessages();
    print("🟠 [DEBUG] clearChat() - PASO 2: mensajes DESPUÉS de limpiar: ${messagesAfterClear.length}");
    
    // ⬅️ PASO 3: Crear mensaje inicial para el nuevo chat
    final initialMessage = ChatMessage(
      id: 'init',
      text: 'Sistema en línea. ¿En qué puedo ayudarte hoy?',
      role: MessageRole.bot,
      timestamp: DateTime.now(),
    );
    print("🟠 [DEBUG] clearChat() - PASO 3: mensaje inicial creado: '${initialMessage.text}'");
    
    // ⬅️ PASO 4: Actualizar estado inmediatamente (pantalla en blanco + estado normal)
    final newState = ChatState(
      messages: [initialMessage],
      isLoading: false,
      currentMood: 'neutral', // ⬅️ Estado normal (neutral = "EN LÍNEA")
      sessionId: _sessionId, // ⬅️ NUEVO sessionId = nuevo contexto (bot olvida todo)
    );
    print("🟠 [DEBUG] clearChat() - PASO 4: nuevo estado creado con ${newState.messages.length} mensajes, mood: ${newState.currentMood}, sessionId: ${newState.sessionId}");
    
    state = newState;
    print("🟠 [DEBUG] clearChat() - PASO 4: estado actualizado. Estado actual: ${state.messages.length} mensajes, mood: ${state.currentMood}, sessionId: ${state.sessionId}");
    
    // ⬅️ PASO 4.5: Actualizar el sessionId activo (importar ui_provider)
    try {
      // Necesitamos acceder al provider de activeSessionId
      // Esto se hará desde chatResetProvider para evitar dependencias circulares
    } catch (e) {
      print("🟠 [DEBUG] clearChat() - Error actualizando activeSessionId: $e");
    }
    
    // ⬅️ PASO 5: Guardar el estado inicial del nuevo chat
    ChatPersistenceService.saveMessages([initialMessage]);
    final messagesAfterSave = ChatPersistenceService.getStoredMessages();
    print("🟠 [DEBUG] clearChat() - PASO 5: mensajes guardados. Mensajes en localStorage: ${messagesAfterSave.length}");
    
    print("🟠 [DEBUG] clearChat() - FIN. Estado final: ${state.messages.length} mensajes, sessionId: ${state.sessionId}, mood: ${state.currentMood}");
    print("🔄 Chat reiniciado: pantalla en blanco, bot en estado 'idle', nuevo sessionId: $_sessionId (bot olvidó todo)");
  }
}