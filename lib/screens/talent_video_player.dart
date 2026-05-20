import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../models/user.dart';
import 'profile_screen.dart';
import 'home_screen.dart' show SharedCommentsSheet;
import '../services/social_service.dart';

class TalentVideoPlayer extends StatefulWidget {
  final dynamic talent;
  final Color sportColor; // ← couleur dynamique selon le sport
  const TalentVideoPlayer({
    super.key,
    required this.talent,
    this.sportColor = const Color(0xFF3CFF7E),
  });

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
  bool _isBuffering = false;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.talent['is_liked_by_me'] ?? false;
    _initializePlayer();
  }

  void _initializePlayer() {
    final videoUrl = widget.talent['video_url']?.toString() ?? '';
    if (videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.play();
          _controller.addListener(_onVideoListener);
        }
      });
  }

  void _onVideoListener() {
    if (!mounted) return;
    final buffering = _controller.value.isBuffering;
    if (buffering != _isBuffering) setState(() => _isBuffering = buffering);
  }

  String _formatDuration(Duration d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${pad(d.inMinutes.remainder(60))}:${pad(d.inSeconds.remainder(60))}";
  }

  // ── Double tap = like + animation ──────────────────────────
  void _handleDoubleTap() {
    if (!_isLiked) _toggleLike();
    setState(() => _showHeart = false);
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        setState(() => _showHeart = true);
        HapticFeedback.heavyImpact();
      }
    });
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  // ── Simple tap = contrôles ──────────────────────────────────
  void _handleTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsTimer?.cancel();
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  // ── Like ────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    final talentId = widget.talent['id'].toString();
    final userId = _socialService.supabase.auth.currentUser!.id;

    setState(() {
      _isLiked = !wasLiked;
      int cur =
          int.tryParse(widget.talent['likes_count']?.toString() ?? '0') ?? 0;
      widget.talent['likes_count'] = !wasLiked ? cur + 1 : cur - 1;
      widget.talent['is_liked_by_me'] = !wasLiked;
    });

    try {
      await _socialService.toggleTalentLike(talentId, userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          int cur =
              int.tryParse(widget.talent['likes_count']?.toString() ?? '0') ??
              0;
          widget.talent['likes_count'] = wasLiked ? cur : cur - 1;
          widget.talent['is_liked_by_me'] = wasLiked;
        });
      }
    }
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized) return;
    _controller.seekTo(_controller.value.position + Duration(seconds: seconds));
    HapticFeedback.mediumImpact();
  }

  // ── Commentaires ────────────────────────────────────────────
  void _showComments() {
    final userId = _socialService.supabase.auth.currentUser!.id;

    final dynamic rawUsers = widget.talent['users'];
    Map<String, dynamic> authorData = {};
    if (rawUsers is List && rawUsers.isNotEmpty) {
      authorData = Map<String, dynamic>.from(rawUsers[0]);
    } else if (rawUsers is Map<String, dynamic>) {
      authorData = rawUsers;
    }

    final fakePost = {
      'id': widget.talent['id'],
      'comments_count': widget.talent['comments_count'] ?? 0,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => SharedCommentsSheet(
        post: fakePost,
        socialService: _socialService,
        currentUserId: userId,
        currentUserImg: authorData['img_url'],
        currentUserName: authorData['full_name'] ?? 'Lion',
        onCommentAdded: () {
          if (mounted) {
            setState(() {
              int cur =
                  int.tryParse(
                    widget.talent['comments_count']?.toString() ?? '0',
                  ) ??
                  0;
              widget.talent['comments_count'] = cur + 1;
            });
          }
        },
        onNavigateToProfile: (ud) {
          if (ud == null) return;
          final uid = ud['id'] ?? '';
          if (uid.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                user: User(
                  id: uid,
                  fullName: ud['full_name'] ?? 'Utilisateur',
                  email: ud['email'] ?? '',
                  role: ud['role'] ?? 'USER',
                  isCertified: ud['is_certified'] ?? false,
                  img_url: ud['img_url'],
                  bio: ud['bio'],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.removeListener(_onVideoListener);
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final dynamic rawUsers = widget.talent['users'];
    Map<String, dynamic> userData = {};
    if (rawUsers is List && rawUsers.isNotEmpty) {
      userData = Map<String, dynamic>.from(rawUsers[0]);
    } else if (rawUsers is Map<String, dynamic>) {
      userData = rawUsers;
    }

    final fullName = userData['full_name']?.toString() ?? 'Lion anonyme';
    final avatarUrl = userData['img_url']?.toString();
    final isCertified = userData['is_certified'] == true;
    final city = (widget.talent['city'] ?? userData['city'] ?? '').toString();
    final sport = widget.talent['sport_type']?.toString() ?? '';
    final category = widget.talent['category']?.toString() ?? '';
    final niveau = widget.talent['level']?.toString() ?? '';
    final color = widget.sportColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Vidéo ──────────────────────────────────────
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
                        color: Color(0xFF3CFF7E),
                        strokeWidth: 2,
                      ),
                    ),
            ),

            // ── Gradient haut ──────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.2, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // ── Buffering indicator ────────────────────────
            if (_isBuffering && _isInitialized)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.black.withOpacity(0.4),
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Contrôles lecture ──────────────────────────
            if (_showControls && _isInitialized)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _controlBtn(
                      Icons.replay_10_rounded,
                      () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 28),
                    _controlBtn(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      () => setState(
                        () => _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                      ),
                      size: 80,
                    ),
                    const SizedBox(width: 28),
                    _controlBtn(
                      Icons.forward_10_rounded,
                      () => _seekRelative(10),
                    ),
                  ],
                ),
              ),

            // ── Animation cœur double tap ──────────────────
            if (_showHeart)
              IgnorePointer(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _LionHeartPart(color: color, size: 200, delay: 0),
                      _LionHeartPart(
                        color: Colors.redAccent,
                        size: 130,
                        delay: 150,
                      ),
                      _LionStarPart(color: color, delay: 350),
                    ],
                  ),
                ),
              ),

            // ── Header : retour + sport badge ──────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (sport.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Text(
                            sport.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Infos bas gauche ───────────────────────────
            Positioned(
              bottom: 40,
              left: 14,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Durée
                  if (_isInitialized)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  // Label TALENT
                  Text(
                    "TALENT",
                    style: TextStyle(
                      color: color,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(blurRadius: 20, color: color.withOpacity(0.4)),
                      ],
                    ),
                  ),

                  // Auteur
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(user: User.fromJson(userData)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    fullName.isNotEmpty
                                        ? fullName[0].toUpperCase()
                                        : 'L',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCertified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.blueAccent,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                              if (city.isNotEmpty)
                                Text(
                                  "📍 $city",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Carte infos sportives
                  _buildInfoCard(category, niveau, color),
                ],
              ),
            ),

            // ── Actions droite ─────────────────────────────
            Positioned(
              right: 12,
              bottom: 40,
              child: Column(
                children: [
                  _actionBtn(
                    icon: _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.redAccent : Colors.white,
                    label: _fmtCount(
                      int.tryParse(
                            widget.talent['likes_count']?.toString() ?? '0',
                          ) ??
                          0,
                    ),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _toggleLike();
                    },
                    glowColor: _isLiked ? Colors.redAccent : null,
                  ),
                  const SizedBox(height: 4),
                  _actionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    label: _fmtCount(
                      int.tryParse(
                            widget.talent['comments_count']?.toString() ?? '0',
                          ) ??
                          0,
                    ),
                    onTap: _showComments,
                  ),
                  const SizedBox(height: 4),
                  _actionBtn(
                    icon: Icons.repeat_rounded,
                    color: Colors.white,
                    label: _fmtCount(
                      int.tryParse(
                            widget.talent['reposts_count']?.toString() ?? '0',
                          ) ??
                          0,
                    ),
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      try {
                        final uid =
                            _socialService.supabase.auth.currentUser!.id;
                        await _socialService.talentRepost(
                          widget.talent['id'].toString(),
                          uid,
                        );
                        setState(() {
                          int cur =
                              int.tryParse(
                                widget.talent['reposts_count']?.toString() ??
                                    '0',
                              ) ??
                              0;
                          widget.talent['reposts_count'] = cur + 1;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Talent reposté !",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              backgroundColor: color,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint("Repost error: $e");
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  _actionBtn(
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.amber,
                    label: "TOP",
                    glowColor: Colors.amber,
                  ),
                ],
              ),
            ),

            // ── Barre de progression ───────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _isInitialized
                  ? VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: color,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    )
                  : const SizedBox(height: 3),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carte infos ─────────────────────────────────────────────
  Widget _buildInfoCard(String category, String niveau, Color color) {
    if (category.isEmpty && niveau.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (category.isNotEmpty)
                _infoChip(Icons.place_rounded, category, color),
              if (niveau.isNotEmpty)
                _infoChip(Icons.bar_chart_rounded, niveau, Colors.amber),
              if (widget.talent['age'] != null)
                _infoChip(
                  Icons.cake_outlined,
                  "${widget.talent['age']} ans",
                  Colors.white54,
                ),
              if (widget.talent['height'] != null)
                _infoChip(
                  Icons.height_rounded,
                  "${widget.talent['height']} cm",
                  Colors.white54,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _controlBtn(IconData icon, VoidCallback onTap, {double size = 52}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.65),
        ),
      );

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
    Color? glowColor,
  }) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: glowColor != null
                  ? [
                      BoxShadow(
                        color: glowColor.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  String _fmtCount(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════════════
// ANIMATIONS CŒUR
// ═══════════════════════════════════════════════════════════════

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
      builder: (_, _) {
        final val = Curves.elasticOut.transform(_anim.value);
        return Opacity(
          opacity: (1.0 - _anim.value).clamp(0, 1),
          child: Transform.scale(
            scale: val * widget.size / 100,
            child: Icon(
              Icons.favorite_rounded,
              color: widget.color,
              size: widget.size,
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

class _LionStarPart extends StatefulWidget {
  final Color color;
  final int delay;
  const _LionStarPart({required this.color, required this.delay});

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
      builder: (_, _) {
        final val = Curves.easeOutBack.transform(_anim.value);
        return Opacity(
          opacity: (1.2 - _anim.value).clamp(0, 1),
          child: Transform.scale(
            scale: val * 1.5,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: widget.color,
              size: 55,
              shadows: [
                Shadow(color: widget.color.withOpacity(0.5), blurRadius: 20),
              ],
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
