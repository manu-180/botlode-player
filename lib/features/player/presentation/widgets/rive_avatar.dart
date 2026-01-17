import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart'; // ✅ IMPRESCINDIBLE

// -----------------------------------------------------------------------------
// PROVEEDOR DE ESTADO
// -----------------------------------------------------------------------------
// 0: Neutral, 1: Angry, 2: Happy, 3: Sales, 4: Confused, 5: Tech
final botMoodProvider = StateProvider<int>((ref) => 0);

// -----------------------------------------------------------------------------
// WIDGET PRINCIPAL: BOT AVATAR
// -----------------------------------------------------------------------------
class BotAvatarWidget extends ConsumerStatefulWidget {
  const BotAvatarWidget({super.key});

  @override
  ConsumerState<BotAvatarWidget> createState() => _BotAvatarWidgetState();
}

class _BotAvatarWidgetState extends ConsumerState<BotAvatarWidget> {
  // Referencias al controlador de Rive
  StateMachineController? _controller;
  
  // Inputs del State Machine (Tipos específicos de Rive)
  SMINumber? _moodInput;  
  SMINumber? _lookXInput; 
  SMINumber? _lookYInput; 

  // Configuración del archivo Rive
  final String _riveFileName = 'assets/animations/bot.riv'; 
  final String _stateMachineName = 'State Machine 1';
  final String _artboardName = 'Catbot'; 

  @override
  void initState() {
    super.initState();
    // Precarga para evitar lag en el primer render
    rootBundle.load(_riveFileName).then(
      (data) async {
        await RiveFile.initialize();
      },
    ).catchError((e) => debugPrint('⚠️ Error precargando Rive: $e'));
  }

  /// Función de inicialización cuando Rive se carga en pantalla
  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      _stateMachineName,
    );

    if (controller != null) {
      artboard.addController(controller);
      _controller = controller;

      // -------------------------------------------------------
      // CORRECCIÓN TÉCNICA: Usamos getNumberInput en lugar de findInput
      // Esto evita el error de "invalid_assignment" de tipos.
      // -------------------------------------------------------
      _moodInput = controller.getNumberInput('Mood');
      _lookXInput = controller.getNumberInput('LookX');
      _lookYInput = controller.getNumberInput('LookY');

      // Estado inicial seguro
      _moodInput?.value = 0; 
      
      debugPrint('🤖 Rive Controller Inicializado Correctamente');
    } else {
      debugPrint('⚠️ Error: No se encontró la State Machine "$_stateMachineName"');
    }
  }

  /// Lógica para seguir el mouse (Efecto Inmersivo)
  void _onHover(PointerEvent event) {
    if (_lookXInput == null || _lookYInput == null) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Size size = box.size;
    final Offset localPosition = box.globalToLocal(event.position);

    final double xPercent = (localPosition.dx / size.width) * 100;
    final double yPercent = (localPosition.dy / size.height) * 100;

    _lookXInput!.value = xPercent.clamp(0.0, 100.0);
    _lookYInput!.value = yPercent.clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final int currentMood = ref.watch(botMoodProvider);

    // Actualizar Rive cuando cambia el estado de Riverpod
    if (_moodInput != null && _moodInput!.value != currentMood.toDouble()) {
      _moodInput!.value = currentMood.toDouble();
    }

    return SizedBox(
      width: 300, 
      height: 300,
      child: MouseRegion(
        onHover: _onHover, 
        child: RiveAnimation.asset(
          _riveFileName,
          artboard: _artboardName,
          fit: BoxFit.contain,
          onInit: _onRiveInit,
          // Placeholder mientras carga
          placeHolder: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00F0FF), 
            ),
          ),
          // NOTA: Se eliminó 'onError' porque no existe en esta versión de RiveAnimation.
        ),
      ),
    );
  }
}