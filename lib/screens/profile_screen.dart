import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user.dart';
import '../services/social_service.dart';
import 'messages_screen.dart';
import 'create_content_screen.dart';
import 'dashboard_screen.dart';
import 'dart:io';
import '../widgets/video_post_player.dart';

// ==========================================
// FICHIER : PROFILE_SCREEN.DART
// ==========================================

class ProfileScreen extends StatefulWidget {
  final User user;
  final bool isMe;
  const ProfileScreen({super.key, required this.user, this.isMe = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  final sb.SupabaseClient supabase = sb.Supabase.instance.client;

  bool isExpanded = false;
  bool isFollowing = false;
  int followersCount = 0;
  bool _isLoading = true;
  bool _showLikeOverlay = false;
  List<dynamic> _userPosts = [];

  late AnimationController _likeController;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _moveUp;

  late String currentFullName;
  late String currentUsername;
  late String currentBio;
  String? currentAvatarUrl;
  String? currentCoverUrl;

  // --- VIDÉO : suivi de quel post est en lecture ---
  String? _playingVideoPostId;

  @override
  void initState() {
    super.initState();
    currentFullName = widget.user.fullName;
    currentUsername = widget.user.fullName.replaceAll(' ', '_').toLowerCase();
    currentBio =
        widget.user.bio ??
        "Rugissement officiel sur la plateforme des Lions. 🦁";
    currentAvatarUrl = widget.user.img_url;
    currentCoverUrl = widget.user.cover_url;
    followersCount = widget.user.followersCount;
    isFollowing = widget.user.isFollowing ?? false;

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween(
      begin: 0.6,
      end: 1.4,
    ).chain(CurveTween(curve: Curves.elasticOut)).animate(_likeController);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_likeController);
    _moveUp =
        Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: const Offset(0, -0.8),
        ).animate(
          CurvedAnimation(parent: _likeController, curve: Curves.easeOutCubic),
        );

    _initProfile();
  }

  Future<void> _initProfile() async {
    await _checkFollowingStatus();
    await _loadUserContent();
    _setupRealtime();
  }

  void _setupRealtime() {
    _socialService.subscribeToPosts(() {
      if (mounted) _loadUserContent();
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadUserContent();
  }

  Future<void> _loadUserContent() async {
    if (!mounted) return;
    try {
      final String myId = supabase.auth.currentUser!.id;
      final posts = await _socialService.fetchPosts(
        myId,
        authorId: widget.user.id,
      );
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', widget.user.id)
          .single();
      if (mounted) {
        setState(() {
          _userPosts = posts;
          currentAvatarUrl = userData['img_url'] ?? currentAvatarUrl;
          currentCoverUrl = userData['cover_url'] ?? currentCoverUrl;
          currentFullName = userData['full_name'] ?? currentFullName;
          currentBio = userData['bio'] ?? currentBio;
          followersCount = userData['followers_count'] ?? followersCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🦁 Erreur loadUserContent: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String dateTimeStr) {
    try {
      DateTime postDate = DateTime.parse(dateTimeStr);
      Duration diff = DateTime.now().difference(postDate);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "il y a ${diff.inHours} h";
      return "${postDate.day}/${postDate.month}/${postDate.year}";
    } catch (e) {
      return "Récemment";
    }
  }

  Future<void> _toggleLike(dynamic post) async {
    final bool isLiked = post['is_liked_by_me'] ?? false;
    setState(() {
      post['is_liked_by_me'] = !isLiked;
      post['likes_count'] = isLiked
          ? (post['likes_count'] - 1)
          : (post['likes_count'] + 1);
    });
    try {
      await _socialService.toggleLike(
        post['id'].toString(),
        supabase.auth.currentUser!.id,
      );
    } catch (e) {
      _loadUserContent();
    }
  }

  void _handleDoubleTap(dynamic post) {
    if (!(post['is_liked_by_me'] ?? false)) _toggleLike(post);
    HapticFeedback.mediumImpact();
    setState(() => _showLikeOverlay = true);
    _likeController.forward(from: 0);
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showLikeOverlay = false);
    });
  }

  void _showZoomedImage(String url) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Hero(
                tag: url,
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
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
      ),
    );
  }

  Future<void> _checkFollowingStatus() async {
    try {
      final String myId = supabase.auth.currentUser!.id;
      final bool following = await _socialService.isFollowing(
        myId,
        widget.user.id,
      );
      if (mounted) setState(() => isFollowing = following);
    } catch (e) {
      debugPrint("🦁 Erreur check follow: $e");
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        HapticFeedback.mediumImpact();
        setState(() => _isLoading = true);
        final bool success = await _socialService.updateProfileMedia(
          userId: widget.user.id,
          file: File(image.path),
          type: isCover ? 'cover' : 'avatar',
        );
        if (success) {
          await _socialService.createPost(
            userId: widget.user.id,
            content: isCover
                ? "🦁 A mis à jour sa couverture !"
                : "🦁 A mis à jour sa photo de profil !",
            type: 'IMAGE',
            file: File(image.path),
          );
          await _loadUserContent();
        }
      }
    } catch (e) {
      debugPrint("🦁 Erreur pickImage: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // APP BAR
  // ==========================================

  Widget _buildAppBar() {
    final String coverUrl =
        (currentCoverUrl != null && currentCoverUrl!.isNotEmpty)
        ? currentCoverUrl!
        : "https://images.unsplash.com/photo-1504450758481-7338eba7524a?q=80";

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => _showZoomedImage(coverUrl),
              child: Hero(
                tag: coverUrl,
                child: Image.network(coverUrl, fit: BoxFit.cover),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.transparent, Colors.black],
                ),
              ),
            ),
            if (supabase.auth.currentUser!.id == widget.user.id)
              Positioned(
                right: 15,
                bottom: 15,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.white12,
                  elevation: 0,
                  onPressed: () => _pickImage(true),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BLOC 2 - AVATAR & INFOS
  // ==========================================

  Widget _buildProfileAvatar() {
    final String avatarUrl =
        (currentAvatarUrl != null && currentAvatarUrl!.isNotEmpty)
        ? currentAvatarUrl!
        : "";
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [Colors.green, Colors.red, Colors.yellow, Colors.green],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                shape: BoxShape.circle,
              ),
              child: GestureDetector(
                onTap: avatarUrl.isNotEmpty
                    ? () => _showZoomedImage(avatarUrl)
                    : null,
                child: Hero(
                  tag: avatarUrl.isNotEmpty
                      ? avatarUrl
                      : 'profile_pic_fallback',
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.white10,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            currentFullName.isNotEmpty
                                ? currentFullName[0].toUpperCase()
                                : "L",
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white24,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          if (supabase.auth.currentUser?.id == widget.user.id)
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A0A0A), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10),
                  ],
                ),
                child: const Icon(
                  Icons.camera_enhance_rounded,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  currentFullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.user.isCertified ? Icons.verified : Icons.stars_rounded,
                color: widget.user.isCertified
                    ? Colors.blueAccent
                    : Colors.amber,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "@${currentUsername.toLowerCase()}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: _toggleFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isFollowing ? Colors.white24 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          isFollowing ? "SE DÉSABONNER" : "S'ABONNER",
          style: TextStyle(
            color: isFollowing ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final String? myId = supabase.auth.currentUser?.id;
    final String targetId = widget.user.id;
    if (myId == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (isFollowing) {
        isFollowing = false;
        followersCount = (followersCount > 0) ? followersCount - 1 : 0;
      } else {
        isFollowing = true;
        followersCount++;
      }
    });
    try {
      await _socialService.toggleFollow(myId, targetId);
    } catch (e) {
      if (mounted) {
        setState(() {
          isFollowing = !isFollowing;
          isFollowing ? followersCount++ : followersCount--;
        });
      }
      debugPrint("🦁 Erreur Follow: $e");
    }
  }

  Widget _buildBioSection() {
    final bool isLongBio = currentBio.length > 90;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      child: GestureDetector(
        onTap: isLongBio
            ? () => setState(() => isExpanded = !isExpanded)
            : null,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: isExpanded || !isLongBio
                      ? currentBio
                      : "${currentBio.substring(0, (currentBio.length < 90 ? currentBio.length : 90))}... ",
                ),
                if (isLongBio)
                  TextSpan(
                    text: isExpanded ? " voir moins" : " voir plus",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildStatItem(
              followersCount,
              "Abonnés",
              onTap: () => debugPrint("Voir abonnés"),
            ),
          ),
          Container(height: 30, width: 1, color: Colors.white10),
          Expanded(
            child: _buildStatItem(
              widget.user.followingCount,
              "Abonnements",
              onTap: () => debugPrint("Voir abonnements"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, {VoidCallback? onTap}) {
    String formattedCount = count >= 1000
        ? "${(count / 1000).toStringAsFixed(1)}k"
        : "$count";
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formattedCount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BLOC 3 - ACTIONS & DASHBOARD
  // ==========================================

  Widget _buildStrategicButtons() {
    final bool isMyProfile = supabase.auth.currentUser?.id == widget.user.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (isMyProfile)
            Expanded(
              child: _buildActionBtn(
                label: "MODIFIER LE PROFIL",
                onTap: () => _showEditProfileDialog(),
                color: const Color(0xFF1A1A1A),
                textColor: Colors.white,
              ),
            ),
          if (isMyProfile) const SizedBox(width: 12),
          Expanded(
            flex: isMyProfile ? 0 : 1,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MessagesScreen(currentUserId: widget.user.id),
                  ),
                );
              },
              child: Container(
                height: 50,
                width: isMyProfile ? 55 : null,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      if (!isMyProfile) ...[
                        const SizedBox(width: 10),
                        const Text(
                          "MESSAGE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardEntry(BuildContext context) {
    if (supabase.auth.currentUser?.id != widget.user.id) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tableau de bord professionnel",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Analysez la portée de vos rugissements",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_mosaic_rounded,
            color: Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "PUBLICATIONS STUDIO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${_userPosts.length} POSTS",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BLOC 4 - FEED : SliverList pour fluidité
  // ==========================================

  // --- FLUIDE : SliverList remplace ListView.builder shrinkWrap ---
  List<Widget> _buildFeedSlivers() {
    if (_isLoading && _userPosts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(60.0),
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ];
    }

    if (_userPosts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.layers_clear_rounded,
                color: Colors.white.withOpacity(0.05),
                size: 70,
              ),
              const SizedBox(height: 20),
              const Text(
                "Aucun rugissement dans le studio",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final post = _userPosts[index];
          return RepaintBoundary(
            child: _buildFeedItem(post: post, index: index),
          );
        }, childCount: _userPosts.length),
      ),
    ];
  }

  Widget _buildFeedItem({required dynamic post, required int index}) {
    final String? mediaUrl = post['media_url'];
    final String postType = post['type']?.toString().toUpperCase() ?? 'TEXT';
    final bool isLiked = post['is_liked_by_me'] ?? false;
    final int likesCount = post['likes_count'] ?? 0;
    final int commentsCount = post['comments_count'] ?? 0;
    final int repostsCount = post['reposts_count'] ?? 0;
    final String postId = post['id']?.toString() ?? '';

    // --- VIDÉO : lecture uniquement si l'utilisateur tape ---
    final bool isPlayingVideo = _playingVideoPostId == postId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: GestureDetector(
        onDoubleTap: () => _handleDoubleTap(post),
        child: Container(
          height: 520,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // --- MÉDIA ---
              Positioned.fill(
                child: postType == 'TEXT'
                    ? Container(
                        padding: const EdgeInsets.all(40),
                        color: const Color(0xFF121212),
                        child: Center(
                          child: Text(
                            post['content'] ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : (mediaUrl != null && mediaUrl.isNotEmpty)
                    ? postType == 'VIDEO'
                          // --- VIDÉO : thumbnail + bouton play, lecture au tap ---
                          ? isPlayingVideo
                                ? VideoPostPlayer(videoUrl: mediaUrl)
                                : GestureDetector(
                                    onTap: () => setState(
                                      () => _playingVideoPostId = postId,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(color: Colors.black),
                                        const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_circle_fill_rounded,
                                                color: Colors.white,
                                                size: 70,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                "Appuyer pour lire",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                          : GestureDetector(
                              onTap: () => _showZoomedImage(mediaUrl),
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.greenAccent,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stack) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white24,
                                      ),
                                    ),
                              ),
                            )
                    : Container(color: const Color(0xFF1A1A1A)),
              ),

              // --- GRADIENT ---
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 1.0],
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.transparent,
                          Colors.black.withOpacity(0.70),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- HEADER ---
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          currentAvatarUrl != null &&
                              currentAvatarUrl!.isNotEmpty
                          ? NetworkImage(currentAvatarUrl!)
                          : null,
                      backgroundColor: Colors.white10,
                      child:
                          (currentAvatarUrl == null ||
                              currentAvatarUrl!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              color: Colors.white24,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentFullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                widget.user.isCertified
                                    ? Icons.verified
                                    : Icons.stars_rounded,
                                color: widget.user.isCertified
                                    ? Colors.blueAccent
                                    : Colors.amber,
                                size: 14,
                              ),
                            ],
                          ),
                          Text(
                            _timeAgo(post['created_at']?.toString() ?? ""),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showPostOptions(post),
                      child: const Icon(Icons.more_horiz, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // --- FOOTER : contenu + actions bien contraints ---
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (postType != 'TEXT' &&
                        post['content'] != null &&
                        post['content'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          post['content'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // --- ACTIONS : SingleChildScrollView horizontal pour éviter overflow ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _interactionItem(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            "$likesCount",
                            isLiked ? Colors.red : Colors.white,
                            onTap: () => _toggleLike(post),
                          ),
                          const SizedBox(width: 8),
                          _interactionItem(
                            Icons.chat_bubble_outline_rounded,
                            "$commentsCount",
                            Colors.white,
                            onTap: () => _showCommentsModal(post),
                          ),
                          const SizedBox(width: 8),
                          _interactionItem(
                            Icons.repeat_rounded,
                            "$repostsCount",
                            repostsCount > 0
                                ? Colors.greenAccent
                                : Colors.white,
                            onTap: () => _handleRepost(post),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ],
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

  Widget _interactionItem(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label != "0") ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLikeHeart() => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(
      position: _moveUp,
      child: ScaleTransition(
        scale: _scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.green, Colors.red, Colors.yellow],
                stops: [0.33, 0.33, 0.66],
              ).createShader(bounds),
              child: const Icon(Icons.favorite, color: Colors.white, size: 140),
            ),
            const Positioned(
              top: 55,
              child: Icon(Icons.star, color: Colors.yellow, size: 40),
            ),
          ],
        ),
      ),
    ),
  );

  void _handleRepost(dynamic post) async {
    HapticFeedback.mediumImpact();
    setState(() {
      int currentCount = post['reposts_count'] ?? 0;
      post['reposts_count'] = currentCount + 1;
    });
    try {
      await _socialService.repost(supabase.auth.currentUser!.id, post);
      _loadUserContent();
    } catch (e) {
      _loadUserContent();
      debugPrint("🦁 Erreur repost: $e");
    }
  }

  // ==========================================
  // BLOC 5 - BUILD PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final bool isMyProfile = widget.user.id == supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      floatingActionButton: isMyProfile ? _buildFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        color: Colors.greenAccent,
        backgroundColor: Colors.black,
        onRefresh: _handleRefresh,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      _buildProfileAvatar(),
                      const SizedBox(height: 15),
                      _buildUserInfo(),
                      _buildBioSection(),
                      const SizedBox(height: 25),
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      _buildStrategicButtons(),
                      const SizedBox(height: 15),
                      _buildDashboardEntry(context),
                      const SizedBox(height: 20),
                      _buildContentHeader(),
                    ],
                  ),
                ),
                // --- FLUIDE : SliverList direct dans CustomScrollView ---
                ..._buildFeedSlivers(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
            // --- CŒUR au niveau Scaffold ---
            if (_showLikeOverlay)
              IgnorePointer(child: Center(child: _buildLikeHeart())),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () => _showPublishMenu(context),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 35),
      ),
    );
  }

  /* ================= COMMENTAIRES & OPTIONS ================= */

  void _showCommentsModal(dynamic post) {
    final TextEditingController commentController = TextEditingController();
    final String postId = post['id'].toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.8),
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
                  stream: _socialService.getCommentsStream(postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          "Soyez le premier à commenter ici !",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final comment = comments[i];
                        final String authorId = comment['author_id'] ?? "";
                        final String authorName =
                            comment['author_name'] ?? "Lion anonyme";
                        final String? authorImg = comment['author_img_url'];
                        final bool isUserCertified =
                            comment['is_certified'] == true;

                        void goToProfile() {
                          if (authorId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  user: User(
                                    id: authorId,
                                    fullName: authorName,
                                    email: "",
                                    role: "USER",
                                    isCertified: isUserCertified,
                                    img_url: authorImg,
                                    bio: "",
                                  ),
                                  isMe: authorId == widget.user.id,
                                ),
                              ),
                            );
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: goToProfile,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  backgroundImage:
                                      (authorImg != null &&
                                          authorImg.isNotEmpty)
                                      ? NetworkImage(authorImg)
                                      : null,
                                  child:
                                      (authorImg == null || authorImg.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          size: 18,
                                          color: Colors.white30,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: goToProfile,
                                            child: Text(
                                              authorName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        if (isUserCertified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified,
                                            color: Colors.blueAccent,
                                            size: 12,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['content'] ?? "",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                        style: const TextStyle(color: Colors.white),
                        maxLines: null,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final text = commentController.text.trim();
                        if (text.isNotEmpty) {
                          HapticFeedback.lightImpact();
                          bool ok = await _socialService.addComment(
                            postId,
                            supabase.auth.currentUser!.id,
                            text,
                          );
                          if (ok) {
                            commentController.clear();
                            setState(() {
                              int currentCount =
                                  int.tryParse(
                                    post['comments_count']?.toString() ?? '0',
                                  ) ??
                                  0;
                              post['comments_count'] = currentCount + 1;
                            });
                            setModalState(() {});
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

  void _showPostOptions(dynamic post) {
    bool isMyPost = post['author_id'] == supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyPost)
              _drawerTile(
                Icons.delete_outline_rounded,
                "Supprimer ce post",
                Colors.redAccent,
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  await _socialService.deletePost(post['id']);
                  Navigator.pop(context);
                  _handleRefresh();
                },
              )
            else ...[
              _drawerTile(
                Icons.flag_outlined,
                "Signaler le contenu",
                Colors.white70,
                onTap: () => Navigator.pop(context),
              ),
              _drawerTile(
                Icons.block_flipped,
                "Bloquer l'utilisateur",
                Colors.orangeAccent,
                onTap: () => Navigator.pop(context),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title,
    Color color, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }

  void _showPublishMenu(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 30,
          top: 15,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "CRÉATION STUDIO",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 30),
            _publishOption(
              icon: Icons.add_photo_alternate_rounded,
              title: "Nouveau Rugissement",
              subtitle: "Poste une photo ou une vidéo",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateContentScreen(type: 'POST', user: widget.user),
                  ),
                );
              },
            ),
            _publishOption(
              icon: Icons.history_toggle_off_rounded,
              title: "Statut Flash",
              subtitle: "Visible 24h par tes abonnés",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateContentScreen(type: 'STATUS', user: widget.user),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _publishOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.greenAccent, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: currentFullName);
    final bioController = TextEditingController(text: currentBio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 25,
          right: 25,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "PARAMÈTRES DU STUDIO",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: nameController,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: "NOM COMPLET",
                labelStyle: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: bioController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: const InputDecoration(
                labelText: "BIOGRAPHIE DU LION",
                labelStyle: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 35),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                try {
                  await supabase
                      .from('users')
                      .update({
                        'full_name': nameController.text.trim(),
                        'bio': bioController.text.trim(),
                      })
                      .eq('id', widget.user.id);
                  setState(() {
                    currentFullName = nameController.text.trim();
                    currentBio = bioController.text.trim();
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("🦁 Erreur update profil: $e");
                }
              },
              child: Container(
                height: 55,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    "SAUVEGARDER",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
} // FIN DE LA CLASSE
