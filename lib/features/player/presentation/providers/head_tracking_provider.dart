// Archivo: lib/features/player/presentation/providers/head_tracking_provider.dart
import 'dart:math' as math;
import 'dart:ui';
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
  
  /// NUEVO: Calcula el tracking global (Vector = Mouse - CentroWidget)
  static HeadTrackingState calculateGlobalTracking({
    required Offset? globalPointer,
    required Offset widgetCenter,
    required double sensitivity,
    double maxDistance = 1200.0, // ⬅️ NUEVO: Distancia máxima antes de volver al centro
  }) {
    // 1. Si el mouse no está en pantalla, mirar al centro
    if (globalPointer == null) {
      return const HeadTrackingState(targetX: 50.0, targetY: 50.0, isTracking: false);
    }

    // 2. Calcular VECTOR DELTA (Distancia real en píxeles)
    final double dx = globalPointer.dx - widgetCenter.dx;
    final double dy = globalPointer.dy - widgetCenter.dy;
    
    // ⬅️ NUEVO: Calcular distancia euclidiana
    final double distance = math.sqrt(dx * dx + dy * dy);
    
    // ⬅️ NUEVO: Si el mouse está MUY LEJOS, volver al centro suavemente
    if (distance > maxDistance) {
      return const HeadTrackingState(targetX: 50.0, targetY: 50.0, isTracking: false);
    }

    // 3. Normalizar a Inputs Rive (0..100, donde 50 es el centro)
    // Fórmula: 50 + (distancia / sensibilidad * 50)
    // Mayor sensibilidad = el ojo se mueve más lento/necesita más distancia
    double targetX = 50 + (dx / sensitivity * 50);
    double targetY = 50 + (dy / sensitivity * 50);

    // 4. Clamping (Limitar para que no se "rompa" el cuello)
    targetX = targetX.clamp(0.0, 100.0);
    targetY = targetY.clamp(0.0, 100.0);

    return HeadTrackingState(
      targetX: targetX,
      targetY: targetY,
      isTracking: true,
    );
  }

  /// (Legacy) Mantenido para compatibilidad con código antiguo
  static HeadTrackingState calculateTracking({
    required Offset? deltaPos,
    required double maxDistance,
    required double sensitivity,
  }) {
    if (deltaPos == null) return const HeadTrackingState();
    
    final double distance = math.sqrt(deltaPos.dx * deltaPos.dx + deltaPos.dy * deltaPos.dy);
    if (distance < maxDistance) {
      final double targetX = (50 + (deltaPos.dx / sensitivity * 50)).clamp(0.0, 100.0);
      final double targetY = (50 + (deltaPos.dy / sensitivity * 50)).clamp(0.0, 100.0);
      return HeadTrackingState(targetX: targetX, targetY: targetY, isTracking: true);
    } else {
      return const HeadTrackingState();
    }
  }
}

// Estos providers quedan como legado o helpers básicos
final floatingHeadTrackingProvider = Provider<HeadTrackingState>((ref) {
  // Nota: Este tracking puede romperse si pointerPositionProvider es global ahora.
  // Se recomienda usar el Controller directamente en el Widget.
  return const HeadTrackingState();
});

final botAvatarTrackingProvider = Provider<HeadTrackingState>((ref) {
  return const HeadTrackingState();
});