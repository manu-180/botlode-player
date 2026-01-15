// Archivo: lib/features/player/presentation/widgets/rive_avatar.dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class RiveAvatar extends StatefulWidget {
  final String mood; 

  const RiveAvatar({super.key, required this.mood});

  @override
  State<RiveAvatar> createState() => _RiveAvatarState();
}

class _RiveAvatarState extends State<RiveAvatar> {
  // VOLVEMOS A LA SINTAXIS ESTABLE (Rive 0.13.4)
  SMIBool? _isTalking;
  SMITrigger? _triggerHappy;
  SMITrigger? _triggerConfused;

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller != null) {
      artboard.addController(controller);
      // Sintaxis antigua y confiable
      _isTalking = controller.findInput<bool>('isTalking') as SMIBool?;
      _triggerHappy = controller.findInput<bool>('happy') as SMITrigger?;
      _triggerConfused = controller.findInput<bool>('confused') as SMITrigger?;
    }
  }

  @override
  void didUpdateWidget(covariant RiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != oldWidget.mood) {
      if (widget.mood == 'happy') _triggerHappy?.fire();
      if (widget.mood == 'confused') _triggerConfused?.fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/animations/bot.riv', 
      fit: BoxFit.cover,
      onInit: _onRiveInit, 
    );
  }
}