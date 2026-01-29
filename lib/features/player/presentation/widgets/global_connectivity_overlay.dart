import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logOverlay(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🛰 [GlobalConnectivityOverlay] $message');
  }
}

/// Overlay de conectividad: sin UI cuando está offline.
/// Al restablecerse la conexión muestra un **SnackBar** flotante (poco invasivo)
/// con la misma estética sci‑fi: gradiente verde, icono, tipografía Courier.
class GlobalConnectivityOverlay extends ConsumerWidget {
  const GlobalConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final isDarkMode = botConfig?.isDarkMode ?? true;
    final isOnline = ref.watch(connectivityProvider);

    _logOverlay('build → isOnline=$isOnline');

    return IgnorePointer(
      ignoring: true,
      child: _ConnectivitySnackBarTrigger(
        isOnline: isOnline,
        isDarkMode: isDarkMode,
      ),
    );
  }
}

class _ConnectivitySnackBarTrigger extends StatefulWidget {
  final bool isOnline;
  final bool isDarkMode;

  const _ConnectivitySnackBarTrigger({
    required this.isOnline,
    required this.isDarkMode,
  });

  @override
  State<_ConnectivitySnackBarTrigger> createState() =>
      _ConnectivitySnackBarTriggerState();
}

class _ConnectivitySnackBarTriggerState
    extends State<_ConnectivitySnackBarTrigger> {
  @override
  void didUpdateWidget(covariant _ConnectivitySnackBarTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOnline && widget.isOnline) {
      _logOverlay('Transición offline → online: mostrando SnackBar');
      _showReconnectedSnackBar();
    }
  }

  void _showReconnectedSnackBar() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final dark = widget.isDarkMode;
    final Color onlineDeep =
        dark ? const Color(0xFF0B4F29) : const Color(0xFF1B5E20);
    final Color onlineGlow =
        dark ? const Color(0xFF00E676) : const Color(0xFF69F0AE);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        duration: const Duration(seconds: 2),
        content: _ReconnectedSnackContent(
          isDarkMode: dark,
          onlineDeep: onlineDeep,
          onlineGlow: onlineGlow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Contenido del SnackBar "Conexión restablecida" con estética sci‑fi.
class _ReconnectedSnackContent extends StatelessWidget {
  final bool isDarkMode;
  final Color onlineDeep;
  final Color onlineGlow;

  const _ReconnectedSnackContent({
    required this.isDarkMode,
    required this.onlineDeep,
    required this.onlineGlow,
  });

  @override
  Widget build(BuildContext context) {
    const String text =
        "Conexión restablecida · El asistente vuelve a estar en línea.";
    final dark = isDarkMode;

    return ClipRRect(
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
                style: const TextStyle(
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
  }
}
