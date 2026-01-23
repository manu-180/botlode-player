// Archivo: lib/features/player/presentation/providers/chat_repository_provider.dart
import 'package:botlode_player/features/player/data/repositories/chat_repository_impl.dart';
import 'package:botlode_player/features/player/domain/repositories/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});