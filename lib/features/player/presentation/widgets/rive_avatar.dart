// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'dart:ui'; 
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/head_tracking_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/loader_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

class BotAvatarWidget extends ConsumerStatefulWidget {
  const BotAvatarWidget({super.key});

  @override
  ConsumerState<BotAvatarWidget> createState() => _BotAvatarWidgetState();
}

class _BotAvatarWidgetState extends ConsumerState<BotAvatarWidget> with SingleTickerProviderStateMixin {
  StateMachineController? _controller;
  SMINumber? _moodInput;
  SMINumber? _lookXInput;
  SMINumber? _lookYInput;
  SMIBool? _errorInput;

  late Ticker _ticker;
  double _targetX = 50.0;
  double _targetY = 50.0;
  double _currentX = 50.0;
  double _currentY = 50.0;
  
  bool _isTracking = false;

  final String _stateMachineName = 'State Machine';
  final String _artboardName = 'Catbot';

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
    
    // LÓGICA PURA: 
    // Tracking = 1.0 (Sin lag). 
    // Reposo = 0.05 (Suave).
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
      _moodInput = controller.getNumberInput('Mood');
      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');
      _errorInput = controller.getBoolInput('Error');
      _errorInput?.value = false;
      _moodInput?.value = ref.read(botMoodProvider).toDouble();
      _lookXInput?.value = 50; 
      _lookYInput?.value = 50; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final riveFileAsync = ref.watch(riveFileLoaderProvider);

    // Listener para cambios de mood
    ref.listen(botMoodProvider, (prev, next) {
       if (_moodInput != null) _moodInput!.value = next.toDouble();
    });

    // Escuchamos el estado de tracking calculado por el provider
    final trackingState = ref.watch(botAvatarTrackingProvider);
    
    // Actualizamos las variables locales con los valores calculados
    _targetX = trackingState.targetX;
    _targetY = trackingState.targetY;
    _isTracking = trackingState.isTracking;

    return SizedBox(
      width: 300, height: 300,
      child: riveFileAsync.when(
        data: (riveFile) {
          return RiveAnimation.direct(
            riveFile, artboard: _artboardName, fit: BoxFit.contain, onInit: _onRiveInit,
          );
        },
        loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC000)))), 
        error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text("Error: $err", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 10)))),
      ),
    );
  }
}