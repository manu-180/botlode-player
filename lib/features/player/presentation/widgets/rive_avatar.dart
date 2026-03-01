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
  /// Tamaño fijo cuando se usa en header del chat (ej. 88). Si null, usa 68 (burbuja) o 300 (chat completo).
  final double? size;
  const BotAvatarWidget({super.key, this.isBubble = false, this.size});

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

  int _moodEnforceCounter = 0;

  // ⬅️ UX PREMIUM: inputs opcionales (si el .riv los tiene, se usan)
  SMITrigger? _helloTrigger;
  SMITrigger? _goodbyeTrigger;
  SMIBool? _hoveredInput;
  SMITrigger? _listeningTrigger;
  SMIBool? _isTypingInput;
  SMIBool? _anticipatingInput;
  SMIBool? _reducedMotionInput;

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

    // Enforcement continuo del mood: la state machine de Rive tiene transiciones con exit-time
    // que devuelven la animación a idle aunque el input Mood siga en el valor correcto.
    // Re-seteamos el valor en cada frame para que la condición se mantenga activa.
    // Cada ~3s hacemos un toggle breve (0 → real) para forzar un re-trigger de la transición.
    if (_moodInput != null) {
      try {
        final target = ref.read(botMoodProvider).toDouble();
        _moodEnforceCounter++;
        if (_moodEnforceCounter >= 180 && target > 0) {
          _moodEnforceCounter = 0;
          _moodInput!.value = 0;
        } else {
          _moodInput!.value = target;
        }
      } catch (_) {}
    }
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

      // ⬅️ UX PREMIUM: triggers/inputs opcionales (añadir en Rive si quieres las animaciones)
      _helloTrigger = controller.getTriggerInput('Hello');
      _goodbyeTrigger = controller.getTriggerInput('Goodbye');
      _listeningTrigger = controller.getTriggerInput('Listening');
      _hoveredInput = controller.getBoolInput('Hovered');
      _isTypingInput = controller.getBoolInput('IsTyping');
      _anticipatingInput = controller.getBoolInput('Anticipating');
      _reducedMotionInput = controller.getBoolInput('ReducedMotion');

      // ⬅️ NOTA: Para que el círculo cambie de color según el estado emocional,
      // debes configurar en Rive que el color del círculo de "Face download" 
      // se controle mediante el input "Mood". El código ya está listo para esto.
      
      _errorInput?.value = false;
      final chatState = ref.read(chatControllerProvider);
      _downloadInput?.value = chatState.isLoading ? 1.0 : 0.0;
      _moodInput?.value = ref.read(botMoodProvider).toDouble();
      _lookXInput?.value = 50;
      _lookYInput?.value = 50;
      // UX PREMIUM: valores iniciales de inputs opcionales
      _isTypingInput?.value = ref.read(userIsTypingProvider);
      _hoveredInput?.value = ref.read(avatarHoveredProvider);
      _anticipatingInput?.value = false;
      _reducedMotionInput?.value = ref.read(reducedMotionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final riveFileAsync = widget.isBubble
        ? ref.watch(riveHeadFileLoaderProvider)
        : ref.watch(riveFileLoaderProvider);

    // ⬅️ Reconstruir cuando cambie isLoading para aplicar modo "procesando" al Rive (igual que botlode_web)
    final chatState = ref.watch(chatControllerProvider);

    // Mood: el ticker (_onTick) se encarga de reforzar el valor del input Mood en cada frame
    // leyendo directamente de botMoodProvider. Este listener solo actualiza _savedMood como cache.
    ref.listen(botMoodProvider, (prev, next) {
      _savedMood = next;
      if (_moodInput != null) {
        _moodInput!.value = next.toDouble();
        _moodEnforceCounter = 0;
      }
    });

    // Download (modo "procesando") y anticipación
    ref.listen(chatControllerProvider, (prev, next) {
      if (_downloadInput != null) {
        _downloadInput!.value = next.isLoading ? 1.0 : 0.0;
      }
      if (prev != null && prev.isLoading && !next.isLoading && _anticipatingInput != null) {
        _anticipatingInput!.value = true;
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _anticipatingInput != null) _anticipatingInput!.value = false;
        });
      }
    });

    // ⬅️ UX PREMIUM: Sincronizar inputs opcionales con providers
    ref.listen(userIsTypingProvider, (_, isTyping) {
      if (_isTypingInput != null) _isTypingInput!.value = isTyping;
    });
    ref.listen(avatarHoveredProvider, (_, hovered) {
      if (_hoveredInput != null) _hoveredInput!.value = hovered;
    });
    ref.listen(avatarListeningTriggerProvider, (_, count) {
      if (count > 0 && _listeningTrigger != null) _listeningTrigger!.fire();
    });
    ref.listen(riveEntryTriggerProvider, (_, count) {
      if (count > 0 && _helloTrigger != null) _helloTrigger!.fire();
    });
    ref.listen(riveExitTriggerProvider, (_, count) {
      if (count > 0 && _goodbyeTrigger != null) _goodbyeTrigger!.fire();
    });
    ref.listen(reducedMotionProvider, (_, reduced) {
      if (_reducedMotionInput != null) _reducedMotionInput!.value = reduced;
    });

    // ⬅️ Aplicar modo "procesando" (Download 1.0) cuando isLoading; 0.0 cuando no (como botlode_web)
    if (_downloadInput != null) {
      _downloadInput!.value = chatState.isLoading ? 1.0 : 0.0;
    }

    // ⬅️ Tamaño según contexto: size explícito, burbuja 68, chat completo 300
    final double avatarSize = widget.size ?? (widget.isBubble ? 68.0 : 300.0);

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