// Archivo: lib/features/player/presentation/widgets/floating_head_widget.dart
import 'dart:math' as math;
import 'dart:ui'; 
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

class FloatingHeadWidget extends ConsumerStatefulWidget {
  const FloatingHeadWidget({super.key});

  @override
  ConsumerState<FloatingHeadWidget> createState() => _FloatingHeadWidgetState();
}

class _FloatingHeadWidgetState extends ConsumerState<FloatingHeadWidget> with SingleTickerProviderStateMixin {
  StateMachineController? _controller;
  SMINumber? _lookXInput;
  SMINumber? _lookYInput;

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

    // --- FÍSICA OPTIMIZADA ---
    // Tracking = 1.0 (Instantáneo). Sin delay para seguir el mouse.
    // Idle = 0.02 (Muy lento). Efecto cinemático al volver al centro.
    final double smoothFactor = _isTracking ? 1.0 : 0.02;

    // --- CALIBRACIÓN DE ARCHIVO ---
    // Ajuste vertical para compensar el offset de tu archivo Rive
    double calibratedTargetY = _targetY - 15.0; 
    calibratedTargetY = calibratedTargetY.clamp(0.0, 100.0);

    _currentX = lerpDouble(_currentX, _targetX, smoothFactor) ?? 50;
    _currentY = lerpDouble(_currentY, calibratedTargetY, smoothFactor) ?? 50;

    _lookXInput!.value = _currentX;
    _lookYInput!.value = _currentY;
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller == null) {
       controller = StateMachineController.fromArtboard(artboard, 'State Machine');
    }

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;
      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');
    }
  }

  @override
  Widget build(BuildContext context) {
    final riveHeadAsync = ref.watch(riveHeadFileLoaderProvider);
    const double verticalOffset = 0.0; 

    ref.listen(pointerPositionProvider, (prev, deltaPos) {
      if (deltaPos == null) return;
      
      final double dx = deltaPos.dx;
      final double dy = deltaPos.dy;

      final double distance = math.sqrt(dx * dx + dy * dy);
      const double maxInterestDistance = 400.0; 

      if (distance < maxInterestDistance) {
        _isTracking = true; 
        const double sensitivity = 200.0; 
        _targetX = (50 + (dx / sensitivity * 50)).clamp(0.0, 100.0);
        _targetY = (50 + (dy / sensitivity * 50)).clamp(0.0, 100.0);
      } else {
        _isTracking = false; 
        _targetX = 50.0;
        _targetY = 50.0;
      }
    });

    return SizedBox(
      width: 70, height: 70,
      child: riveHeadAsync.when(
        data: (riveFile) {
          return Transform.translate(
            offset: const Offset(0, verticalOffset), 
            child: Transform.scale(
              scale: 1.35, 
              child: RiveAnimation.direct(riveFile, fit: BoxFit.cover, onInit: _onRiveInit),
            ),
          );
        },
        loading: () => const SizedBox(), 
        error: (_, __) => const Icon(Icons.smart_toy, color: Colors.white),
      ),
    );
  }
}