// Archivo: lib/core/config/supabase_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Indica si Supabase ya está inicializado (para init no bloqueante)
final supabaseReadyProvider = StateProvider<bool>((ref) => false);

/// Provider centralizado para el cliente de Supabase
/// 
/// Este provider encapsula el acceso a Supabase.instance.client,
/// permitiendo inyección de dependencias y facilitando el testing.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
