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
  final String sessionId; // ⬅️ ID temporal del contexto (cambia con reloads)
  final String chatId; // ⬅️ NUEVO: ID persistente del chat (NO cambia con reloads)
  final DateTime createdAt; // ⬅️ NUEVO: Timestamp de creación del chat (para determinar prioridad)

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentMood = 'neutral', // ⬅️ Estado inicial: 'neutral' = "EN LÍNEA"
    required this.sessionId,
    required this.chatId, // ⬅️ NUEVO: Requerido
    DateTime? createdAt, // ⬅️ NUEVO: Opcional, se crea automáticamente si no se proporciona
  }) : createdAt = createdAt ?? DateTime.now().toUtc(); // ⬅️ CRÍTICO: SIEMPRE UTC para evitar problemas de zona horaria

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentMood,
    String? sessionId,
    String? chatId,
    DateTime? createdAt,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentMood: currentMood ?? this.currentMood,
      sessionId: sessionId ?? this.sessionId,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
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
    // ⬅️ NUEVO: Cargar sessionId persistente o crear uno nuevo
    // Solo inicializar si está vacío (primera vez) o si fue reseteado
    if (_sessionId.isEmpty) {
      _sessionId = ChatPersistenceService.getOrCreateSessionId();
    } else {
      // Si ya existe, verificar si hay un reset reciente
      final lastReset = ChatPersistenceService.getLastResetTime();
      if (lastReset != null) {
        final now = DateTime.now();
        final timeSinceReset = now.difference(lastReset);
        if (timeSinceReset.inSeconds < 2) {
          // Reset reciente, crear nuevo sessionId
          _sessionId = ChatPersistenceService.createNewSessionId();
        }
      }
    }
    
    // ⬅️ NUEVO: Cargar mensajes guardados si existen
    final storedMessages = ChatPersistenceService.getStoredMessages();
    
    // ⬅️ NUEVO: Obtener mensaje inicial del bot (si está disponible)
    String defaultInitialMessage = 'Sistema en línea. ¿En qué puedo ayudarte hoy?';
    try {
      final botConfigAsync = ref.watch(botConfigProvider);
      final botConfig = botConfigAsync.asData?.value;
      if (botConfig?.initialMessage != null && botConfig!.initialMessage!.trim().isNotEmpty) {
        defaultInitialMessage = botConfig.initialMessage!;
      }
    } catch (e) {
      // Si hay error, usar el mensaje por defecto
    }
    
    // Si hay mensajes guardados, usarlos; si no, mensaje inicial del bot
    final initialMessages = storedMessages.isNotEmpty
        ? storedMessages
        : [
            ChatMessage(
              id: 'init',
              text: defaultInitialMessage,
              role: MessageRole.bot,
              timestamp: DateTime.now().subtract(const Duration(hours: 3)), // ⬅️ Hora de Argentina (UTC-3)
            )
          ];
    
    // Guardar mensajes iniciales
    ChatPersistenceService.saveMessages(initialMessages);
    
    // ⬅️ NUEVO: Obtener o crear chatId persistente (NO cambia con reloads)
    // ⚠️ CRÍTICO: Asegurar que chatId siempre tenga un valor válido
    String chatId = ChatPersistenceService.getOrCreateChatId();
    
    // Validación adicional: si está vacío, crear uno nuevo
    if (chatId.isEmpty) {
      chatId = ChatPersistenceService.resetChatId();
    }
    
    final state = ChatState(
      sessionId: _sessionId,
      chatId: chatId, // ⬅️ NUEVO: ID persistente del chat (asegurado que no esté vacío)
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
      timestamp: DateTime.now().subtract(const Duration(hours: 3)), // ⬅️ Hora de Argentina (UTC-3)
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true, 
      currentMood: 'thinking', 
    );
    
    // ⬅️ NUEVO: Guardar mensajes después de agregar el del usuario
    ChatPersistenceService.saveMessages(state.messages);

    // ⬅️ CRÍTICO: Asegurar que chatId no sea null o vacío
    // Si está vacío o es null, obtenerlo o crearlo desde el servicio de persistencia
    String effectiveChatId = state.chatId;
    
    // Validación estricta: verificar que chatId tenga un valor válido
    if (effectiveChatId.isEmpty || effectiveChatId.trim().isEmpty) {
      effectiveChatId = ChatPersistenceService.getOrCreateChatId();
      
      // Validación adicional: si sigue vacío, crear uno nuevo
      if (effectiveChatId.isEmpty) {
        effectiveChatId = ChatPersistenceService.resetChatId();
      }
      
      // Actualizar el estado con el chatId correcto
      state = state.copyWith(chatId: effectiveChatId);
    }

    final response = await repository.sendMessage(
      message: text,
      sessionId: _sessionId,
      chatId: effectiveChatId, // ⬅️ Asegurar que no sea null
      botId: botId, 
    );

    final botMsg = ChatMessage(
      id: _uuid.v4(),
      text: response.reply,
      role: MessageRole.bot,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)), // ⬅️ Hora de Argentina (UTC-3)
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
    // ⬅️ IMPORTANTE: Mantener el mismo chatId (NO cambiar con reloads)
    // El chatId identifica la conversación completa, mientras que sessionId identifica el contexto actual
    final currentChatId = state.chatId;
    
    // ⬅️ PASO 1: Crear un NUEVO sessionId (chat completamente nuevo - el bot olvida todo)
    // PERO mantener el mismo chatId para que los heartbeats se agrupen correctamente
    _sessionId = ChatPersistenceService.createNewSessionId();
    
    // ⬅️ PASO 2: Limpiar mensajes del localStorage (pantalla en blanco)
    ChatPersistenceService.saveMessages([]);
    
    // ⬅️ PASO 3: Crear mensaje inicial para el nuevo chat
    final initialMessage = ChatMessage(
      id: 'init',
      text: 'Sistema en línea. ¿En qué puedo ayudarte hoy?',
      role: MessageRole.bot,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)), // ⬅️ Hora de Argentina (UTC-3)
    );
    
    // ⬅️ PASO 4: Actualizar estado inmediatamente (pantalla en blanco + estado normal)
    // ⚠️ IMPORTANTE: Mantener el mismo chatId (NO cambiar con reloads)
    // ⬅️ NUEVO: Crear nuevo timestamp para que este chat sea el más nuevo
    final newState = ChatState(
      messages: [initialMessage],
      isLoading: false,
      currentMood: 'neutral', // ⬅️ Estado normal (neutral = "EN LÍNEA")
      sessionId: _sessionId, // ⬅️ NUEVO sessionId = nuevo contexto (bot olvida todo)
      chatId: currentChatId, // ⬅️ MANTENER el mismo chatId (persistente)
      createdAt: DateTime.now().toUtc(), // ⬅️ CRÍTICO: SIEMPRE UTC para evitar problemas de zona horaria
    );
    
    state = newState;
    
    // ⬅️ PASO 4.5: Actualizar el sessionId activo (importar ui_provider)
    try {
      // Necesitamos acceder al provider de activeSessionId
      // Esto se hará desde chatResetProvider para evitar dependencias circulares
    } catch (e) {
      // Error silenciado
    }
    
    // ⬅️ PASO 5: Guardar el estado inicial del nuevo chat
    ChatPersistenceService.saveMessages([initialMessage]);
  }
}