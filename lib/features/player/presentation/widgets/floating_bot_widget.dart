// Archivo: lib/features/player/presentation/widgets/floating_bot_widget.dart
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:botlode_player/features/player/presentation/views/chat_panel_view.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingBotWidget extends ConsumerStatefulWidget {
  const FloatingBotWidget({super.key});

  @override
  ConsumerState<FloatingBotWidget> createState() => _FloatingBotWidgetState();
}

class _FloatingBotWidgetState extends ConsumerState<FloatingBotWidget> {
  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(chatOpenProvider);
    final botConfigAsync = ref.watch(botConfigProvider);
    final isHovered = ref.watch(isHoveredExternalProvider);

    // DEBUG:
    print("🎈 [DEBUG BUBBLE] Open: $isOpen | ConfigLoaded: ${botConfigAsync.hasValue}");

    return Stack(
      fit: StackFit.loose, 
      alignment: Alignment.bottomRight,
      children: [
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, 
              onTap: () => ref.read(chatOpenProvider.notifier).set(false),
              child: const SizedBox.expand(), 
            ),
          ),

        Positioned(
          bottom: 0, right: 0,
          child: IgnorePointer(
            ignoring: !isOpen, 
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isOpen ? 1.0 : 0.0,
              child: AnimatedScale(
                scale: isOpen ? 1.0 : 0.9, 
                duration: const Duration(milliseconds: 350),
                child: const SizedBox(height: 700, width: 380, child: ChatPanelView()),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 40, right: 40,
          child: IgnorePointer(
            ignoring: isOpen, 
            child: AnimatedScale(
              scale: isOpen ? 0.0 : 1.0, 
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: () {
                  ref.read(chatOpenProvider.notifier).set(true);
                  html.window.parent?.postMessage('CMD_OPEN', '*');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => ref.read(isHoveredExternalProvider.notifier).state = true,
                  onExit: (_) => ref.read(isHoveredExternalProvider.notifier).state = false,
                  child: botConfigAsync.when(
                    loading: () => _buildCircle(Colors.grey, const Icon(Icons.more_horiz, color: Colors.white)),
                    error: (err, stack) => _buildCircle(Colors.red, const Icon(Icons.error_outline, color: Colors.white)),
                    data: (config) => _buildFloatingButton(isHovered, config.name, config.themeColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(Color color, Widget icon) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: icon),
    );
  }

  Widget _buildFloatingButton(bool isHovered, String name, Color color) {
    const double closedSize = 72.0; 
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: isHovered ? 220.0 : closedSize, 
      height: closedSize, 
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(closedSize / 2),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isHovered) 
            Expanded(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Container(
            width: 58, height: 58, margin: const EdgeInsets.all(7),
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: Icon(Icons.smart_toy_rounded, color: Colors.white.withOpacity(0.5), size: 30)),
                  const BotAvatarWidget(), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}