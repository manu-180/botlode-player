// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Necesario para Ticker
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rv; 

class RiveAvatar extends ConsumerStatefulWidget {
  final String mood;
  const RiveAvatar({super.key, required this.mood});

  @override
  ConsumerState<RiveAvatar> createState() => _RiveAvatarState();
}

// Agregamos SingleTickerProviderStateMixin para la animación fluida
class _RiveAvatarState extends ConsumerState<RiveAvatar> with SingleTickerProviderStateMixin {
  final GlobalKey _riveKey = GlobalKey();
  
  rv.RiveWidgetController? _controller;
  rv.ViewModelInstanceNumber? _mouseXProp, _mouseYProp;
  
  // Variables para la interpolación (Suavizado)
  late Ticker _ticker;
  double _currentX = 50.0; // Empieza en el centro (0-100)
  double _currentY = 50.0;
  double _targetX = 50.0;  // A dónde queremos ir
  double _targetY = 50.0;

  @override
  void initState() {
    super.initState();
    _setupRive();
    
    // Iniciamos el loop de animación
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Este método se ejecuta 60 veces por segundo
  void _onTick(Duration elapsed) {
    if (_controller == null) return;

    // 1. LEER EL OBJETIVO (TARGET)
    // Usamos read en lugar de watch para no reconstruir el widget, solo leer el valor
    final globalMousePos = ref.read(pointerPositionProvider);
    
    _calculateTarget(globalMousePos);

    // 2. INTERPOLACIÓN LINEAL (LERP) - La clave de la suavidad
    // "Acércate un 10% a tu destino en cada frame"
    // Ajusta el 0.1: Más bajo (0.05) = más lento/pesado. Más alto (0.3) = más rápido/robótico.
    const double speed = 0.1; 
    
    _currentX += (_targetX - _currentX) * speed;
    _currentY += (_targetY - _currentY) * speed;

    // 3. APLICAR A RIVE
    _mouseXProp?.value = _currentX;
    _mouseYProp?.value = _currentY;
  }

  void _calculateTarget(Offset? globalPosition) {
    // Si no hay mouse (null), el objetivo es el centro (50, 50)
    if (globalPosition == null) {
      _targetX = 50.0;
      _targetY = 50.0;
      return;
    }

    final renderBox = _riveKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Convertir Global a Local
    final localOffset = renderBox.globalToLocal(globalPosition);

    // Mapear a 0-100
    // clamp(0, 100) asegura que si el mouse se pasa de la pantalla, el valor no se rompa
    _targetX = ((localOffset.dx / renderBox.size.width) * 100).clamp(0.0, 100.0);
    _targetY = ((localOffset.dy / renderBox.size.height) * 100).clamp(0.0, 100.0);
  }

  Future<void> _setupRive() async {
    try {
      final ByteData data = await rootBundle.load('assets/animations/bot.riv');
      final file = await rv.File.decode(
        data.buffer.asUint8List(), 
        riveFactory: rv.Factory.rive,
      );
      
      if (file == null) return;

      final controller = rv.RiveWidgetController(file);
      final viewModel = controller.dataBind(rv.DataBind.auto());
      
      if (viewModel != null) {
        _mouseXProp = viewModel.number('mouseX');
        _mouseYProp = viewModel.number('mouseY');
      }

      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('❌ Rive Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return rv.RiveWidget(
      key: _riveKey,
      controller: _controller!,
      fit: rv.Fit.contain,
    );
  }
}