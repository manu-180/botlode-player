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

/// Provider que trackea si hubo una transición de online->offline (no solo estado inicial).
/// Útil para ocultar "DESCONECTADO" al refrescar sin internet.
final connectivityTransitionProvider = StateNotifierProvider<_ConnectivityTransitionNotifier, bool>((ref) {
  final notifier = _ConnectivityTransitionNotifier();
  
  // Leer estado inicial
  final initialValue = ref.read(connectivityProvider).valueOrNull ?? true;
  notifier._update(initialValue);
  
  // Escuchar cambios futuros
  ref.listen(connectivityProvider, (prev, next) {
    next.whenData((isOnline) {
      notifier._update(isOnline);
    });
  });
  
  return notifier;
});

class _ConnectivityTransitionNotifier extends StateNotifier<bool> {
  bool? _previousValue;
  bool _hasSeenOnline = false;

  _ConnectivityTransitionNotifier() : super(false);

  void _update(bool isOnline) {
    // Si alguna vez vimos online=true, marcamos que hemos visto online
    if (isOnline) {
      _hasSeenOnline = true;
    }
    
    // Solo marcamos transición si: ya vimos online Y ahora está offline
    if (_hasSeenOnline && !isOnline && _previousValue == true) {
      state = true; // Hubo transición online->offline
    } else {
      state = false; // No hubo transición (o es estado inicial)
    }
    
    _previousValue = isOnline;
  }
}