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

/// Overlay de conectividad: muestra cartel "Sin conexión" cuando está offline.
/// SOLO se muestra cuando el chat está ABIERTO (iframe grande).
/// En modo burbuja, se confía en: _BubbleOfflineBanner (sobre la burbuja) y el snackbar del HTML padre.
class GlobalConnectivityOverlay extends ConsumerWidget {
  const GlobalConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final isDarkMode = botConfig?.isDarkMode ?? true;
    final showOfflineAlert = botConfig?.showOfflineAlert ?? false;
    final isOnline = ref.watch(connectivityProvider);
    final isChatOpen = ref.watch(chatOpenProvider); // ⬅️ NUEVO: Verificar si el chat está abierto

    _logOverlay('build → isOnline=$isOnline, showOfflineAlert=$showOfflineAlert, isChatOpen=$isChatOpen');

    // ⬅️ CRÍTICO: Solo mostrar cuando el chat está ABIERTO
    // En modo burbuja el iframe es pequeño (140x140px) y este overlay no se vería bien
    if (!isChatOpen) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: _ConnectivitySnackBarTrigger(
        isOnline: isOnline,
        isDarkMode: isDarkMode,
        showOfflineAlert: showOfflineAlert,
      ),
    );
  }
}

class _ConnectivitySnackBarTrigger extends StatefulWidget {
  final bool isOnline;
  final bool isDarkMode;
  final bool showOfflineAlert;

  const _ConnectivitySnackBarTrigger({
    required this.isOnline,
    required this.isDarkMode,
    required this.showOfflineAlert,
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
      _logOverlay('Transición offline → online (sin SnackBar interno)');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOnline || !widget.showOfflineAlert) {
      return const SizedBox.shrink();
    }
    
    // ⬅️ IgnorePointer aquí para que no bloquee interacciones con la burbuja
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF2A1810).withOpacity(0.95)
                      : const Color(0xFFFFE8D9).withOpacity(0.98),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? const Color(0xFFFF8C40).withOpacity(0.5)
                        : const Color(0xFFE07030).withOpacity(0.6),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 22,
                      color: widget.isDarkMode
                          ? const Color(0xFFFFB380)
                          : const Color(0xFFC05020),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Conexión perdida. Comprueba tu red.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? const Color(0xFFFFB380)
                              : const Color(0xFF8B4513),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
