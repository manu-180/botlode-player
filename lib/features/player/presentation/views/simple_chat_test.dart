// PASO 3.2: Integración de Rive Avatar + StatusIndicator
import 'package:botlode_player/core/network/connectivity_provider.dart';
import 'package:botlode_player/features/player/presentation/widgets/rive_avatar.dart';
import 'package:botlode_player/features/player/presentation/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleChatTest extends ConsumerWidget {
  const SimpleChatTest({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Configuración de colores (hardcoded por ahora)
    const Color bgColor = Color(0xFF181818);
    const Color inputFill = Color(0xFF2C2C2C);
    const Color borderColor = Colors.white24;
    const Color themeColor = Color(0xFFFFC000);
    const bool isDarkMode = true;

    // Estados temporales hardcoded (lo haremos dinámico en Paso 3)
    const bool isLoading = false;
    const String currentMood = 'neutral';
    
    // Conectividad real desde provider
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // ========== HEADER ==========
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Stack(
                children: [
                  // ✅ RIVE AVATAR (LO MÁS IMPORTANTE)
                  const Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: BotAvatarWidget(),
                    ),
                  ),
                  
                  // Botones en esquina superior derecha
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {
                            print('🔄 Refresh presionado');
                          },
                          color: Colors.white70,
                          tooltip: "Reiniciar",
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            print('❌ Close presionado');
                          },
                          color: Colors.white70,
                          tooltip: "Cerrar",
                        ),
                      ],
                    ),
                  ),
                  
                  // ✅ STATUS INDICATOR REAL
                  Positioned(
                    bottom: 12,
                    left: 24,
                    child: StatusIndicator(
                      isLoading: isLoading,
                      isOnline: isOnline,
                      mood: currentMood,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ],
              ),
            ),

            // ========== BODY (CHAT MESSAGES) ==========
            Expanded(
              child: Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: const Center(
                  child: Text(
                    'Los mensajes aparecerán aquí\n(Paso 3: Integrar chat provider)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // ========== INPUT AREA ==========
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: bgColor,
              child: Container(
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        enabled: false, // Deshabilitado por ahora
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Escribe un mensaje...",
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: null, // Deshabilitado por ahora
                      icon: const Icon(Icons.send_rounded, color: Colors.grey),
                      tooltip: "Enviar",
                      splashRadius: 24,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
