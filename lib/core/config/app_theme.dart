// Archivo: lib/core/config/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Colores Oficial BotsLode
  static const Color primary = Color(0xFFFFC000);    // Amarillo Oro
  static const Color background = Color(0xFF050505); // Negro Profundo
  static const Color surface = Color(0xFF151515);    // Gris Oscuro / Carbono
  static const Color borderGlass = Colors.white10;   // Bordes sutiles
  
  static const Color success = Color(0xFF00FF94);    // Verde Neón
  static const Color error = Color(0xFFFF003C);      // Rojo Láser
  static const Color techCyan = Color(0xFF00F0FF);   // Azul Cyberpunk

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      
      // Esquema de colores
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: techCyan,
        surface: surface,
        error: error,
        background: background,
      ),

      // Tipografía Sci-Fi (Oxanium)
      textTheme: GoogleFonts.oxaniumTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),

      // Estilo de Inputs (Campos de texto)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // ⬅️ Color neutro para el borde enfocado (no usa primary amarillo)
          // Gris claro para dark mode que funciona bien con cualquier tema
          borderSide: BorderSide(color: Colors.grey.shade600, width: 1.5),
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      ),

      // Estilo de Botones Elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black, // Texto negro sobre amarillo
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      
      // Estilo de Iconos
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}