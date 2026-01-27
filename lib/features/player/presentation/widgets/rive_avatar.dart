// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'dart:ui'; 
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
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
    
    // LÓGICA PURA: Tracking sin lag, reposo suave.
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

    if (widget.isBubble) {
      // --- MODO BURBUJA ---
      // Posición fija: bottom: 40, right: 40.
      // Contenedor ancho variable, pero Avatar pegado a la derecha.
      // Margen derecho total: 40 (screen) + 7 (margin container) + 29 (mitad avatar) ≈ 76px
      // Margen inferior total: 40 (screen) + 7 (margin container) + 29 (mitad avatar) ≈ 76px
      myCenter = Offset(screenSize.width - 76, screenSize.height - 76);
      sensitivity = 350.0; // Rango medio para la burbuja
    } else {
      // --- MODO CHAT PANEL ---
      // Ancho Panel: 380px. Padding right: 28px.
      // Centro X del panel = ScreenWidth - 28 (padding) - (380 / 2) = ScreenWidth - 218
      final double chatCenterX = screenSize.width - 28 - 190;
      
      // Chat desde bottom: 28px. Header: 180px. Avatar en medio del header.
      // Centro Y Avatar = ScreenHeight - 28 (padding bottom) - 90 (mitad del header)
      final double chatAvatarCenterY = screenSize.height - 28 - 90;
      
      myCenter = Offset(chatCenterX, chatAvatarCenterY);
      sensitivity = 600.0; // ⬅️ Sensibilidad ajustada
    }

    // 3. DELEGAR CÁLCULO AL CONTROLLER
    final trackingState = HeadTrackingController.calculateGlobalTracking(
      globalPointer: globalPointer,
      widgetCenter: myCenter,
      sensitivity: sensitivity,
    );

    // 4. ACTUALIZAR VARIABLES LOCALES
    _targetX = trackingState.targetX;
    _targetY = trackingState.targetY;
    _isTracking = trackingState.isTracking;

    // Listener para cambios de mood
    ref.listen(botMoodProvider, (prev, next) {
       if (_moodInput != null) _moodInput!.value = next.toDouble();
    });

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