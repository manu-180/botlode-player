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

  final String _stateMachineName = 'State Machine 1'; 

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
    final double smoothFactor = _isTracking ? 1.0 : 0.05;
    _currentX = lerpDouble(_currentX, _targetX, smoothFactor) ?? 50;
    _currentY = lerpDouble(_currentY, _targetY, smoothFactor) ?? 50;
    _lookXInput!.value = _currentX;
    _lookYInput!.value = _currentY;
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, _stateMachineName);
    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;
      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');
      _lookXInput?.value = 50;
      _lookYInput?.value = 50;
    } 
  }

  @override
  Widget build(BuildContext context) {
    final riveHeadAsync = ref.watch(riveHeadFileLoaderProvider);
    const double verticalOffset = -8.0; 

    // CORRECCIÓN MATEMÁTICA: Usamos el delta directo
    ref.listen(pointerPositionProvider, (prev, deltaPos) {
      if (deltaPos == null) return;
      
      // 'deltaPos' ya es la distancia calculada por el HTML (dx, dy)
      final double dx = deltaPos.dx;
      final double dy = deltaPos.dy;

      final double distance = math.sqrt(dx * dx + dy * dy);
      const double maxInterestDistance = 600.0; // Rango visual amplio

      if (distance < maxInterestDistance) {
        _isTracking = true; 
        const double sensitivity = 250.0; // Ajustar sensibilidad si los ojos se mueven poco
        // Mapeamos el delta a rango 0-100 para Rive
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
              scale: 1.2, 
              child: RiveAnimation.direct(riveFile, fit: BoxFit.cover, onInit: _onRiveInit),
            ),
          );
        },
        loading: () => const SizedBox(), 
        error: (_, __) => const Icon(Icons.error_outline, color: Colors.red),
      ),
    );
  }
}