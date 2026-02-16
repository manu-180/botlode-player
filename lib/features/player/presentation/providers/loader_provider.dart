// Archivo: lib/features/player/presentation/providers/loader_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

// Cache global para la CABEZA FLOTANTE (se carga primero al mostrar burbuja)
final riveHeadFileLoaderProvider = FutureProvider<RiveFile>((ref) async {
  try {
    await RiveFile.initialize();
    final data = await rootBundle.load('assets/animations/cabezabot.riv');
    return RiveFile.import(data);
  } catch (e) {
    debugPrint("🔴 ERROR CARGANDO RIVE CABEZA: $e");
    throw Exception("No se pudo cargar el archivo de la cabeza: $e");
  }
});

// Cache global del archivo Rive PRINCIPAL (cuerpo entero - initialize ya ejecutado en head)
final riveFileLoaderProvider = FutureProvider<RiveFile>((ref) async {
  try {
    final data = await rootBundle.load('assets/animations/catbotlode.riv');
    return RiveFile.import(data);
  } catch (e) {
    debugPrint("🔴 ERROR CARGANDO RIVE PRINCIPAL: $e");
    throw Exception("No se pudo cargar el archivo: $e");
  }
});