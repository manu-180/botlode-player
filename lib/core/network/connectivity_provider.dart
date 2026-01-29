// Archivo: lib/core/network/connectivity_provider.dart
// Solución refactorizada: estado síncrono para reconexión inmediata,
// sin StreamController ni delays. El UI reacciona en el mismo tick que
// el navegador dispara onOnline/onOffline.
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logConnectivity(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('🛰 [connectivity] $message');
  }
}

/// Estado de conectividad: true = online, false = offline.
/// Actualización síncrona en el mismo tick que window.onOnline/onOffline.
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() {
    final initial = html.window.navigator.onLine ?? true;
    _logConnectivity('Estado inicial: ${initial ? "online" : "offline"}');

    final onlineSub = html.window.onOnline.listen((_) {
      _logConnectivity('Evento onOnline → estado = true');
      state = true;
    });
    final offlineSub = html.window.onOffline.listen((_) {
      _logConnectivity('Evento onOffline → estado = false');
      state = false;
    });

    ref.onDispose(() {
      _logConnectivity('Dispose: cancelando listeners');
      onlineSub.cancel();
      offlineSub.cancel();
    });

    return initial;
  }
}

/// Indica si en esta sesión hubo al menos un momento con red.
/// Monotónico: pasa de false → true y no vuelve atrás.
/// Sirve para no mostrar "DESCONECTADO" en un refresh sin internet.
final hasEverBeenOnlineProvider =
    StateNotifierProvider<_HasEverBeenOnlineNotifier, bool>((ref) {
  final notifier = _HasEverBeenOnlineNotifier();
  final initial = ref.read(connectivityProvider);
  _logConnectivity('hasEverBeenOnline init → connectivity=$initial');
  if (initial) notifier.markOnline();

  ref.listen(connectivityProvider, (prev, next) {
    if (next) notifier.markOnline();
  });

  return notifier;
});

class _HasEverBeenOnlineNotifier extends StateNotifier<bool> {
  _HasEverBeenOnlineNotifier() : super(false);

  void markOnline() {
    if (!state) {
      _logConnectivity('markOnline → hasEverBeenOnline = true');
      state = true;
    }
  }
}
