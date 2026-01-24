// Archivo: lib/core/services/presence_manager.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceManager {
  final SupabaseClient _supabase;
  final String sessionId;
  final String botId;

  PresenceManager(this._supabase, {required this.sessionId, required this.botId});

  /// 🟢 ENTRA EN LÍNEA (Al abrir burbuja)
  Future<void> setOnline() async {
    try {
      await _supabase.from('session_heartbeats').upsert({
        'session_id': sessionId,
        'bot_id': botId,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');
    } catch (e) {
      print("⚠️ Error reportando presencia online: $e");
    }
  }

  /// 🔴 SALE DE LÍNEA (Al cerrar burbuja o cerrar web)
  Future<void> setOffline() async {
    try {
      await _supabase.from('session_heartbeats').update({
        'is_online': false,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('session_id', sessionId);
    } catch (e) {
      print("⚠️ Error reportando desconexión: $e");
    }
  }
}