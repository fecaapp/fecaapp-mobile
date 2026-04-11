import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../models/user.dart';
import 'profile_screen.dart';
import '../services/social_service.dart';

class TalentVideoPlayer extends StatefulWidget {
  final dynamic talent;
  const TalentVideoPlayer({super.key, required this.talent});

  @override
  State<TalentVideoPlayer> createState() => _TalentVideoPlayerState();
}

class _TalentVideoPlayerState extends State<TalentVideoPlayer> {
  late VideoPlayerController _controller;
  final SocialService _socialService = SocialService();
  bool _isLiked = false;
  bool _showHeart = false;
  bool _isInitialized = false;
  bool _showControls = false;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    // Initialisation propre depuis les données du talent
    _isLiked = widget.talent['is_liked_by_me'] ?? false;
    _initializePlayer();
  }

  void _initializePlayer() {
    String videoUrl = widget.talent['video_url'] ?? "";
    if (videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.play();
          _controller.addListener(() {
            if (mounted) setState(() {});
          });
        }
      });
  }

  // Formattage du temps (ex: 0:15)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // --- LOGIQUE DOUBLE TAP : L'ANIMATION LION ---
  void _handleGlobalDoubleTap() {
    if (!_isLiked) _toggleLike();

    setState(() => _showHeart = false);

    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        setState(() => _showHeart = true);
        HapticFeedback.heavyImpact();
      }
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _handleSingleTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsTimer?.cancel();
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  // --- LOGIQUE LIKE (UNIFIÉE : MISE À JOUR LOCALE ET SYNC DB) ---
  Future<void> _toggleLike() async {
    final bool wasLiked = _isLiked;
    final String talentId = widget.talent['id'].toString();
    final String currentUserId = _socialService.supabase.auth.currentUser!.id;

    // Mise à jour instantanée de l'UI et de l'objet talent (Persistance locale forte)
    setState(() {
      _isLiked = !wasLiked;
      int currentLikes =
          int.tryParse(widget.talent['likes_count']?.toString() ?? '0') ?? 0;

      // Mise à jour de l'objet source pour éviter le reset au scroll
      widget.talent['likes_count'] = !wasLiked
          ? (currentLikes + 1)
          : (currentLikes - 1);
      widget.talent['is_liked_by_me'] = !wasLiked;
    });

    try {
      // Utilise désormais la table 'likes' unifiée via le service
      await _socialService.toggleTalentLike(talentId, currentUserId);
    } catch (e) {
      // Rollback en cas d'erreur
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          int currentLikes =
              int.tryParse(widget.talent['likes_count']?.toString() ?? '0') ??
              0;
          widget.talent['likes_count'] = wasLiked
              ? currentLikes
              : (currentLikes - 1);
          widget.talent['is_liked_by_me'] = wasLiked;
        });
      }
    }
  }

  void _seekRelative(int seconds) {
    if (_isInitialized) {
      _controller.seekTo(
        _controller.value.position + Duration(seconds: seconds),
      );
      HapticFeedback.mediumImpact();
    }
  }

  // --- MODAL COMMENTAIRES (SUR TABLES UNIFIÉES) ---
  void _showCommentsModal() {
    final TextEditingController commentController = TextEditingController();
    final String talentId = widget.talent['id'].toString();
    final String currentUserId = _socialService.supabase.auth.currentUser!.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "ESPACE COMMENTAIRES",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<dynamic>>(
                  stream: _socialService.getTalentCommentsStream(talentId),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: comments.length,
                      itemBuilder: (context, i) =>
                          _buildCommentTile(comments[i]),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 15,
                ),
                decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Ajoute ton commentaire...",
                          hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final text = commentController.text.trim();
                        if (text.isNotEmpty) {
                          bool ok = await _socialService.addTalentComment(
                            talentId,
                            currentUserId,
                            text,
                          );
                          if (ok) {
                            commentController.clear();
                            // Mise à jour locale pour éviter le reset au scroll
                            setState(() {
                              int current =
                                  int.tryParse(
                                    widget.talent['comments_count']
                                            ?.toString() ??
                                        '0',
                                  ) ??
                                  0;
                              widget.talent['comments_count'] = current + 1;
                            });
                          }
                        }
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.greenAccent,
                        radius: 22,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(dynamic comment) {
    final bool isCert = comment['is_certified'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: (comment['author_img_url'] != null)
                ? NetworkImage(comment['author_img_url'])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['author_name'] ?? "Lion",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (isCert) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.blueAccent,
                        size: 12,
                      ),
                    ],
                  ],
                ),
                Text(
                  comment['content'] ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extraction robuste des données utilisateur (Map ou List)
    final dynamic rawUsers = widget.talent['users'];
    Map<String, dynamic> userData = {};
    if (rawUsers is List && rawUsers.isNotEmpty) {
      userData = rawUsers[0];
    } else if (rawUsers is Map<String, dynamic>) {
      userData = rawUsers;
    }

    final String fullName = userData['full_name'] ?? "Lion anonyme";
    final String? avatarUrl = userData['img_url'];
    final bool isCertified = userData['is_certified'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleSingleTap,
        onDoubleTap: _handleGlobalDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: _isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.greenAccent,
                        strokeWidth: 2,
                      ),
                    ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            if (_showControls && _isInitialized)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 55,
                    ),
                    onPressed: () => _seekRelative(-10),
                  ),
                  const SizedBox(width: 30),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      color: Colors.white,
                      size: 85,
                    ),
                    onPressed: () => setState(
                      () => _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play(),
                    ),
                  ),
                  const SizedBox(width: 30),
                  IconButton(
                    icon: const Icon(
                      Icons.forward_10_rounded,
                      color: Colors.white,
                      size: 55,
                    ),
                    onPressed: () => _seekRelative(10),
                  ),
                ],
              ),

            if (_showHeart)
              Stack(
                alignment: Alignment.center,
                children: [
                  _LionHeartPart(
                    color: Colors.greenAccent,
                    size: 200,
                    delay: 0,
                  ),
                  _LionHeartPart(
                    color: Colors.redAccent,
                    size: 130,
                    delay: 200,
                  ),
                  _LionStarPart(delay: 400),
                ],
              ),
            Positioned(
              bottom: 45,
              left: 15,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isInitialized)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  const Text(
                    "TALENT",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 15, color: Colors.black)],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfileScreen(user: User.fromJson(userData)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.greenAccent,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: (avatarUrl != null)
                                ? NetworkImage(avatarUrl)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCertified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoCard(),
                ],
              ),
            ),

            Positioned(
              right: 15,
              bottom: 50,
              child: Column(
                children: [
                  _buildActionButton(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.redAccent : Colors.white,
                    label: widget.talent['likes_count']?.toString() ?? "0",
                    onTap: _toggleLike,
                  ),
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    label: widget.talent['comments_count']?.toString() ?? "0",
                    onTap: _showCommentsModal,
                  ),
                  _buildActionButton(
                    icon: Icons.repeat_rounded,
                    color: Colors.white,
                    label: widget.talent['reposts_count']?.toString() ?? "0",
                    onTap: () async {
                      try {
                        final String currentUserId =
                            _socialService.supabase.auth.currentUser!.id;
                        await _socialService.talentRepost(
                          widget.talent['id'].toString(),
                          currentUserId,
                        );
                        // Mise à jour locale immédiate du compteur
                        setState(() {
                          int current =
                              int.tryParse(
                                widget.talent['reposts_count']?.toString() ??
                                    '0',
                              ) ??
                              0;
                          widget.talent['reposts_count'] = current + 1;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Talent reposté !")),
                          );
                        }
                      } catch (e) {
                        debugPrint("Erreur Repost: $e");
                      }
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.auto_awesome,
                    color: Colors.amber,
                    label: "TOP",
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 4,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.greenAccent,
                    bufferedColor: Colors.white24,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 50,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 35),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.talent['category']?.toUpperCase() ?? 'JOUEUR'} • ${widget.talent['specialty']?.toUpperCase() ?? 'TALENT'}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              Text(
                "${widget.talent['age'] ?? '--'} ANS • ${widget.talent['height'] ?? '--'} CM • PIED ${widget.talent['foot']?.toString().toUpperCase() ?? '--'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class _LionHeartPart extends StatefulWidget {
  final Color color;
  final double size;
  final int delay;
  const _LionHeartPart({
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  State<_LionHeartPart> createState() => _LionHeartPartState();
}

class _LionHeartPartState extends State<_LionHeartPart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        double val = Curves.elasticOut.transform(_anim.value);
        return Opacity(
          opacity: (1.0 - _anim.value).clamp(0, 1),
          child: Transform.scale(
            scale: val * widget.size / 100,
            child: Icon(Icons.favorite, color: widget.color, size: widget.size),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

class _LionStarPart extends StatefulWidget {
  final int delay;
  const _LionStarPart({required this.delay});
  @override
  State<_LionStarPart> createState() => _LionStarPartState();
}

class _LionStarPartState extends State<_LionStarPart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        double val = Curves.easeOutBack.transform(_anim.value);
        return Opacity(
          opacity: (1.2 - _anim.value).clamp(0, 1),
          child: Transform.scale(
            scale: val * 1.5,
            child: const Icon(
              Icons.star,
              color: Colors.yellow,
              size: 60,
              shadows: [Shadow(color: Colors.orange, blurRadius: 20)],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
