// Archivo: lib/features/player/presentation/providers/bot_repository_provider.dart
import 'package:botlode_player/features/player/data/repositories/bot_repository_impl.dart';
import 'package:botlode_player/features/player/domain/repositories/bot_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final botRepositoryProvider = Provider<BotRepository>((ref) {
  return BotRepositoryImpl(Supabase.instance.client);
});