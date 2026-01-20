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
  
  // Variables de animación
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

  // TICKER DE ANIMACIÓN (60 FPS)
  void _onTick(Duration elapsed) {
    if (_lookXInput == null || _lookYInput == null) return;

    final double smoothFactor = _isTracking ? 0.3 : 0.05; // Más rápido si sigue al mouse

    _currentX = lerpDouble(_currentX, _targetX, smoothFactor) ?? 50;
    _currentY = lerpDouble(_currentY, _targetY, smoothFactor) ?? 50;

    _lookXInput!.value = _currentX;
    _lookYInput!.value = _currentY;
  }

  // INICIALIZACIÓN DE RIVE (DEBUG MODE)
  void _onRiveInit(Artboard artboard) {
    // 1. INSPECCIÓN (Para que me digas qué sale en consola)
    print("🤖 [RIVE INSPECTOR] State Machines encontradas: ${artboard.stateMachines.map((e) => e.name).toList()}");
    
    // 2. BUSQUEDA DE CONTROLADOR
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    controller ??= StateMachineController.fromArtboard(artboard, 'State Machine');
    controller ??= StateMachineController.fromArtboard(artboard, 'Main'); // Intento extra

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;
      
      // 3. INSPECCIÓN DE INPUTS
      print("🤖 [RIVE INSPECTOR] Inputs disponibles: ${controller.inputs.map((e) => e.name).toList()}");

      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');
      
      // Fallbacks comunes por si se llaman diferente
      if (_lookXInput == null) _lookXInput = controller.getNumberInput('xAxis');
      if (_lookYInput == null) _lookYInput = controller.getNumberInput('yAxis');

      if (_lookXInput == null) print("⚠️ ALERTA: No se encontró input para Eje X");
    } else {
      print("🔴 ERROR CRÍTICO: No se encontró ninguna State Machine válida.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final riveHeadAsync = ref.watch(riveHeadFileLoaderProvider);
    const double verticalOffset = 0.0; 

    // LISTENER DE POSICIÓN (Relativa al Bot)
    ref.listen(pointerPositionProvider, (prev, deltaPos) {
      if (deltaPos == null) return;
      
      // deltaPos ahora contiene la distancia (dx, dy) desde el centro del bot
      final double dx = deltaPos.dx;
      final double dy = deltaPos.dy;

      final double distance = math.sqrt(dx * dx + dy * dy);
      const double maxInterestDistance = 800.0; 

      if (distance < maxInterestDistance) {
        _isTracking = true; 
        // Sensibilidad: Qué tan lejos tengo que mover el mouse para que el ojo llegue al tope (0 o 100)
        // 500px parece razonable para una pantalla de escritorio
        const double sensitivity = 500.0; 
        
        // Fórmula: Centro (50) + (Distancia / Sensibilidad * Rango 50)
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
              scale: 1.3, 
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