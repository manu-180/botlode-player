import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overlay global de conectividad.
///
/// - Siempre está montado (en el `Stack` raíz) pero solo muestra un
///   banner tipo "snackbar" en la parte superior.
/// - No bloquea la navegación ni la interacción con la página.
/// - Mensajes:
///   - Offline: "Sin conexión a internet" (persistente).
///   - Online de nuevo: "Conexión restablecida" (se oculta solo).
/// - Respeta modo claro / oscuro del bot.
class GlobalConnectivityOverlay extends ConsumerWidget {
  const GlobalConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final isDarkMode = botConfig?.isDarkMode ?? true;
    // select: solo reconstruir cuando el valor booleano cambie (evita rebuilds por AsyncValue distinto).
    final isOnline = ref.watch(
      connectivityProvider.select((async) => async.valueOrNull ?? true),
    );
    final isChatOpen = ref.watch(chatOpenProvider);

    // ⚠️ EXPERIMENTO: NO construir overlay cuando offline para evitar TypeError minificado.
    // Solo mostrar mensaje de reconexión cuando vuelve online.
    if (!isOnline) {
      return const SizedBox.shrink();
    }

    // Este widget debe ser hijo directo de un Stack (UltraSimpleBot / PlayerScreen).
    return IgnorePointer(
      // No queremos capturar taps; el banner es solo informativo.
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
  State<_GlobalConnectivityBanner> createState() => _GlobalConnectivityBannerState();
}

class _GlobalConnectivityBannerState extends State<_GlobalConnectivityBanner> {
  bool _showSuccess = false;

  @override
  void didUpdateWidget(covariant _GlobalConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Mostrar banner de reconexión solo cuando pasamos de offline -> online.
    if (!oldWidget.isOnline && widget.isOnline) {
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Solo mostrar cuando hay reconexión (_showSuccess).
    // El mensaje offline se deshabilitó para evitar TypeError minificado.
    if (!_showSuccess) {
      return const SizedBox.shrink();
    }

    final bool dark = widget.isDarkMode;

    // Paleta sci‑fi, sin azules, ajustada a modo claro/oscuro.
    final Color offlineDeep = dark ? const Color(0xFF9B0018) : const Color(0xFFB71C1C);
    final Color offlineGlow = dark ? const Color(0xFFFF1744) : const Color(0xFFFF5252);

    final Color onlineDeep = dark ? const Color(0xFF0B4F29) : const Color(0xFF1B5E20);
    final Color onlineGlow = dark ? const Color(0xFF00E676) : const Color(0xFF69F0AE);

    // Solo mostramos mensaje de reconexión (online).
    final Color bgDeep = onlineDeep;
    final Color bgGlow = onlineGlow;
    final String text = "Conexión restablecida · El asistente vuelve a estar en línea y puede seguir respondiendo normalmente.";
    final IconData icon = Icons.wifi_rounded;

    // Banner estilo "snackbar" con diseño futurista.
    // Sin BackdropFilter ni flutter_animate: solo animaciones implícitas nativas (estables en HTML renderer).
    final Widget banner = AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      opacity: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bgGlow.withOpacity(dark ? 0.92 : 0.88),
                bgDeep.withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(dark ? 0.22 : 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: bgGlow.withOpacity(dark ? 0.70 : 0.55),
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
                child: Icon(icon, color: Colors.white, size: 18),
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
      ),
    );

    // Positioned fijo (sin AnimatedPositioned) para evitar manipulación de ParentData en HTML renderer.
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;
    const double desktopChatWidth = 380.0;
    const double desktopChatPadding = 28.0;
    final double rightInset = (!isMobile && widget.isChatOpen)
        ? (desktopChatWidth + desktopChatPadding + 16.0)
        : 16.0;

    return Positioned(
      bottom: 12,
      left: 16,
      right: rightInset,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? size.width - 32 : (size.width * 0.55),
            ),
            child: banner,
          ),
        ),
      ),
    );
  }
}
