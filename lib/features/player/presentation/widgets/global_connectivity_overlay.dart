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
/// Al restablecerse la conexión no se muestra cartel dentro del chat (el aviso es el snackbar del HTML).
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
    // Sin cartel de reconexión dentro del chat: solo el snackbar del HTML avisa abajo
    if (!oldWidget.isOnline && widget.isOnline) {
      _logOverlay('Transición offline → online (sin SnackBar interno)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
