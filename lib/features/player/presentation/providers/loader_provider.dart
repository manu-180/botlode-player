// Archivo: lib/features/player/presentation/providers/loader_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

// Cache global del archivo Rive PRINCIPAL (Cuerpo entero)
final riveFileLoaderProvider = FutureProvider<RiveFile>((ref) async {
  // ... (código existente del primer provider) ...
  try {
    await RiveFile.initialize(); 
    final data = await rootBundle.load('assets/animations/catbotlode.riv');
    return RiveFile.import(data);
  } catch (e) {
    debugPrint("🔴 ERROR CARGANDO RIVE PRINCIPAL: $e");
    throw Exception("No se pudo cargar el archivo: $e");
  }
});

// --- NUEVO PROVIDER ---
// Cache global para la CABEZA FLOTANTE
final riveHeadFileLoaderProvider = FutureProvider<RiveFile>((ref) async {
  try {
    // No hace falta llamar a initialize() de nuevo si ya se llamó, pero no hace daño.
    await RiveFile.initialize(); 

    // ASUMO QUE ESTE SERÁ EL NOMBRE DEL NUEVO ARCHIVO
    final data = await rootBundle.load('assets/animations/cabezabot.riv');
    return RiveFile.import(data);
  } catch (e) {
    debugPrint("🔴 ERROR CARGANDO RIVE CABEZA: $e");
    throw Exception("No se pudo cargar el archivo de la cabeza: $e");
  }
});