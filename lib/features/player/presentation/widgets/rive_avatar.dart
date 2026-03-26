// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'dart:async';
import 'dart:ui';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/head_tracking_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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
  /// Brazo siguiendo el mouse: mismos valores que LookX/LookY cuando hay hover (opcional en .riv).
  SMINumber? _armLookXInput;
  SMINumber? _armLookYInput;
  SMIBool? _errorInput;
  SMINumber? _downloadInput;

  // ⬅️ UX PREMIUM: inputs opcionales (si el .riv los tiene, se usan)
  // --- Saludo Hello (gesto ENTRY/EXIT): desactivado temporalmente para producción ---
  // SMITrigger? _helloTrigger;
  SMIBool? _hoveredInput;
  SMIBool? _hoverFromRightInput; // true = derecha, false = izquierda
  SMIBool? _hoverFromTopInput;   // true = arriba, false = abajo → 4 cuadrantes
  SMITrigger? _listeningTrigger;
  SMITrigger? _gestureTopLeftTrigger;
  SMITrigger? _gestureTopRightTrigger;
  SMITrigger? _gestureBottomLeftTrigger;
  SMITrigger? _gestureBottomRightTrigger;
  /// Modo "manotazo dirigido": dispara una animación one-shot al objetivo actual.
  SMITrigger? _strikeTrigger;
  SMINumber? _strikeTargetXInput;
  SMINumber? _strikeTargetYInput;
  SMIBool? _strikeUseRightHandInput;
  SMIBool? _isTypingInput;

  /// Cuadrante actual del hover (0=TL, 1=TR, 2=BL, 3=BR). Null cuando no hay hover.
  int? _lastHoverQuadrant;
  static const _quadrantCooldown = Duration(milliseconds: 1200);
  final List<DateTime?> _lastQuadrantFireTime = List.filled(4, null);
  static const _strikeCooldown = Duration(milliseconds: 650);
  static const double _minStrikeDistance = 8.0;
  DateTime? _lastStrikeFireTime;
  double _lastStrikeX = 50.0;
  double _lastStrikeY = 50.0;

  /// Ciclo "manotazo": ir a la posición del mouse → volver a reposo → repetir (no seguimiento continuo).
  static const int _strikeOutMs = 220;   // ms que la mano va hacia el objetivo
  static const int _strikeReturnMs = 380; // ms que la mano vuelve a 50/50
  DateTime? _strikeCycleStartTime;
  double _capturedStrikeX = 50.0;
  double _capturedStrikeY = 50.0;

  /// Logs de depuración para gestos por cuadrante (poner true para ver en consola).
  static const bool _debugQuadrantGestures = false;
  static const bool _debugStrikeGestures = true;
  /// Logs para StrikeTarget/HandTarget (hover + valores enviados).
  static const bool _debugHandTarget = true;
  int _tickCount = 0;
  bool _lastHoveredForLog = false;

  late Ticker _ticker;
  /// Timer independiente del Ticker para reforzar el mood en iframe/embed (evita parpadeo a neutral cuando rAF se throttlea).
  Timer? _moodReinforceTimer;
  double _targetX = 50.0;
  double _targetY = 50.0;
  double _currentX = 50.0;
  double _currentY = 50.0;

  bool _isTracking = false;
  bool _wasTrackingPreviously = false;
  int _trackingFrames = 0;

  // --- Hello ENTRY/EXIT (retomar junto con listeners y bloque en _onRiveInit) ---
  // static const _helloCooldown = Duration(milliseconds: 1500);
  // DateTime? _lastEntryFireTime;
  // DateTime? _lastExitFireTime;
  // static const List<String> _helloTriggerCandidates = <String>[
  //   'Hello',
  //   'Gesture Hello',
  //   'GestureHello',
  //   'gesture_hello',
  // ];

  /// Sensibilidad y rango: 450px máximo para que no siga por toda la pantalla
  double get _sensitivity => widget.isBubble ? 400.0 : 600.0;
  double get _maxDistance => 450.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    // Refuerzo de mood por timer: en iframe/embed el Ticker puede pausarse (throttling), y la state machine
    // de Rive vuelve a neutral por exit-time. Este timer mantiene el mood estable sin depender del frame rate.
    _moodReinforceTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      try {
        final mood = ref.read(botMoodProvider).toDouble();
        if (_moodInput != null) _moodInput!.value = mood;
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _moodReinforceTimer?.cancel();
    _moodReinforceTimer = null;
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _tryFireStrike({
    required double targetX,
    required double targetY,
  }) {
    if (_strikeTrigger == null || _strikeTargetXInput == null || _strikeTargetYInput == null) {
      return;
    }
    final now = DateTime.now();
    final bool cooldownOk = _lastStrikeFireTime == null ||
        now.difference(_lastStrikeFireTime!) >= _strikeCooldown;
    final dx = targetX - _lastStrikeX;
    final dy = targetY - _lastStrikeY;
    final bool movedEnough = (dx * dx + dy * dy) >= (_minStrikeDistance * _minStrikeDistance);
    if (!cooldownOk || !movedEnough) return;

    _strikeTargetXInput!.value = targetX;
    _strikeTargetYInput!.value = targetY;
    if (_strikeUseRightHandInput != null) {
      _strikeUseRightHandInput!.value = targetX >= 50.0;
    }
    _strikeTrigger!.fire();
    _lastStrikeFireTime = now;
    _lastStrikeX = targetX;
    _lastStrikeY = targetY;
    if (_debugStrikeGestures) {
      debugPrint('[Rive Strike] fire() x=${targetX.toStringAsFixed(1)} y=${targetY.toStringAsFixed(1)} '
          'hand=${targetX >= 50.0 ? "right" : "left"}');
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _lookXInput == null || _lookYInput == null) return;

    final bool hovered = ref.read(avatarHoveredProvider);
    final bool enableBodyGestures = !widget.isBubble;
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

      // Cuadrantes/strike solo para avatar completo (chat), no para burbuja de cabeza.
      if (enableBodyGestures && hovered && globalPointer != null) {
        final fromRight = globalPointer.dx > widgetCenter.dx;
        final fromTop = globalPointer.dy < widgetCenter.dy; // Y menor = arriba
        if (_hoverFromRightInput != null) _hoverFromRightInput!.value = fromRight;
        if (_hoverFromTopInput != null) _hoverFromTopInput!.value = fromTop;
        // Modo pro: objetivo continuo + trigger one-shot (si el .riv tiene Strike + targets).
        final strikeTargetY = (_targetY - 15.0).clamp(0.0, 100.0);
        if (_strikeTrigger != null && _strikeTargetXInput != null && _strikeTargetYInput != null) {
          _tryFireStrike(targetX: _targetX, targetY: strikeTargetY);
        } else {
          // Fallback legacy: cuadrantes
          final quadrant = (fromRight ? 1 : 0) + (fromTop ? 0 : 2); // 0=TL, 1=TR, 2=BL, 3=BR
          if (quadrant != _lastHoverQuadrant) {
            final now = DateTime.now();
            final cooldownOk = _lastQuadrantFireTime[quadrant] == null ||
                now.difference(_lastQuadrantFireTime[quadrant]!) >= _quadrantCooldown;
            if (_debugQuadrantGestures) {
              const names = ['TopLeft', 'TopRight', 'BottomLeft', 'BottomRight'];
              debugPrint('[Rive Quadrant] cambio → $quadrant (${names[quadrant]}): '
                  'fromRight=$fromRight fromTop=$fromTop cooldownOk=$cooldownOk '
                  'triggerTL=${_gestureTopLeftTrigger != null}');
            }
            _lastHoverQuadrant = quadrant;
            if (cooldownOk) {
              _lastQuadrantFireTime[quadrant] = now;
              switch (quadrant) {
                case 0:
                  _gestureTopLeftTrigger?.fire();
                  break;
                case 1:
                  _gestureTopRightTrigger?.fire();
                  break;
                case 2:
                  _gestureBottomLeftTrigger?.fire();
                  break;
                case 3:
                  _gestureBottomRightTrigger?.fire();
                  break;
              }
            }
          }
        }
      } else {
        _lastHoverQuadrant = null;
      }
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

    _tickCount++;
    try {
      _lookXInput!.value = _currentX;
      _lookYInput!.value = _currentY;
      // StrikeTargetX/Y solo en avatar completo (chat). Modo "manotazo": ir a posición → volver a reposo → repetir.
      if (enableBodyGestures && _strikeTargetXInput != null && _strikeTargetYInput != null) {
        if (hovered) {
          final now = DateTime.now();
          if (_strikeCycleStartTime == null) {
            _strikeCycleStartTime = now;
            _capturedStrikeX = _currentX;
            _capturedStrikeY = _currentY;
          }
          int elapsedMs = now.difference(_strikeCycleStartTime!).inMilliseconds;
          final cycleLength = _strikeOutMs + _strikeReturnMs;
          if (elapsedMs >= cycleLength) {
            _strikeCycleStartTime = now;
            _capturedStrikeX = _currentX;
            _capturedStrikeY = _currentY;
            elapsedMs = 0;
          }
          final inOutPhase = elapsedMs < _strikeOutMs;
          final sendX = inOutPhase ? _capturedStrikeX : 50.0;
          final sendY = inOutPhase ? _capturedStrikeY : 50.0;
          _strikeTargetXInput!.value = sendX;
          _strikeTargetYInput!.value = sendY;
          if (_strikeUseRightHandInput != null) {
            _strikeUseRightHandInput!.value = sendX >= 50.0;
          }
          if (_debugHandTarget) {
            if (!_lastHoveredForLog) {
              debugPrint('[HandTarget] hover ENTRÓ → modo manotazo (ir → volver → repetir)');
              _lastHoveredForLog = true;
            } else if (_tickCount % 90 == 0) {
              debugPrint('[HandTarget] fase=${inOutPhase ? "ir" : "volver"} enviando X=${sendX.toStringAsFixed(1)} Y=${sendY.toStringAsFixed(1)}');
            }
          }
        } else {
          _strikeCycleStartTime = null;
          _strikeTargetXInput!.value = 50.0;
          _strikeTargetYInput!.value = 50.0;
          if (_debugHandTarget && _lastHoveredForLog) {
            debugPrint('[HandTarget] hover SALIÓ → enviando 50, 50');
            _lastHoveredForLog = false;
          }
        }
      } else if (_debugHandTarget && enableBodyGestures && hovered && _tickCount % 90 == 0) {
        debugPrint('[HandTarget] hover=true pero StrikeTargetX o StrikeTargetY son null (¿inputs en .riv?)');
      }
      if (_debugHandTarget && enableBodyGestures && _tickCount % 120 == 0) {
        debugPrint('[HandTarget] estado: hovered=$hovered strikeInputs=${_strikeTargetXInput != null && _strikeTargetYInput != null} look=($_currentX, $_currentY)');
      }
      // ArmLook (si existe y no usamos Strike/Blend): brazo sigue al mouse continuo.
      if (_armLookXInput != null && _armLookYInput != null) {
        final hasStrikeInputs = _strikeTargetXInput != null && _strikeTargetYInput != null;
        if (hovered && !hasStrikeInputs) {
          _armLookXInput!.value = _currentX;
          _armLookYInput!.value = _currentY;
        } else {
          _armLookXInput!.value = 50.0;
          _armLookYInput!.value = 50.0;
        }
      }
    } catch (_) {}

    // Enforcement continuo del mood: re-aplicar el valor en cada frame para que la state machine
    // de Rive no vuelva a idle por exit-time. Sin toggle a 0 para evitar parpadeos.
    if (_moodInput != null) {
      try {
        _moodInput!.value = ref.read(botMoodProvider).toDouble();
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
      _armLookXInput = controller.getNumberInput('ArmLookX');
      _armLookYInput = controller.getNumberInput('ArmLookY');
      _errorInput = controller.getBoolInput('Error');
      _downloadInput = controller.getNumberInput('Download'); // ⬅️ Modo "procesando" (como botlode_web)

      // UX: saludo Hello (ENTRY/EXIT) — desactivado temporalmente para producción.
      // for (final name in _helloTriggerCandidates) {
      //   _helloTrigger = controller.getTriggerInput(name);
      //   if (_helloTrigger != null) {
      //     debugPrint('[Rive Hello] _onRiveInit: trigger "$name" OK');
      //     break;
      //   }
      // }
      // if (_helloTrigger == null) {
      //   debugPrint('[Rive Hello] _onRiveInit: trigger Hello no encontrado (aliases: $_helloTriggerCandidates)');
      // }
      // if (_helloTrigger != null) {
      //   final exit = ref.read(riveExitTriggerProvider);
      //   if (exit > 0) {
      //     SchedulerBinding.instance.addPostFrameCallback((_) {
      //       if (!mounted || _helloTrigger == null) return;
      //       if (_lastExitFireTime != null && DateTime.now().difference(_lastExitFireTime!) < _helloCooldown) return;
      //       _lastExitFireTime = DateTime.now();
      //       _helloTrigger!.fire();
      //       debugPrint('[Rive Hello] fire() en init (exit pendiente)');
      //     });
      //   }
      // }
      _listeningTrigger = controller.getTriggerInput('Listening');
      _hoveredInput = controller.getBoolInput('Hovered');
      _hoverFromRightInput = controller.getBoolInput('HoverFromRight');
      _hoverFromTopInput = controller.getBoolInput('HoverFromTop');
      _gestureTopLeftTrigger = controller.getTriggerInput('GestureTopLeft');
      _gestureTopRightTrigger = controller.getTriggerInput('GestureTopRight');
      _gestureBottomLeftTrigger = controller.getTriggerInput('GestureBottomLeft');
      _gestureBottomRightTrigger = controller.getTriggerInput('GestureBottomRight');
      _strikeTrigger = controller.getTriggerInput('Strike');
      _strikeTargetXInput = controller.getNumberInput('StrikeTargetX');
      _strikeTargetYInput = controller.getNumberInput('StrikeTargetY');
      _strikeUseRightHandInput = controller.getBoolInput('StrikeUseRightHand');
      _isTypingInput = controller.getBoolInput('IsTyping');
      if (!widget.isBubble) {
        if (_strikeTrigger != null && _strikeTargetXInput != null && _strikeTargetYInput != null) {
          debugPrint('[Rive Strike] modo strike habilitado (Strike + StrikeTargetX/Y detectados)');
          if (_debugHandTarget) {
            debugPrint('[HandTarget] StrikeTargetX y StrikeTargetY encontrados → el brazo puede seguir al mouse');
          }
        } else {
          if (_debugStrikeGestures) {
            debugPrint('[Rive Strike] modo strike NO activo (faltan inputs en .riv), usando fallback por cuadrantes');
          }
          if (_debugHandTarget) {
            debugPrint('[HandTarget] StrikeTargetX o StrikeTargetY NO encontrados → revisar nombres en State Machine del .riv');
          }
        }
      }

      // ⬅️ NOTA: Para que el círculo cambie de color según el estado emocional,
      // debes configurar en Rive que el color del círculo de "Face download" 
      // se controle mediante el input "Mood". El código ya está listo para esto.
      
      _errorInput?.value = false;
      final chatState = ref.read(chatControllerProvider);
      _downloadInput?.value = chatState.isLoading ? 1.0 : 0.0;
      _moodInput?.value = ref.read(botMoodProvider).toDouble();
      _lookXInput?.value = 50;
      _lookYInput?.value = 50;
      if (_armLookXInput != null) _armLookXInput!.value = 50;
      if (_armLookYInput != null) _armLookYInput!.value = 50;
      if (_strikeTargetXInput != null) _strikeTargetXInput!.value = 50;
      if (_strikeTargetYInput != null) _strikeTargetYInput!.value = 50;
      // UX PREMIUM: valores iniciales de inputs opcionales
      _isTypingInput?.value = ref.read(userIsTypingProvider);
      _hoveredInput?.value = ref.read(avatarHoveredProvider);
      _hoverFromRightInput?.value = true;
      _hoverFromTopInput?.value = true; // el ticker actualiza ambos al hacer hover (4 cuadrantes)
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
    // leyendo directamente de botMoodProvider.
    ref.listen(botMoodProvider, (prev, next) {
      if (_moodInput != null) _moodInput!.value = next.toDouble();
    });

    // Download (modo "procesando")
    ref.listen(chatControllerProvider, (prev, next) {
      if (_downloadInput != null) {
        _downloadInput!.value = next.isLoading ? 1.0 : 0.0;
      }
    });

    // ⬅️ UX PREMIUM: Sincronizar inputs opcionales con providers
    ref.listen(userIsTypingProvider, (_, isTyping) {
      if (_isTypingInput != null) _isTypingInput!.value = isTyping;
    });
    // Hover en avatar (input Rive Hovered): desactivado temporalmente (producción).
    // ref.listen(avatarHoveredProvider, (_, hovered) {
    //   if (_hoveredInput != null) _hoveredInput!.value = hovered;
    // });
    ref.listen(avatarListeningTriggerProvider, (_, count) {
      if (count > 0 && _listeningTrigger != null) _listeningTrigger!.fire();
    });
    // ref.listen(riveEntryTriggerProvider, (_, count) {
    //   if (count <= 0) return;
    //   if (_helloTrigger == null) {
    //     debugPrint('[Rive Hello] ENTRY count=$count pero _helloTrigger=null (avatar aún no init o .riv sin Hello)');
    //     return;
    //   }
    //   if (_lastEntryFireTime != null && DateTime.now().difference(_lastEntryFireTime!) < _helloCooldown) {
    //     debugPrint('[Rive Hello] ENTRY count=$count skip por cooldown');
    //     return;
    //   }
    //   _lastEntryFireTime = DateTime.now();
    //   _helloTrigger!.fire();
    //   debugPrint('[Rive Hello] ENTRY fire() OK');
    // });
    // ref.listen(riveExitTriggerProvider, (_, count) {
    //   if (count <= 0) return;
    //   if (_helloTrigger == null) {
    //     debugPrint('[Rive Hello] EXIT count=$count pero _helloTrigger=null (avatar aún no init o .riv sin Hello)');
    //     return;
    //   }
    //   if (_lastExitFireTime != null && DateTime.now().difference(_lastExitFireTime!) < _helloCooldown) {
    //     debugPrint('[Rive Hello] EXIT count=$count skip por cooldown');
    //     return;
    //   }
    //   _lastExitFireTime = DateTime.now();
    //   _helloTrigger!.fire();
    //   debugPrint('[Rive Hello] EXIT fire() OK');
    // });

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
              riveFile,
              fit: widget.isBubble ? BoxFit.cover : BoxFit.contain,
              onInit: _onRiveInit,
            ),
          );
        },
        loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC000)))), 
        error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text("Error: $err", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 10)))),
      ),
    );
  }
}