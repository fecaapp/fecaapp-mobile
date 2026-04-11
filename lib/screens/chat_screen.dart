import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/message_bubble.dart';
import '../widgets/voice_message.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;
  final String targetId; // Doit correspondre à l'UUID dans ta table messages
  final String currentUserId;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.chatName,
    required this.targetId,
    required this.currentUserId,
    required this.isGroup,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  String? _groupCreatorId;
  late RealtimeChannel chatChannel;

  @override
  void initState() {
    super.initState();
    if (widget.isGroup) _fetchGroupInfo();
    _loadMessages();
    _setupRealtime();
  }

  // RÉCUPÉRATION DES INFOS DU GROUPE
  Future<void> _fetchGroupInfo() async {
    try {
      final data = await supabase
          .from('groups')
          .select('creator_id')
          .eq('id', widget.targetId)
          .single();
      if (mounted) setState(() => _groupCreatorId = data['creator_id']);
    } catch (e) {
      debugPrint("Erreur info groupe: $e");
    }
  }

  // 1. CHARGER L'HISTORIQUE (Correction du filtrage de persistance)
  Future<void> _loadMessages() async {
    try {
      // On récupère les messages ET les infos du profil
      final query = supabase.from('messages').select('''
        *,
        sender:sender_id (
          full_name,
          img_url,
          is_certified
        )
      ''');

      final response =
          await (widget.isGroup
                  ? query.eq(
                      'group_id',
                      widget.targetId,
                    ) // Filtre strict par groupe
                  : query.or(
                      'and(sender_id.eq.${widget.currentUserId},receiver_id.eq.${widget.targetId}),and(sender_id.eq.${widget.targetId},receiver_id.eq.${widget.currentUserId})',
                    ))
              .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(List<Map<String, dynamic>>.from(response));
        });
        _markAsRead();
      }
    } catch (e) {
      debugPrint("Erreur chargement: $e");
    }
  }

  // 2. TEMPS RÉEL (Injecte le profil immédiatement)
  void _setupRealtime() {
    chatChannel = supabase.channel('chat_room_${widget.targetId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final newMsg = payload.newRecord;

          bool isRelevant = widget.isGroup
              ? newMsg['group_id'] == widget.targetId
              : (newMsg['sender_id'] == widget.targetId &&
                        newMsg['receiver_id'] == widget.currentUserId) ||
                    (newMsg['sender_id'] == widget.currentUserId &&
                        newMsg['receiver_id'] == widget.targetId);

          if (isRelevant && mounted) {
            // On récupère le profil pour l'afficher direct
            final senderData = await supabase
                .from('users')
                .select('full_name, img_url, is_certified')
                .eq('id', newMsg['sender_id'])
                .single();

            newMsg['sender'] = senderData;

            setState(() => _messages.insert(0, newMsg));
            if (newMsg['sender_id'] != widget.currentUserId) _markAsRead();
          }
        },
      ).subscribe();
  }

  // 3. ENVOI (Force l'ID cible)
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final msgData = {
      'sender_id': widget.currentUserId,
      'receiver_id': widget.isGroup ? null : widget.targetId,
      'group_id': widget.isGroup ? widget.targetId : null,
      'content': text,
      'type': 'TEXT',
    };

    try {
      _controller.clear();
      await supabase.from('messages').insert(msgData);
    } catch (e) {
      debugPrint("Erreur envoi: $e");
    }
  }

  @override
  void dispose() {
    supabase.removeChannel(chatChannel);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.chatName.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = msg['sender_id'] == widget.currentUserId;
        final sender = msg['sender'];
        final String senderName = isMe
            ? "Moi"
            : (sender?['full_name'] ?? "Lion");
        final String? senderImg = sender?['img_url'];
        final bool isCertified = sender?['is_certified'] ?? false;
        final bool isChef =
            widget.isGroup && msg['sender_id'] == _groupCreatorId;
        final createdAt = DateTime.parse(msg['created_at']).toLocal();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) _buildAvatar(senderImg, isCertified),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 6,
                        left: 4,
                        right: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senderName,
                            style: TextStyle(
                              color: isMe
                                  ? const Color(0xFF00FF85).withOpacity(0.6)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isChef) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFF00FF85),
                              size: 12,
                            ),
                          ],
                        ],
                      ),
                    ),
                    msg['type'] == 'VOICE'
                        ? VoiceMessage(
                            duration: msg['duration'],
                            isMe: isMe,
                            timestamp: DateFormat('HH:mm').format(createdAt),
                          )
                        : MessageBubble(data: msg, isMe: isMe),
                    if (isMe) _buildReadStatus(msg),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isMe) _buildAvatar(senderImg, isCertified),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? url, bool isCertified) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white10,
          backgroundImage: url != null && url.isNotEmpty
              ? NetworkImage(url)
              : null,
          child: (url == null || url.isEmpty)
              ? const Icon(Icons.person, size: 14, color: Colors.white24)
              : null,
        ),
        if (isCertified)
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.verified, color: Color(0xFF00FF85), size: 10),
          ),
      ],
    );
  }

  Widget _buildReadStatus(Map<String, dynamic> msg) {
    if (widget.isGroup) return const SizedBox.shrink();
    final bool isRead = msg['is_read'] ?? false;
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 12,
      color: isRead ? const Color(0xFF00FF85) : Colors.white24,
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: const Color(0xFF0D0D0D),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Rugir...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF00FF85)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsRead() async {
    if (widget.isGroup) return;
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', widget.currentUserId)
          .eq('sender_id', widget.targetId)
          .eq('is_read', false);
    } catch (e) {}
  }
}
