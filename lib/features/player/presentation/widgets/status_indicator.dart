// Archivo: lib/features/player/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';

class StatusIndicator extends ConsumerStatefulWidget {
  final bool isLoading;
  final bool isOnline;
  final String mood;
  final bool isDarkMode;
  final String? currentSessionId;

  const StatusIndicator({
    super.key,
    required this.isLoading,
    required this.isOnline,
    required this.mood,
    this.currentSessionId,
    this.isDarkMode = true,
  });

  @override
  ConsumerState<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends ConsumerState<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2450), // 200 + 1300 + 800 + 150
    )..repeat();

    // Secuencia: fade in 200ms, hold 1300ms, fade out 800ms, delay 150ms
    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 200,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: 1300,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 800,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: 150,
      ),
    ]).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChatOpen = ref.watch(chatOpenProvider);
    final activeSessionId = ref.watch(activeSessionIdProvider);

    if (!isChatOpen) {
      return const SizedBox.shrink();
    }

    final effectiveCurrentSessionId = widget.currentSessionId ??
        ref.watch(chatControllerProvider).sessionId;

    String text;
    Color color;

    if (!widget.isOnline) {
      text = "DESCONECTADO";
      color = const Color(0xFFFF003C);
    } else {
      switch (widget.mood.toLowerCase()) {
        case 'angry':
          text = "ENOJADO";
          color = const Color(0xFFFF2A00);
          break;
        case 'happy':
          text = "FELIZ";
          color = const Color(0xFFFF00D6);
          break;
        case 'sales':
          text = "VENDEDOR";
          color = const Color(0xFFFFC000);
          break;
        case 'confused':
          text = "CONFUNDIDO";
          color = const Color(0xFF7B00FF);
          break;
        case 'tech':
          text = "TÉCNICO";
          color = const Color(0xFF00F0FF);
          break;
        case 'neutral':
        case 'idle':
        default:
          final bool shouldShowOnline;
          if (!isChatOpen) {
            shouldShowOnline = false;
          } else if (activeSessionId == null || activeSessionId.isEmpty) {
            shouldShowOnline = false;
          } else if (effectiveCurrentSessionId.isEmpty) {
            shouldShowOnline = false;
          } else if (activeSessionId != effectiveCurrentSessionId) {
            shouldShowOnline = false;
          } else {
            shouldShowOnline = true;
          }

          if (shouldShowOnline) {
            text = "EN LÍNEA";
            color = const Color(0xFF00FF94);
          } else {
            text = "";
            color = const Color(0xFF00FF94);
          }
          break;
      }
    }

    final Color bgColor = widget.isDarkMode
        ? const Color(0xFF0A0A0A).withOpacity(0.95)
        : const Color(0xFFFFFFFF).withOpacity(0.95);

    final Color textColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.9)
        : const Color(0xFF2D2D2D);

    final Color borderColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

    final Widget reactorBar = Container(
      width: 4,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: widget.isDarkMode
            ? [
                BoxShadow(color: color, blurRadius: 4, spreadRadius: 1),
                BoxShadow(
                    color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 3),
              ]
            : [
                BoxShadow(
                    color: color.withOpacity(0.6), blurRadius: 2, spreadRadius: 0),
              ],
      ),
    );

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(left: 6, right: 12, top: 6, bottom: 6),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: borderColor, width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            bottomRight: Radius.circular(10),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.6 : 0.1),
            blurRadius: 10,
            offset: const Offset(2, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _blinkAnimation,
            child: reactorBar,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Courier',
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
