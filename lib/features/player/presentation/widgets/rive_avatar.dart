// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'dart:ui'; 
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/head_tracking_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

class BotAvatarWidget extends ConsumerStatefulWidget {
  final bool isBubble; // ⬅️ NUEVO: Contexto de ubicación
  const BotAvatarWidget({super.key, this.isBubble = false});

  @override
  ConsumerState<BotAvatarWidget> createState() => _BotAvatarWidgetState();
}

class _BotAvatarWidgetState extends ConsumerState<BotAvatarWidget> with SingleTickerProviderStateMixin {
  StateMachineController? _controller;
  SMINumber? _moodInput;
  SMINumber? _lookXInput;
  SMINumber? _lookYInput;
  SMIBool? _errorInput;
  SMINumber? _downloadInput; // ⬅️ Input para activar "Face download"
  int? _savedMood; // ⬅️ Guardar el mood real cuando no está pensando

  late Ticker _ticker;
  double _targetX = 50.0;
  double _targetY = 50.0;
  double _currentX = 50.0;
  double _currentY = 50.0;
  
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lookXInput == null || _lookYInput == null) return;
    
    // ⬅️ MEJORADO: Tracking más preciso y directo
    // Cuando está tracking, usar interpolación más agresiva (0.5) para seguir el mouse con precisión
    // Cuando no está tracking, suavizar para volver al centro (0.05)
    final double smoothFactor = _isTracking ? 0.5 : 0.05; // ⬅️ Aumentado a 0.5 para tracking más preciso y directo
    
    _currentX = lerpDouble(_currentX, _targetX, smoothFactor) ?? 50;
    _currentY = lerpDouble(_currentY, _targetY, smoothFactor) ?? 50;
    
    _lookXInput!.value = _currentX;
    _lookYInput!.value = _currentY;
  }

  void _onRiveInit(Artboard artboard) {
    // ⬅️ DETECCIÓN AUTOMÁTICA: Intentar diferentes nombres de State Machine
    StateMachineController? controller;
    
    // Intentar 'State Machine 1' primero (para cabezabot.riv)
    controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    
    // Si no existe, intentar 'State Machine' (para catbotlode.riv)
    if (controller == null) {
      controller = StateMachineController.fromArtboard(artboard, 'State Machine');
    }
    
    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;
      _moodInput = controller.getNumberInput('Mood');
      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');
      _errorInput = controller.getBoolInput('Error');
      _downloadInput = controller.getNumberInput('Download'); // ⬅️ Obtener input Download
      
      // ⬅️ NOTA: Para que el círculo cambie de color según el estado emocional,
      // debes configurar en Rive que el color del círculo de "Face download" 
      // se controle mediante el input "Mood". El código ya está listo para esto.
      
      _errorInput?.value = false;
      _downloadInput?.value = 0.0; // Inicializar en 0 (desactivado)
      _moodInput?.value = ref.read(botMoodProvider).toDouble();
      _lookXInput?.value = 50; 
      _lookYInput?.value = 50; 
    } else {
      print("⚠️ No se encontró State Machine en el archivo Rive");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ SELECCIONAR ARCHIVO RIVE CORRECTO según contexto
    final riveFileAsync = widget.isBubble 
        ? ref.watch(riveHeadFileLoaderProvider)   // ⬅️ BURBUJA: Solo cabeza
        : ref.watch(riveFileLoaderProvider);      // ⬅️ CHAT: Cuerpo completo
    
    // 1. OBTENER DATOS DE ENTRADA
    final globalPointer = ref.watch(pointerPositionProvider); // Mouse Global
    final screenSize = MediaQuery.of(context).size; // Tamaño pantalla

    // 2. CALCULAR MI POSICIÓN (GEOMETRÍA)
    Offset myCenter;
    double sensitivity;
    double maxDistance; // ⬅️ NUEVO: Distancia máxima según contexto

    if (widget.isBubble) {
      // --- MODO BURBUJA ---
      // Posición fija: bottom: 40, right: 40.
      // Contenedor ancho variable, pero Avatar pegado a la derecha.
      // Margen derecho total: 40 (screen) + 7 (margin container) + 29 (mitad avatar) ≈ 76px
      // Margen inferior total: 40 (screen) + 7 (margin container) + 29 (mitad avatar) ≈ 76px
      myCenter = Offset(screenSize.width - 76, screenSize.height - 76);
      sensitivity = 150.0; // ⬅️ MEJORADO: Sensibilidad más baja = seguimiento más preciso y directo
      maxDistance = 1000.0; // ⬅️ MEJORADO: Rango aumentado para mejor seguimiento
    } else {
      // --- MODO CHAT PANEL ---
      // Ancho Panel: 380px. Padding right: 28px.
      // Centro X del panel = ScreenWidth - 28 (padding) - (380 / 2) = ScreenWidth - 218
      final double chatCenterX = screenSize.width - 28 - 190;
      
      // Chat desde bottom: 28px. Header: 180px. Avatar en medio del header.
      // Centro Y Avatar = ScreenHeight - 28 (padding bottom) - 90 (mitad del header)
      final double chatAvatarCenterY = screenSize.height - 28 - 90;
      
      myCenter = Offset(chatCenterX, chatAvatarCenterY);
      sensitivity = 180.0; // ⬅️ MEJORADO: Sensibilidad más baja = seguimiento más preciso y directo
      maxDistance = 1200.0; // ⬅️ MEJORADO: Rango aumentado para mejor seguimiento en chat
    }

    // 3. DELEGAR CÁLCULO AL CONTROLLER
    final trackingState = HeadTrackingController.calculateGlobalTracking(
      globalPointer: globalPointer,
      widgetCenter: myCenter,
      sensitivity: sensitivity,
      maxDistance: maxDistance, // ⬅️ Pasar distancia máxima según contexto
    );

    // 4. ACTUALIZAR VARIABLES LOCALES
    _targetX = trackingState.targetX;
    _targetY = trackingState.targetY;
    _isTracking = trackingState.isTracking;

    // Listener para cambios de mood
    ref.listen(botMoodProvider, (prev, next) {
       if (_moodInput != null) {
         // Guardar el mood real
         _savedMood = next;
         
         // Solo actualizar el mood si NO está pensando
         // Si está pensando, mantenemos el mood en 0 (verde) para el círculo
         final chatState = ref.read(chatControllerProvider);
         if (!chatState.isLoading) {
           _moodInput!.value = next.toDouble();
         }
       }
    });

    // ⬅️ Listener para activar "Face download" cuando el bot está pensando
    // IMPORTANTE: Cuando está pensando, forzamos el mood a 0 (verde) para que
    // el círculo siempre sea verde, independientemente del estado emocional
    ref.listen(chatControllerProvider, (prev, next) {
      if (_downloadInput != null) {
        // Activar Download (1.0) cuando isLoading es true, desactivar (0.0) cuando es false
        _downloadInput!.value = next.isLoading ? 1.0 : 0.0;
      }
      
      if (_moodInput != null) {
        if (next.isLoading) {
          // ⬅️ Cuando está pensando, forzar mood a 0 (verde/neutral) para que el círculo sea verde
          _moodInput!.value = 0.0;
        } else {
          // ⬅️ Cuando termina de pensar, restaurar el mood real del bot
          if (_savedMood != null) {
            _moodInput!.value = _savedMood!.toDouble();
          } else {
            // Si no hay mood guardado, usar el mood actual
            final currentMoodIndex = ref.read(botMoodProvider);
            _moodInput!.value = currentMoodIndex.toDouble();
          }
        }
      }
    });

    // ⬅️ NUEVO: Inicializar el estado de Download según el estado actual del chat
    if (_downloadInput != null) {
      final chatState = ref.read(chatControllerProvider);
      _downloadInput!.value = chatState.isLoading ? 1.0 : 0.0;
    }

    // ⬅️ Tamaño según contexto: Burbuja más pequeña, Chat más grande
    final double avatarSize = widget.isBubble ? 68.0 : 300.0;
    
    return SizedBox(
      width: avatarSize, 
      height: avatarSize,
      child: riveFileAsync.when(
        data: (riveFile) {
          // ⬅️ NO especificar artboard: usar el artboard por defecto del archivo
          // Esto funciona tanto para cabezabot.riv como para catbotlode.riv
          return RiveAnimation.direct(
            riveFile, fit: BoxFit.contain, onInit: _onRiveInit,
          );
        },
        loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC000)))), 
        error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text("Error: $err", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 10)))),
      ),
    );
  }
}