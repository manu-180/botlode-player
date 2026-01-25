// Archivo: lib/features/player/presentation/providers/head_tracking_provider.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:botlode_player/features/player/presentation/providers/ui_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modelo inmutable para el estado de tracking
class HeadTrackingState {
  final double targetX;
  final double targetY;
  final bool isTracking;

  const HeadTrackingState({
    this.targetX = 50.0,
    this.targetY = 50.0,
    this.isTracking = false,
  });

  HeadTrackingState copyWith({
    double? targetX,
    double? targetY,
    bool? isTracking,
  }) {
    return HeadTrackingState(
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

/// Controlador que encapsula toda la lógica matemática de tracking
class HeadTrackingController {
  /// Calcula la posición objetivo basándose en la posición del puntero
  /// 
  /// [deltaPos] - Offset relativo del puntero respecto al centro del widget
  /// [maxDistance] - Distancia máxima de interés para activar tracking
  /// [sensitivity] - Factor de sensibilidad del movimiento (menor = más sensible)
  /// 
  /// Retorna el nuevo estado de tracking con las coordenadas calculadas
  static HeadTrackingState calculateTracking({
    required Offset? deltaPos,
    required double maxDistance,
    required double sensitivity,
  }) {
    // Si no hay posición válida, retornar al centro
    if (deltaPos == null) {
      return const HeadTrackingState(
        targetX: 50.0,
        targetY: 50.0,
        isTracking: false,
      );
    }

    final double dx = deltaPos.dx;
    final double dy = deltaPos.dy;

    // Calcular distancia euclidiana
    final double distance = math.sqrt(dx * dx + dy * dy);

    // Determinar si el puntero está dentro del rango de interés
    if (distance < maxDistance) {
      // Normalizar posición a escala 0-100 con sensibilidad
      final double targetX = (50 + (dx / sensitivity * 50)).clamp(0.0, 100.0);
      final double targetY = (50 + (dy / sensitivity * 50)).clamp(0.0, 100.0);

      return HeadTrackingState(
        targetX: targetX,
        targetY: targetY,
        isTracking: true,
      );
    } else {
      // Fuera de rango: volver al centro
      return const HeadTrackingState(
        targetX: 50.0,
        targetY: 50.0,
        isTracking: false,
      );
    }
  }
}

/// Provider para floating head (cabeza pequeña flotante)
/// Configuración: Distancia 400px, Sensibilidad 200
final floatingHeadTrackingProvider = Provider<HeadTrackingState>((ref) {
  final pointerPosition = ref.watch(pointerPositionProvider);
  
  return HeadTrackingController.calculateTracking(
    deltaPos: pointerPosition,
    maxDistance: 400.0,
    sensitivity: 200.0,
  );
});

/// Provider para bot avatar (cabeza grande del panel de chat)
/// Configuración: Distancia 600px, Sensibilidad 400
final botAvatarTrackingProvider = Provider<HeadTrackingState>((ref) {
  final pointerPosition = ref.watch(pointerPositionProvider);
  
  return HeadTrackingController.calculateTracking(
    deltaPos: pointerPosition,
    maxDistance: 600.0,
    sensitivity: 400.0,
  );
});
