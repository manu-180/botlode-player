import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logOverlay(String message) {
  // Logs de diagnóstico para entender cuándo se dibuja el HUD y con qué estado.
  // Se ven en consola como:
  // 🛰 [GlobalConnectivityOverlay] <mensaje>
  // ignore: avoid_print
  print('🛰 [GlobalConnectivityOverlay] $message');
}

/// Overlay global de conectividad.
///
/// - Siempre está montado (en el `Stack` raíz) pero solo muestra un
///   banner tipo "snackbar" en la parte inferior izquierda.
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

    _logOverlay(
      'build() → isOnline=$isOnline, isDarkMode=$isDarkMode, isChatOpen=$isChatOpen',
    );

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
  void initState() {
    super.initState();
    _logOverlay(
      'initState() → isOnline=${widget.isOnline}, isDarkMode=${widget.isDarkMode}, isChatOpen=${widget.isChatOpen}',
    );
  }

  @override
  void didUpdateWidget(covariant _GlobalConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    _logOverlay(
      'didUpdateWidget() → old.isOnline=${oldWidget.isOnline}, new.isOnline=${widget.isOnline}, '
      'old.isChatOpen=${oldWidget.isChatOpen}, new.isChatOpen=${widget.isChatOpen}',
    );

    // Mostrar banner de reconexión solo cuando pasamos de offline -> online.
    if (!oldWidget.isOnline && widget.isOnline) {
      _logOverlay('Transición OFFLINE → ONLINE → mostrando banner de éxito');
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _logOverlay('Ocultando banner de éxito tras 3s');
        setState(() => _showSuccess = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showOffline = !widget.isOnline;
    final bool isVisible = showOffline || _showSuccess;

    _logOverlay(
      'build(_GlobalConnectivityBanner) → isOnline=${widget.isOnline}, '
      'showOffline=$showOffline, showSuccess=$_showSuccess, isVisible=$isVisible',
    );

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final bool dark = widget.isDarkMode;

    // Paleta sci‑fi, sin azules, ajustada a modo claro/oscuro.
    final Color offlineDeep = dark ? const Color(0xFF9B0018) : const Color(0xFFB71C1C);
    final Color offlineGlow = dark ? const Color(0xFFFF1744) : const Color(0xFFFF5252);

    final Color onlineDeep = dark ? const Color(0xFF0B4F29) : const Color(0xFF1B5E20);
    final Color onlineGlow = dark ? const Color(0xFF00E676) : const Color(0xFF69F0AE);

    final Color bgDeep = showOffline ? offlineDeep : onlineDeep;
    final Color bgGlow = showOffline ? offlineGlow : onlineGlow;

    final String text = showOffline
        ? "Sin conexión a internet · Verificá tu Wi‑Fi o datos móviles. Las respuestas del asistente se pausarán hasta que vuelva la señal."
        : "Conexión restablecida · El asistente vuelve a estar en línea y puede seguir respondiendo normalmente.";
    final IconData icon = showOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;

    // Banner estilo "snackbar" con diseño futurista.
    // Sin BackdropFilter ni flutter_animate: solo animaciones implícitas nativas (estables en HTML renderer).
    final Widget banner = ClipRRect(
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
    );

    // Positioned siempre en el árbol (evita cambios de estructura), pero envuelto en AnimatedOpacity
    // para controlar visibilidad sin manipular ParentData del Stack.
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
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: isVisible ? 1.0 : 0.0,
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
        ),
      ),
    );
  }
}
