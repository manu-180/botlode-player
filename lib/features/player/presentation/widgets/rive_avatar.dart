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

/// Misma lógica de seguimiento que botlode_web (home, bot view, demo):
/// - Centro del widget desde RenderBox (posición real)
/// - Transición suave al entrar en rango (primeros ~10 frames)
/// - Fluidez al volver al centro cuando el mouse sale del rango
class BotAvatarWidget extends ConsumerStatefulWidget {
  final bool isBubble;
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
  SMINumber? _downloadInput;
  int? _savedMood;

  late Ticker _ticker;
  double _targetX = 50.0;
  double _targetY = 50.0;
  double _currentX = 50.0;
  double _currentY = 50.0;

  bool _isTracking = false;
  bool _wasTrackingPreviously = false;
  int _trackingFrames = 0;

  /// Sensibilidad y rango: 450px máximo para que no siga por toda la pantalla
  double get _sensitivity => widget.isBubble ? 400.0 : 600.0;
  double get _maxDistance => 450.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _lookXInput == null || _lookYInput == null) return;

    // Calcular tracking en cada frame (como botlode_web): posición real del widget
    try {
      final globalPointer = ref.read(pointerPositionProvider);
      final renderObject = context.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) return;

      final RenderBox box = renderObject;
      if (!box.hasSize || !box.attached) return;

      final widgetCenter = Offset(
        box.localToGlobal(Offset.zero).dx + box.size.width / 2,
        box.localToGlobal(Offset.zero).dy + box.size.height / 2,
      );

      final trackingState = HeadTrackingController.calculateGlobalTracking(
        globalPointer: globalPointer,
        widgetCenter: widgetCenter,
        sensitivity: _sensitivity,
        maxDistance: _maxDistance,
      );

      _targetX = trackingState.targetX;
      _targetY = trackingState.targetY;
      _isTracking = trackingState.isTracking;

      if (_isTracking && !_wasTrackingPreviously) _trackingFrames = 0;
      if (_isTracking) _trackingFrames++; else _trackingFrames = 0;
      _wasTrackingPreviously = _isTracking;
    } catch (e) {
      _targetX = 50.0;
      _targetY = 50.0;
      _isTracking = false;
      _wasTrackingPreviously = false;
      _trackingFrames = 0;
    }

    // Misma física que botlode_web: suave al entrar, preciso siguiendo, fluido al centro
    double smoothFactor;
    if (_isTracking) {
      smoothFactor = _trackingFrames < 10 ? 0.15 : 1.0;
    } else {
      smoothFactor = 0.05;
    }

    // Calibración Y igual que en botlode_web
    double calibratedTargetY = _targetY - 15.0;
    calibratedTargetY = calibratedTargetY.clamp(0.0, 100.0);

    _currentX = lerpDouble(_currentX, _targetX, smoothFactor) ?? 50;
    _currentY = lerpDouble(_currentY, calibratedTargetY, smoothFactor) ?? 50;

    try {
      _lookXInput!.value = _currentX;
      _lookYInput!.value = _currentY;
    } catch (_) {}
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
      _downloadInput = controller.getNumberInput('Download'); // ⬅️ Modo "procesando" (como botlode_web)
      
      // ⬅️ NOTA: Para que el círculo cambie de color según el estado emocional,
      // debes configurar en Rive que el color del círculo de "Face download" 
      // se controle mediante el input "Mood". El código ya está listo para esto.
      
      _errorInput?.value = false;
      // Sincronizar con estado actual: si ya está pensando, mostrar animación de procesando de una
      final chatState = ref.read(chatControllerProvider);
      _downloadInput?.value = chatState.isLoading ? 1.0 : 0.0;
      _moodInput?.value = ref.read(botMoodProvider).toDouble();
      _lookXInput?.value = 50; 
      _lookYInput?.value = 50; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final riveFileAsync = widget.isBubble
        ? ref.watch(riveHeadFileLoaderProvider)
        : ref.watch(riveFileLoaderProvider);

    // ⬅️ Reconstruir cuando cambie isLoading para aplicar modo "procesando" al Rive (igual que botlode_web)
    final chatState = ref.watch(chatControllerProvider);

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

    // ⬅️ Aplicar modo "procesando" (Download 1.0) cuando isLoading; 0.0 cuando no (como botlode_web)
    if (_downloadInput != null) {
      _downloadInput!.value = chatState.isLoading ? 1.0 : 0.0;
    }

    // ⬅️ Tamaño según contexto: Burbuja más pequeña, Chat más grande
    final double avatarSize = widget.isBubble ? 68.0 : 300.0;
    
    return SizedBox(
      width: avatarSize, 
      height: avatarSize,
      child: riveFileAsync.when(
        data: (riveFile) {
          return RepaintBoundary(
            child: RiveAnimation.direct(
              riveFile, fit: BoxFit.contain, onInit: _onRiveInit,
            ),
          );
        },
        loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC000)))), 
        error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text("Error: $err", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 10)))),
      ),
    );
  }
}