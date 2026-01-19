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