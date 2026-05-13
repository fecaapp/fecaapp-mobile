import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;
  final String targetId;
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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // ── Cache persistant
  static final Map<String, List<Map<String, dynamic>>> _msgCache = {};

  List<Map<String, dynamic>> _messages = [];
  String? _groupCreatorId;
  late RealtimeChannel _chatChannel;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAttachMenu = false;
  bool _isTyping = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Réponse inline
  String? _replyingToId;
  String? _replyingToContent;
  String? _replyingToAuthor;

  // Réactions
  String? _reactionTargetId;

  // Animations
  late AnimationController _sendAnim;
  late Animation<double> _sendScale;
  late AnimationController _micAnim;
  late Animation<double> _micPulse;
  late AnimationController _attachAnim;
  late Animation<double> _attachSlide;

  String get _cacheKey => widget.targetId;

  static const List<String> _reactions = ['❤️', '😂', '😮', '😢', '🔥', '🦁'];

  @override
  void initState() {
    super.initState();

    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _sendScale = Tween(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _sendAnim, curve: Curves.easeOut));

    _micAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _micPulse = Tween(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _micAnim, curve: Curves.easeInOut));

    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _attachSlide = CurvedAnimation(
      parent: _attachAnim,
      curve: Curves.easeOutCubic,
    );

    _controller.addListener(() {
      final typing = _controller.text.isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });

    if (_msgCache.containsKey(_cacheKey)) {
      _messages = List.from(_msgCache[_cacheKey]!);
      _isLoading = false;
    }

    if (widget.isGroup) _fetchGroupInfo();
    _loadMessages();
    _setupRealtime();
  }

  @override
  void dispose() {
    supabase.removeChannel(_chatChannel);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendAnim.dispose();
    _micAnim.dispose();
    _attachAnim.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // ── DONNÉES ─────────────────────────────────────────────────

  Future<void> _fetchGroupInfo() async {
    try {
      final data = await supabase
          .from('groups')
          .select('creator_id')
          .eq('id', widget.targetId)
          .single();
      if (mounted) setState(() => _groupCreatorId = data['creator_id']);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final query = supabase
          .from('messages')
          .select('*, sender:sender_id(id, full_name, img_url, is_certified)');
      final response =
          await (widget.isGroup
                  ? query.eq('group_id', widget.targetId)
                  : query.or(
                      'and(sender_id.eq.${widget.currentUserId},receiver_id.eq.${widget.targetId}),'
                      'and(sender_id.eq.${widget.targetId},receiver_id.eq.${widget.currentUserId})',
                    ))
              .order('created_at', ascending: false)
              .limit(100);

      final msgs = List<Map<String, dynamic>>.from(response);
      if (mounted)
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
      _msgCache[_cacheKey] = msgs;
      if (!widget.isGroup) _markAsRead();
    } catch (e) {
      debugPrint("Erreur messages: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    _chatChannel = supabase.channel('chat_${widget.targetId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final newMsg = Map<String, dynamic>.from(payload.newRecord);
          final isRelevant = widget.isGroup
              ? newMsg['group_id'] == widget.targetId
              : (newMsg['sender_id'] == widget.targetId &&
                        newMsg['receiver_id'] == widget.currentUserId) ||
                    (newMsg['sender_id'] == widget.currentUserId &&
                        newMsg['receiver_id'] == widget.targetId);

          if (isRelevant && mounted) {
            try {
              final sd = await supabase
                  .from('users')
                  .select('id, full_name, img_url, is_certified')
                  .eq('id', newMsg['sender_id'])
                  .single();
              newMsg['sender'] = sd;
            } catch (_) {}
            setState(() => _messages.insert(0, newMsg));
            _msgCache[_cacheKey] = List.from(_messages);
            if (newMsg['sender_id'] != widget.currentUserId) {
              _markAsRead();
              HapticFeedback.lightImpact();
            }
          }
        },
      ).subscribe();
  }

  // ── ENVOI ────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    HapticFeedback.lightImpact();
    try {
      _controller.clear();
      await supabase.from('messages').insert({
        'sender_id': widget.currentUserId,
        'receiver_id': widget.isGroup ? null : widget.targetId,
        'group_id': widget.isGroup ? widget.targetId : null,
        'content': text,
        'type': 'TEXT',
        if (_replyingToId != null) 'reply_to_id': _replyingToId,
      });
      _clearReply();
    } catch (e) {
      debugPrint("Erreur envoi: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMedia({required String source}) async {
    setState(() => _showAttachMenu = false);
    _attachAnim.reverse();
    final picker = ImagePicker();
    XFile? file;

    try {
      if (source == 'gallery_image') {
        file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else if (source == 'gallery_video') {
        file = await picker.pickVideo(source: ImageSource.gallery);
      } else if (source == 'camera') {
        file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }

      if (file == null || !mounted) return;
      setState(() => _isSending = true);
      HapticFeedback.mediumImpact();

      final ext = file.path.split('.').last;
      final fileName =
          '${widget.currentUserId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final isVideo = source == 'gallery_video';

      await supabase.storage.from('posts').upload(fileName, File(file.path));
      final mediaUrl = supabase.storage.from('posts').getPublicUrl(fileName);

      await supabase.from('messages').insert({
        'sender_id': widget.currentUserId,
        'receiver_id': widget.isGroup ? null : widget.targetId,
        'group_id': widget.isGroup ? widget.targetId : null,
        'content': '',
        'type': isVideo ? 'VIDEO' : 'IMAGE',
        'media_url': mediaUrl,
        if (_replyingToId != null) 'reply_to_id': _replyingToId,
      });
      _clearReply();
    } catch (e) {
      debugPrint("Erreur media: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startRecording() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  void _stopRecording({bool send = true}) {
    _recordTimer?.cancel();
    HapticFeedback.mediumImpact();
    if (send && _recordSeconds > 0) {
      // Simulation envoi vocal (intégrer audio_recorder si besoin)
      supabase
          .from('messages')
          .insert({
            'sender_id': widget.currentUserId,
            'receiver_id': widget.isGroup ? null : widget.targetId,
            'group_id': widget.isGroup ? widget.targetId : null,
            'content':
                '🎙️ Message vocal (${_formatRecordTime(_recordSeconds)})',
            'type': 'VOICE',
            'duration': _formatRecordTime(_recordSeconds),
          })
          .then((_) {})
          .catchError((e) => debugPrint("Erreur vocal: $e"));
    }
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  String _formatRecordTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
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
    } catch (_) {}
  }

  void _setReply(Map<String, dynamic> msg) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyingToId = msg['id']?.toString();
      _replyingToContent = msg['type'] == 'IMAGE'
          ? '📷 Photo'
          : msg['type'] == 'VIDEO'
          ? '🎥 Vidéo'
          : msg['type'] == 'VOICE'
          ? '🎙️ Vocal'
          : msg['content']?.toString() ?? '';
      _replyingToAuthor = msg['sender']?['full_name'] ?? 'Lion';
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToContent = null;
      _replyingToAuthor = null;
    });
  }

  void _addReaction(String msgId, String emoji) {
    Navigator.pop(context);
    HapticFeedback.lightImpact();
    // Mettre à jour localement
    setState(() {
      final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
      if (idx != -1) {
        _messages[idx]['my_reaction'] = emoji;
      }
    });
  }

  // ── DATES ─────────────────────────────────────────────────

  String _formatTime(String dateStr) =>
      DateFormat('HH:mm').format(DateTime.parse(dateStr).toLocal());

  String _formatDateSeparator(String dateStr) {
    final dt = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return "Aujourd'hui";
    if (msgDay == yesterday) return "Hier";
    return DateFormat('dd MMMM yyyy', 'fr').format(dt);
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == _messages.length - 1) return true;
    final c = DateTime.parse(_messages[index]['created_at']).toLocal();
    final n = DateTime.parse(_messages[index + 1]['created_at']).toLocal();
    return DateTime(c.year, c.month, c.day) != DateTime(n.year, n.month, n.day);
  }

  // ── APPELS ───────────────────────────────────────────────────

  void _initiateCall({required bool isVideo}) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CallDialog(
        chatName: widget.chatName,
        isVideo: isVideo,
        onEnd: () => Navigator.pop(context),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () {
          setState(() => _showAttachMenu = false);
          _attachAnim.reverse();
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: _showAttachMenu
                  ? _buildAttachMenu()
                  : const SizedBox.shrink(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────

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
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.isGroup ? 14 : 21),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3CFF7E).withOpacity(0.25),
                  const Color(0xFF3CFF7E).withOpacity(0.08),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF3CFF7E).withOpacity(0.25),
              ),
            ),
            child: Icon(
              widget.isGroup ? Icons.groups_rounded : Icons.person_rounded,
              color: const Color(0xFF3CFF7E),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3CFF7E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      widget.isGroup ? "Tribu active" : "En ligne",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Appel audio
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.call_rounded,
              color: Color(0xFF3CFF7E),
              size: 18,
            ),
          ),
          onPressed: () => _initiateCall(isVideo: false),
        ),
        // Appel vidéo
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFF3CFF7E),
              size: 18,
            ),
          ),
          onPressed: () => _initiateCall(isVideo: true),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── LISTE MESSAGES ───────────────────────────────────────────

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3CFF7E),
          strokeWidth: 2,
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Text("🦁", style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            Text(
              "Commencez à rugir !",
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Envoyez un message ou passez un appel",
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = msg['sender_id'] == widget.currentUserId;
        return Column(
          children: [
            if (_shouldShowDateSeparator(index))
              _buildDateSeparator(msg['created_at']),
            _buildMessageItem(msg, isMe, msg['sender']),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(String dateStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Text(
              _formatDateSeparator(dateStr),
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    Map<String, dynamic> msg,
    bool isMe,
    dynamic sender,
  ) {
    final String senderName = isMe ? "Moi" : (sender?['full_name'] ?? "Lion");
    final String? senderImg = sender?['img_url'];
    final bool isCertified = sender?['is_certified'] ?? false;
    final bool isChef = widget.isGroup && msg['sender_id'] == _groupCreatorId;
    final String time = _formatTime(msg['created_at']);
    final bool isRead = msg['is_read'] ?? false;
    final String? reaction = msg['my_reaction'];

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: reaction != null ? 18 : 8,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _buildAvatar(senderImg, isCertified),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe || (widget.isGroup))
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 4,
                        left: 2,
                        right: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senderName,
                            style: TextStyle(
                              color: isMe
                                  ? const Color(0xFF3CFF7E).withOpacity(0.7)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isChef) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFF3CFF7E),
                              size: 11,
                            ),
                          ],
                          if (isCertified && !isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.blueAccent,
                              size: 11,
                            ),
                          ],
                        ],
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildBubble(msg, isMe, time, isRead),
                      if (reaction != null)
                        Positioned(
                          bottom: -14,
                          right: isMe ? 8 : null,
                          left: isMe ? null : 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              reaction,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              _buildAvatar(senderImg, isCertified),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String time,
    bool isRead,
  ) {
    final String content = msg['content'] ?? '';
    final String type = msg['type'] ?? 'TEXT';
    final String? mediaUrl = msg['media_url'];
    final String? duration = msg['duration'];

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(isMe ? 20 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 20),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: type == 'TEXT' || type == 'VOICE' ? 260 : 240,
          ),
          padding: (type == 'IMAGE' || type == 'VIDEO')
              ? const EdgeInsets.all(3)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isMe
                  ? [
                      const Color(0xFF3CFF7E).withOpacity(0.22),
                      const Color(0xFF3CFF7E).withOpacity(0.07),
                    ]
                  : [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.03),
                    ],
            ),
            border: Border.all(
              color: isMe
                  ? const Color(0xFF3CFF7E).withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Réponse citée
              if (msg['reply_to_id'] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? const Color(0xFF3CFF7E) : Colors.white38,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingToAuthor ?? 'Lion',
                        style: const TextStyle(
                          color: Color(0xFF3CFF7E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyingToContent ?? '...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // TEXT
              if (type == 'TEXT' && content.isNotEmpty)
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                    letterSpacing: 0.1,
                  ),
                ),

              // IMAGE / VIDEO
              if ((type == 'IMAGE' || type == 'VIDEO') && mediaUrl != null)
                GestureDetector(
                  onTap: () => _showZoomedMedia(mediaUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Image.network(
                          mediaUrl,
                          width: 230,
                          height: 210,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, p) {
                            if (p == null) return child;
                            return Container(
                              width: 230,
                              height: 210,
                              color: const Color(0xFF1A1A1A),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF3CFF7E),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            width: 230,
                            height: 210,
                            color: const Color(0xFF1A1A1A),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white24,
                              size: 40,
                            ),
                          ),
                        ),
                        if (type == 'VIDEO')
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 54,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // VOICE
              if (type == 'VOICE')
                _VoiceBubble(duration: duration ?? '0:00', isMe: isMe),

              // Footer
              Padding(
                padding: EdgeInsets.only(
                  top: (type == 'TEXT' || type == 'VOICE') ? 5 : 6,
                  left: (type == 'IMAGE' || type == 'VIDEO') ? 6 : 0,
                  right: (type == 'IMAGE' || type == 'VIDEO') ? 6 : 0,
                  bottom: (type == 'IMAGE' || type == 'VIDEO') ? 4 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 9,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 12,
                        color: isRead
                            ? const Color(0xFF3CFF7E)
                            : Colors.white24,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showZoomedMedia(String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.96),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Réactions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _reactions
                    .map(
                      (e) => GestureDetector(
                        onTap: () => _addReaction(msg['id'].toString(), e),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            _optionTile(Icons.reply_rounded, "Répondre", Colors.white, () {
              Navigator.pop(context);
              _setReply(msg);
            }),
            if (isMe)
              _optionTile(
                Icons.delete_outline_rounded,
                "Supprimer",
                Colors.redAccent,
                () async {
                  Navigator.pop(context);
                  try {
                    await supabase
                        .from('messages')
                        .delete()
                        .eq('id', msg['id']);
                    setState(
                      () => _messages.removeWhere((m) => m['id'] == msg['id']),
                    );
                  } catch (_) {}
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(String? url, bool isCertified) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white10,
          backgroundImage: (url?.isNotEmpty ?? false)
              ? NetworkImage(url!)
              : null,
          child: (url?.isEmpty ?? true)
              ? const Icon(Icons.person, size: 14, color: Colors.white24)
              : null,
        ),
        if (isCertified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: Color(0xFF3CFF7E),
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  // ── MENU PIÈCES JOINTES ──────────────────────────────────────

  Widget _buildAttachMenu() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _attachBtn(
            Icons.image_rounded,
            "Galerie",
            const Color(0xFF3CFF7E),
            () => _sendMedia(source: 'gallery_image'),
          ),
          _attachBtn(
            Icons.videocam_rounded,
            "Vidéo",
            Colors.blueAccent,
            () => _sendMedia(source: 'gallery_video'),
          ),
          _attachBtn(
            Icons.camera_alt_rounded,
            "Caméra",
            Colors.orangeAccent,
            () => _sendMedia(source: 'camera'),
          ),
          _attachBtn(Icons.mic_rounded, "Vocal", Colors.purpleAccent, () {
            setState(() => _showAttachMenu = false);
            _attachAnim.reverse();
          }),
        ],
      ),
    );
  }

  Widget _attachBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT ────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre réponse
            if (_replyingToId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CFF7E).withOpacity(0.05),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF3CFF7E), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      color: Color(0xFF3CFF7E),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Réponse à $_replyingToAuthor",
                            style: const TextStyle(
                              color: Color(0xFF3CFF7E),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _replyingToContent ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearReply,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

            // Enregistrement vocal
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _micPulse,
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatRecordTime(_recordSeconds),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "Relâchez pour envoyer · Glissez pour annuler",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Bouton + attachements
                    GestureDetector(
                      onTap: () {
                        setState(() => _showAttachMenu = !_showAttachMenu);
                        _showAttachMenu
                            ? _attachAnim.forward()
                            : _attachAnim.reverse();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _showAttachMenu
                              ? const Color(0xFF3CFF7E).withOpacity(0.12)
                              : Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _showAttachMenu
                                ? const Color(0xFF3CFF7E).withOpacity(0.3)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: RotationTransition(
                          turns: Tween(
                            begin: 0.0,
                            end: 0.125,
                          ).animate(_attachAnim),
                          child: Icon(
                            Icons.add_rounded,
                            color: _showAttachMenu
                                ? const Color(0xFF3CFF7E)
                                : Colors.white54,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Champ texte
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 5,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: widget.isGroup
                                ? "Rugir dans la tribu..."
                                : "Rugir...",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.22),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Bouton envoi / mic
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: _isTyping
                          ? ScaleTransition(
                              key: const ValueKey('send'),
                              scale: _sendScale,
                              child: GestureDetector(
                                onTapDown: (_) => _sendAnim.forward(),
                                onTapUp: (_) {
                                  _sendAnim.reverse();
                                  _sendText();
                                },
                                onTapCancel: () => _sendAnim.reverse(),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3CFF7E),
                                        Color(0xFF00C853),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3CFF7E,
                                        ).withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _isSending
                                      ? const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                ),
                              ),
                            )
                          : GestureDetector(
                              key: const ValueKey('mic'),
                              onLongPressStart: (_) => _startRecording(),
                              onLongPressEnd: (_) => _stopRecording(send: true),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mic_none_rounded,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET BULLE VOCALE
// ═══════════════════════════════════════════════════════════════

class _VoiceBubble extends StatefulWidget {
  final String duration;
  final bool isMe;
  const _VoiceBubble({required this.duration, required this.isMe});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late AnimationController _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isMe ? const Color(0xFF3CFF7E) : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isPlaying = !_isPlaying);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: accent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _waveAnim,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(20, (i) {
                  final rand =
                      (sin(i * 0.8 + _waveAnim.value * pi) * 0.5 + 0.5);
                  final h = _isPlaying
                      ? 4 + rand * 20
                      : [
                          4.0,
                          8.0,
                          14.0,
                          6.0,
                          18.0,
                          5.0,
                          12.0,
                          7.0,
                          16.0,
                          4.0,
                          9.0,
                          13.0,
                          6.0,
                          11.0,
                          8.0,
                          15.0,
                          5.0,
                          10.0,
                          7.0,
                          12.0,
                        ][i];
                  return Container(
                    width: 2.5,
                    height: h.toDouble(),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(_isPlaying ? 0.8 : 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.duration,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOG APPEL
// ═══════════════════════════════════════════════════════════════

class _CallDialog extends StatefulWidget {
  final String chatName;
  final bool isVideo;
  final VoidCallback onEnd;
  const _CallDialog({
    required this.chatName,
    required this.isVideo,
    required this.onEnd,
  });

  @override
  State<_CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<_CallDialog>
    with TickerProviderStateMixin {
  int _seconds = 0;
  Timer? _timer;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  bool _calling = true;
  late AnimationController _pulseAnim;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

    // Simulation connexion après 3s
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _calling = false);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseAnim.dispose();
    super.dispose();
  }

  String get _elapsed {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fond dégradé animé
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _calling
                    ? [const Color(0xFF0A1A0A), const Color(0xFF050505)]
                    : [const Color(0xFF0D2010), const Color(0xFF050505)],
              ),
            ),
          ),

          // Cercles animés
          Center(
            child: ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3CFF7E).withOpacity(0.04),
                  border: Border.all(
                    color: const Color(0xFF3CFF7E).withOpacity(0.08),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3CFF7E).withOpacity(0.06),
                border: Border.all(
                  color: const Color(0xFF3CFF7E).withOpacity(0.12),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3CFF7E), Color(0xFF00C853)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.chatName.isNotEmpty
                          ? widget.chatName[0].toUpperCase()
                          : 'L',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Nom
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // Statut
                Text(
                  _calling ? "Appel en cours..." : _elapsed,
                  style: TextStyle(
                    color: _calling ? Colors.white38 : const Color(0xFF3CFF7E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (widget.isVideo && !_calling) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CFF7E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3CFF7E).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3CFF7E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Vidéo HD",
                          style: TextStyle(
                            color: Color(0xFF3CFF7E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Boutons contrôle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _controlBtn(
                            icon: _muted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            label: _muted ? "Muet" : "Micro",
                            color: _muted ? Colors.redAccent : Colors.white,
                            onTap: () => setState(() => _muted = !_muted),
                          ),
                          _controlBtn(
                            icon: _speakerOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            label: "Haut-parleur",
                            color: _speakerOn
                                ? const Color(0xFF3CFF7E)
                                : Colors.white,
                            onTap: () =>
                                setState(() => _speakerOn = !_speakerOn),
                          ),
                          if (widget.isVideo)
                            _controlBtn(
                              icon: _cameraOff
                                  ? Icons.videocam_off_rounded
                                  : Icons.videocam_rounded,
                              label: "Caméra",
                              color: _cameraOff
                                  ? Colors.redAccent
                                  : Colors.white,
                              onTap: () =>
                                  setState(() => _cameraOff = !_cameraOff),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Bouton fin appel
                      GestureDetector(
                        onTap: widget.onEnd,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Raccrocher",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
