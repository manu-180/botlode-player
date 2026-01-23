// Archivo: lib/features/crm/presentation/views/nexus_dashboard_view.dart
import 'dart:ui';
import 'package:botlode_player/core/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- MODELOS ---
class NexusSession {
  final String sessionId;
  final DateTime lastActive;
  final int messageCount;
  final int intentScore;
  final String lastMessage;

  NexusSession({required this.sessionId, required this.lastActive, required this.messageCount, required this.intentScore, required this.lastMessage});

  factory NexusSession.fromMap(Map<String, dynamic> map) {
    return NexusSession(
      sessionId: map['session_id'] ?? 'unknown',
      lastActive: DateTime.tryParse(map['last_active'] ?? '') ?? DateTime.now(),
      messageCount: map['message_count'] ?? 0,
      intentScore: map['max_intent_score'] ?? 0,
      lastMessage: map['last_message_preview'] ?? '...',
    );
  }
}

class NexusMessage {
  final String content;
  final bool isUser;
  final DateTime createdAt;
  NexusMessage({required this.content, required this.isUser, required this.createdAt});
  
  factory NexusMessage.fromMap(Map<String, dynamic> map) {
    return NexusMessage(
      content: map['content'] ?? '',
      isUser: map['role'] == 'user',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// --- VISTA PRINCIPAL ---
class NexusDashboardView extends StatefulWidget {
  final String botId;
  const NexusDashboardView({super.key, required this.botId});

  @override
  State<NexusDashboardView> createState() => _NexusDashboardViewState();
}

class _NexusDashboardViewState extends State<NexusDashboardView> {
  String? _selectedSessionId;
  
  Stream<List<NexusSession>> get _sessionsStream {
    return Supabase.instance.client
        .from('session_summaries')
        .stream(primaryKey: ['session_id'])
        .eq('bot_id', widget.botId)
        .order('last_active', ascending: false)
        .map((data) => data.map((e) => NexusSession.fromMap(e)).toList());
  }

  Stream<List<NexusMessage>> _messagesStream(String sessionId) {
    return Supabase.instance.client
        .from('chat_logs')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => NexusMessage.fromMap(e)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Row(
        children: [
          // LISTA
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F13),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<List<NexusSession>>(
                    stream: _sessionsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: AppTheme.error)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                      
                      final sessions = snapshot.data!;
                      if (sessions.isEmpty) return const Center(child: Text("SIN ACTIVIDAD RECIENTE", style: TextStyle(color: Colors.white38, fontFamily: 'Oxanium')));

                      return ListView.builder(
                        itemCount: sessions.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return _NexusSessionCard(
                            session: session,
                            isSelected: session.sessionId == _selectedSessionId,
                            onTap: () => setState(() => _selectedSessionId = session.sessionId),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // DETALLE
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("https://www.transparenttextures.com/patterns/diagmonds-light.png"),
                  opacity: 0.05,
                  repeat: ImageRepeat.repeat,
                ),
              ),
              child: _selectedSessionId == null
                  ? _buildWelcome()
                  : _buildChatDetail(_selectedSessionId!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("HISTORIAL DE ENLACE", style: GoogleFonts.oxanium(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
              Text("ID: ${widget.botId.substring(0, 8)}...", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'Courier')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 80, color: AppTheme.primary.withOpacity(0.2))
              .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          const SizedBox(height: 24),
          Text("SELECCIONA UN CHAT", style: GoogleFonts.oxanium(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          const SizedBox(height: 8),
          const Text("Visualiza las conversaciones y detecta oportunidades.", style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildChatDetail(String sessionId) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          color: Colors.black.withOpacity(0.8),
          child: Row(
            children: [
              const Text("REGISTRO DE CONVERSACIÓN", style: TextStyle(color: Colors.white, fontFamily: 'Oxanium', fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                child: Text("SESIÓN: ${sessionId.substring(0, 8)}", style: const TextStyle(color: Colors.white54, fontFamily: 'Courier', fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NexusMessage>>(
            stream: _messagesStream(sessionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              final messages = snapshot.data!;
              
              return ListView.builder(
                padding: const EdgeInsets.all(32),
                itemCount: messages.length,
                itemBuilder: (context, index) => _NexusBubble(message: messages[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NexusSessionCard extends StatelessWidget {
  final NexusSession session;
  final bool isSelected;
  final VoidCallback onTap;

  const _NexusSessionCard({required this.session, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color scoreColor = Colors.grey;
    String scoreLabel = "CONSULTA";
    if (session.intentScore > 70) { scoreColor = AppTheme.success; scoreLabel = "VENTA PROBABLE"; }
    else if (session.intentScore > 30) { scoreColor = AppTheme.primary; scoreLabel = "INTERESADO"; }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? scoreColor.withOpacity(0.1) : Colors.white.withOpacity(0.03),
        border: Border.all(color: isSelected ? scoreColor.withOpacity(0.5) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: scoreColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: Text(scoreLabel, style: TextStyle(color: scoreColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            Text(DateFormat('HH:mm').format(session.lastActive), style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(session.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ),
    );
  }
}

class _NexusBubble extends StatelessWidget {
  final NexusMessage message;
  const _NexusBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isUser ? "CLIENTE" : "BOT", style: TextStyle(color: isUser ? Colors.black54 : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message.content, style: TextStyle(color: isUser ? Colors.black : Colors.white, fontSize: 14)),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }
}