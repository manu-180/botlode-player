// Archivo: lib/features/crm/presentation/views/nexus_gate_view.dart
import 'dart:ui';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NexusGateView extends StatefulWidget {
  final String initialBotId;
  const NexusGateView({super.key, required this.initialBotId});

  @override
  State<NexusGateView> createState() => _NexusGateViewState();
}

class _NexusGateViewState extends State<NexusGateView> {
  late TextEditingController _idController;
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.initialBotId);
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inputId = _idController.text.trim();
      final pin = _pinController.text.trim();

      if (inputId.isEmpty || pin.isEmpty) {
        throw "Credenciales incompletas.";
      }

      // --- VERIFICACIÓN ---
      final response = await Supabase.instance.client
          .from('bots')
          .select('id')
          .or('id.eq.$inputId,alias.eq.$inputId') 
          .eq('access_pin', pin) 
          .maybeSingle();

      if (response == null) {
        await Future.delayed(const Duration(seconds: 1));
        throw "ACCESO DENEGADO: ID o PIN incorrecto.";
      }

      final realBotId = response['id'] as String;

      // --- PERSISTENCIA ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_bot_id', realBotId);

      // --- NAVEGACIÓN A RUTA NUEVA ---
      if (mounted) {
        context.go('/historial/panel', extra: realBotId);
      }

    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception:', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.network(
                "https://www.transparenttextures.com/patterns/diagmonds-light.png",
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          
          Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F13).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_edu_rounded, size: 48, color: AppTheme.primary)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.5, end: 1.0, duration: 1.5.seconds),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    "ACCESO A HISTORIAL",
                    style: GoogleFonts.oxanium(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Registro de conversaciones y ventas",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),

                  const SizedBox(height: 40),

                  _GateInput(
                    controller: _idController,
                    label: "ID DE UNIDAD / ALIAS", 
                    icon: Icons.fingerprint,
                    isReadOnly: false, 
                    hint: "Ej: tito-pizzas",
                  ),
                  const SizedBox(height: 20),
                  _GateInput(
                    controller: _pinController,
                    label: "PIN DE SEGURIDAD",
                    icon: Icons.password,
                    isObscure: true,
                    hint: "****",
                  ),

                  const SizedBox(height: 30),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        "⚠️ $_error",
                        style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().shake(),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text("INGRESAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GateInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isObscure;
  final bool isReadOnly;
  final String? hint;

  const _GateInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isObscure = false,
    this.isReadOnly = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          readOnly: isReadOnly,
          style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontWeight: FontWeight.bold),
          cursorColor: AppTheme.primary,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: isReadOnly ? Colors.white24 : AppTheme.primary),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ],
    );
  }
}