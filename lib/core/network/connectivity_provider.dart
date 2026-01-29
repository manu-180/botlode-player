// Archivo: lib/core/network/connectivity_provider.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logConnectivity(String message) {
  // Logs de diagnóstico para entender exactamente cuándo el navegador
  // dispara los eventos de conectividad y qué ve Riverpod.
  // Se ven en la consola como:
  // 🛰 [connectivity_provider] <mensaje>
  // Evitamos dependencias extra (debugPrint) para mantener este archivo core limpio.
  // ignore: avoid_print
  print('🛰 [connectivity_provider] $message');
}

// Este provider escucha los eventos del navegador y nos dice si hay red o no.
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  // 1. Estado inicial
  final initialOnline = html.window.navigator.onLine ?? true;
  _logConnectivity('Estado inicial navigator.onLine = $initialOnline');
  controller.add(initialOnline);

  // 2. Escuchar evento "online" (Volvió internet)
  final onlineSub = html.window.onOnline.listen((event) {
    _logConnectivity('Evento onOnline recibido → isOnline=true | event=$event');
    controller.add(true);
  });

  // 3. Escuchar evento "offline" (Se fue internet)
  final offlineSub = html.window.onOffline.listen((event) {
    _logConnectivity('Evento onOffline recibido → isOnline=false | event=$event');
    controller.add(false);
  });

  // Limpieza al cerrar
  ref.onDispose(() {
    _logConnectivity('onDispose() → cancelando listeners y cerrando StreamController');
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
  _logConnectivity(
    'hasEverBeenOnlineProvider init → connectivityProvider.initial = $initial',
  );
  if (initial) {
    notifier.markOnline();
  }

  // Escuchar cambios futuros y marcar cuando haya alguna vez online=true
  ref.listen(connectivityProvider, (prev, next) {
    final prevVal = prev?.valueOrNull;
    final nextVal = next.valueOrNull;
    _logConnectivity(
      'listen(connectivityProvider) → prev=$prevVal, next=$nextVal',
    );

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
      _logConnectivity('markOnline() → cambiando hasEverBeenOnline false → true');
      state = true;
    } else {
      _logConnectivity('markOnline() → ya era true, se mantiene');
    }
  }
}