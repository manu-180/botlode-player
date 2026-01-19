// Archivo: lib/features/player/presentation/providers/ui_provider.dart
import 'dart:ui';
import 'package:botlode_player/features/player/presentation/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui_provider.g.dart';

@riverpod
class ChatOpen extends _$ChatOpen {
  @override
  bool build() {
    return false; 
  }

  void set(bool value) {
    state = value;
  }
}

// Provider existente para posición
final pointerPositionProvider = StateProvider<Offset?>((ref) => null);

// --- NUEVO: Provider para Hover Externo (Controlado por HTML) ---
final isHoveredExternalProvider = StateProvider<bool>((ref) => false);

final chatResetProvider = Provider((ref) {
  return () {
    ref.invalidate(chatControllerProvider);
  };
});