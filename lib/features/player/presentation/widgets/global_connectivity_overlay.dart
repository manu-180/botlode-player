import 'package:botlode_player/core/config/app_theme.dart';
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/bot_state_provider.dart';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

void _logOverlay(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🛰 [GlobalConnectivityOverlay] $message');
  }
}

/// Overlay de conectividad: banner profesional con icono, punto parpadeante (solo offline)
/// y texto descriptivo. Reconexión: check sin punto parpadeante.
class GlobalConnectivityOverlay extends ConsumerWidget {
  const GlobalConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botConfig = ref.watch(botConfigProvider).asData?.value;
    final isDarkMode = botConfig?.isDarkMode ?? true;
    final isOnline = ref.watch(connectivityProvider);
    final isChatOpen = ref.watch(chatOpenProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    _logOverlay('build → isOnline=$isOnline');

    return IgnorePointer(
      ignoring: true,
      child: _ConnectivityBanner(
        isOnline: isOnline,
        isDarkMode: isDarkMode,
        isChatOpen: isChatOpen,
        isMobile: isMobile,
      ),
    );
  }
}

class _ConnectivityBanner extends StatefulWidget {
  final bool isOnline;
  final bool isDarkMode;
  final bool isChatOpen;
  final bool isMobile;

  const _ConnectivityBanner({
    required this.isOnline,
    required this.isDarkMode,
    required this.isChatOpen,
    required this.isMobile,
  });

  @override
  State<_ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<_ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showReconnected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOnline && widget.isOnline) {
      _logOverlay('Transición offline → online → mostrando reconexión');
      setState(() => _showReconnected = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showReconnected = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = !widget.isOnline || _showReconnected;
    if (!showBanner) return const SizedBox.shrink();

    final isOffline = !widget.isOnline;
    final rightInset = (!widget.isMobile && widget.isChatOpen) ? 420.0 : 16.0;

    return Positioned(
      left: 16,
      right: rightInset,
      bottom: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: showBanner ? 1.0 : 0.0,
        child: SafeArea(
          top: false,
          child: _BannerCard(
            isOffline: isOffline,
            showBlinkingDot: isOffline,
            isDarkMode: widget.isDarkMode,
            pulseController: _pulseController,
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final bool isOffline;
  final bool showBlinkingDot;
  final bool isDarkMode;
  final AnimationController pulseController;

  const _BannerCard({
    required this.isOffline,
    required this.showBlinkingDot,
    required this.isDarkMode,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? AppTheme.error : AppTheme.success;
    final bgColor = isDarkMode
        ? Colors.black.withOpacity(0.95)
        : Colors.white.withOpacity(0.98);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgColor,
              color.withOpacity(0.06),
              bgColor,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono + punto parpadeante (solo en offline)
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                  ),
                  child: Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                if (showBlinkingDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: AnimatedBuilder(
                      animation: pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.4 + pulseController.value * 0.6,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOffline ? "Sin conexión a internet" : "Conexión restablecida",
                    style: GoogleFonts.oxanium(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOffline
                        ? "Se ha perdido la conexión. Cuando la señal esté disponible, podés seguir navegando con normalidad."
                        : "La conexión ha sido restablecida correctamente.",
                    style: TextStyle(
                      color: (isDarkMode ? Colors.white : Colors.black87).withOpacity(0.85),
                      fontSize: 12,
                      fontFamily: 'Courier',
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Estado: red no disponible",
                      style: TextStyle(
                        color: color.withOpacity(0.9),
                        fontSize: 10,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
