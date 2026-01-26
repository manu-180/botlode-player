// TEST WIDGET ULTRA SIMPLE - Solo para debugging
import 'package:flutter/material.dart';

class SimpleChatTest extends StatelessWidget {
  const SimpleChatTest({super.key});

  @override
  Widget build(BuildContext context) {
    // ULTRA SIMPLE: Solo un Container con color sólido
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF181818), // Gris oscuro DIRECTO (sin BoxDecoration)
      child: Column(
        children: [
          // HEADER SIMPLE
          Container(
            height: 80,
            color: const Color(0xFF2C2C2C),
            alignment: Alignment.center,
            child: const Text(
              'TEST CHAT',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          
          // ESPACIO (simulando mensajes)
          Expanded(
            child: Container(
              color: const Color(0xFF181818),
              alignment: Alignment.center,
              child: const Text(
                'Si ves esto, el fondo funciona ✅',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
          
          // INPUT SIMPLE
          Container(
            height: 60,
            color: const Color(0xFF2C2C2C),
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(30),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Input de prueba',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
