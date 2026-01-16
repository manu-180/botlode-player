// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';

import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui_provider.g.dart'; // <--- Esto aparecerá en rojo hasta que corras el build_runner

// 1. ESTADO DE APERTURA (Notifier generado)
@riverpod
class ChatOpen extends _$ChatOpen {
  @override
  bool build() {
    return false; // Estado inicial: Cerrado
  }

  // Método para cambiar estado manualmente
  void set(bool value) {
    state = value;
  }
}
final pointerPositionProvider = StateProvider<Offset?>((ref) => null);
// 2. LÓGICA DE RESET (Provider simple)
final chatResetProvider = Provider((ref) {
  return () {
    ref.invalidate(chatControllerProvider);
  };
});