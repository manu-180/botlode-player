import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logOverlay(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🛰 [GlobalConnectivityOverlay] $message');
  }
}

/// Overlay de conectividad refactorizado.
///
/// - **Cuando el usuario desconecta WiFi:** no se muestra ningún rectángulo,
///   banner ni cartel. Cero UI de offline.
/// - **Cuando se restablece la conexión:** se muestra un breve mensaje
///   "Conexión restablecida" (1,5 s) y desaparece.
/// - No bloquea la interacción. Respeta tema claro/oscuro.
class GlobalConnectivityOverlay extends ConsumerWidget {
  const GlobalConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final isDarkMode = botConfig?.isDarkMode ?? true;
    final isOnline = ref.watch(connectivityProvider);
    final isChatOpen = ref.watch(chatOpenProvider);

    _logOverlay('build → isOnline=$isOnline, isChatOpen=$isChatOpen');

    return IgnorePointer(
      ignoring: true,
      child: _GlobalConnectivityBanner(
        isOnline: isOnline,
        isDarkMode: isDarkMode,
        isChatOpen: isChatOpen,
      ),
    );
  }
}

class _GlobalConnectivityBanner extends StatefulWidget {
  final bool isOnline;
  final bool isDarkMode;
  final bool isChatOpen;

  const _GlobalConnectivityBanner({
    required this.isOnline,
    required this.isDarkMode,
    required this.isChatOpen,
  });

  @override
  State<_GlobalConnectivityBanner> createState() =>
      _GlobalConnectivityBannerState();
}

class _GlobalConnectivityBannerState extends State<_GlobalConnectivityBanner> {
  bool _showReconnected = false;

  @override
  void didUpdateWidget(covariant _GlobalConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOnline && widget.isOnline) {
      _logOverlay('Transición offline → online: mostrando banner breve');
      setState(() => _showReconnected = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _showReconnected = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nada cuando está offline. Solo mostrar banner al volver online.
    final isVisible = widget.isOnline && _showReconnected;

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final bool dark = widget.isDarkMode;
    final Color onlineDeep =
        dark ? const Color(0xFF0B4F29) : const Color(0xFF1B5E20);
    final Color onlineGlow =
        dark ? const Color(0xFF00E676) : const Color(0xFF69F0AE);

    final String text =
        "Conexión restablecida · El asistente vuelve a estar en línea.";
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;
    const double desktopChatWidth = 380.0;
    const double desktopChatPadding = 28.0;
    final double rightInset = (!isMobile && widget.isChatOpen)
        ? (desktopChatWidth + desktopChatPadding + 16.0)
        : 16.0;

    final Widget banner = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              onlineGlow.withOpacity(dark ? 0.92 : 0.88),
              onlineDeep.withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(dark ? 0.22 : 0.30),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: onlineGlow.withOpacity(dark ? 0.70 : 0.55),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.70 : 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(dark ? 0.28 : 0.10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.35 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.4,
                  decoration: TextDecoration.none,
                  fontFamily: 'Courier',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      bottom: 12,
      left: 16,
      right: rightInset,
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: 1.0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      isMobile ? size.width - 32 : (size.width * 0.55),
                ),
                child: banner,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
