// Archivo: lib/core/network/connectivity_provider.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Este provider escucha los eventos del navegador y nos dice si hay red o no.
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  // 1. Estado inicial
  controller.add(html.window.navigator.onLine ?? true);

  // 2. Escuchar evento "online" (Volvió internet)
  final onlineSub = html.window.onOnline.listen((_) {
    controller.add(true);
  });

  // 3. Escuchar evento "offline" (Se fue internet)
  final offlineSub = html.window.onOffline.listen((_) {
    controller.add(false);
  });

  // Limpieza al cerrar
  ref.onDispose(() {
    onlineSub.cancel();
    offlineSub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider que indica si **alguna vez** hubo conectividad real en esta sesión
/// (hasEverBeenOnline). Es MONOTÓNICO: pasa de false -> true y nunca vuelve a false.
///
/// Objetivo: distinguir entre:
/// - Estado inicial offline (refresh sin internet)  → hasEverBeenOnline = false
/// - App que ya estuvo online al menos una vez     → hasEverBeenOnline = true
final hasEverBeenOnlineProvider =
    StateNotifierProvider<_HasEverBeenOnlineNotifier, bool>((ref) {
  final notifier = _HasEverBeenOnlineNotifier();

  // Leer estado inicial
  final initial = ref.read(connectivityProvider).valueOrNull ?? true;
  if (initial) {
    notifier.markOnline();
  }

  // Escuchar cambios futuros y marcar cuando haya alguna vez online=true
  ref.listen(connectivityProvider, (prev, next) {
    next.whenData((isOnline) {
      if (isOnline) {
        notifier.markOnline();
      }
    });
  });

  return notifier;
});

class _HasEverBeenOnlineNotifier extends StateNotifier<bool> {
  _HasEverBeenOnlineNotifier() : super(false);

  void markOnline() {
    if (!state) {
      state = true;
    }
  }
}