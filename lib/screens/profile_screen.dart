import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user.dart';
import '../services/social_service.dart';
import 'messages_screen.dart';
import 'chat_screen.dart';
import 'create_content_screen.dart';
import 'dashboard_screen.dart';
import 'dart:io';
import '../widgets/video_post_player.dart';
import 'home_screen.dart' show SharedCommentsSheet, CommentItem;
// ── Import des écrans de certification depuis settings ──
import 'settings_screen.dart'
    show UploadScreen, UploadCertScreen, UploadCertProScreen;

// ═══════════════════════════════════════════════════════════════
// HELPERS CV
// ═══════════════════════════════════════════════════════════════

String _roleLabel(String r) {
  const m = {
    'supporter': 'Supporter',
    'athlete': 'Athlète',
    'club': 'Club',
    'agent': 'Agent / Recruteur',
    'journaliste': 'Journaliste',
  };
  return m[r] ?? r;
}

String _levelLabel(String? v) {
  const m = {
    'amateur': 'Amateur',
    'semi_pro': 'Semi-Pro',
    'professionnel': 'Professionnel',
    'international': 'International',
  };
  return m[v] ?? (v ?? '—');
}

String _sportLabel(String? v) {
  const m = {
    'football': 'Football',
    'basketball': 'Basketball',
    'handball': 'Handball',
    'athletics': 'Athlétisme',
    'tennis': 'Tennis',
    'volleyball': 'Volleyball',
    'boxing': 'Boxe',
    'mma': 'MMA',
    'karate': 'Karaté',
  };
  return m[v] ?? (v ?? '—');
}

String _positionLabel(String? v) {
  const m = {
    'gardien': 'Gardien',
    'defenseur': 'Défenseur',
    'milieu': 'Milieu',
    'attaquant': 'Attaquant',
    'meneur': 'Meneur',
    'arriere': 'Arrière',
    'ailier': 'Ailier',
    'ailier_fort': 'Ailier Fort',
    'pivot': 'Pivot',
    'passeur': 'Passeur',
    'libero': 'Libéro',
    'central': 'Central',
    'pointu': 'Pointu',
    'recepteur': 'Réceptionneur',
  };
  return m[v] ?? (v ?? '—');
}

String _mediaTypeLabel(String? v) {
  const m = {
    'presse_ecrite': 'Presse écrite',
    'television': 'Télévision',
    'radio': 'Radio',
    'web': 'Web / Blog',
    'podcast': 'Podcast',
    'freelance': 'Freelance',
  };
  return m[v] ?? (v ?? '—');
}

// ═══════════════════════════════════════════════════════════════
// HELPER : navigation vers l'écran de certification selon le rôle
// ═══════════════════════════════════════════════════════════════

void _navigateToCertScreen(BuildContext context, String role) {
  Widget screen;
  switch (role) {
    case 'athlete':
      screen = const UploadCertScreen();
      break;
    case 'club':
    case 'agent':
    case 'journaliste':
      screen = const UploadCertProScreen();
      break;
    default: // supporter
      screen = const UploadScreen();
  }
  HapticFeedback.lightImpact();
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

// ═══════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════

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
  bool _isFirstLoad = true;
  bool _isPostsLoading = true;
  bool _showLikeOverlay = false;
  List<dynamic> _userPosts = [];
  Map<String, dynamic> _profileData = {};
  String? _postFilter;

  // ── REALTIME : channel qui écoute les changements du profil ──
  sb.RealtimeChannel? _profileRealtimeChannel;

  late AnimationController _likeCtrl;
  late Animation<double> _scale, _opacity;
  late Animation<Offset> _moveUp;

  late String currentFullName;
  late String currentUsername;
  late String currentBio;
  String? currentAvatarUrl;
  String? currentCoverUrl;

  @override
  void initState() {
    super.initState();
    _initFromWidget();
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween(
      begin: 0.6,
      end: 1.4,
    ).chain(CurveTween(curve: Curves.elasticOut)).animate(_likeCtrl);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_likeCtrl);
    _moveUp = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.8),
    ).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOutCubic));
    _initProfile();
  }

  void _initFromWidget() {
    currentFullName = widget.user.fullName;
    currentUsername = widget.user.fullName.replaceAll(' ', '_').toLowerCase();
    currentBio = widget.user.bio?.isNotEmpty == true
        ? widget.user.bio!
        : "Rugissement officiel sur la plateforme des Lions. 🦁";
    currentAvatarUrl = widget.user.img_url;
    currentCoverUrl = widget.user.cover_url;
    followersCount = widget.user.followersCount;
    isFollowing = widget.user.isFollowing ?? false;
  }

  Future<void> _initProfile() async {
    await _checkFollowingStatus();
    await _loadUserContent();
    _subscribeToRealtimeProfile(); // ← Realtime activé après le premier chargement
    _socialService.subscribeToPosts(() {
      if (mounted) _loadUserContent(silent: true);
    });
  }

  // ── REALTIME : dès qu'un UPDATE touche la ligne du profil (depuis
  //    SettingsScreen ou ailleurs), l'UI se met à jour instantanément ──
  void _subscribeToRealtimeProfile() {
    _profileRealtimeChannel = supabase
        .channel('profile_rt_${widget.user.id}')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.user.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = payload.newRecord;
            setState(() {
              // Merge : on conserve les clés existantes et on écrase ce qui a changé
              _profileData = {..._profileData, ...updated};

              // Mise à jour des champs affichés en temps réel
              if (updated['full_name'] != null)
                currentFullName = updated['full_name'];
              if (updated['bio'] != null &&
                  (updated['bio'] as String).isNotEmpty)
                currentBio = updated['bio'];
              if (updated['img_url'] != null)
                currentAvatarUrl = updated['img_url'];
              if (updated['cover_url'] != null)
                currentCoverUrl = updated['cover_url'];
              if (updated['followers_count'] != null)
                followersCount = updated['followers_count'];

              // Recalcule le username si le nom change
              currentUsername = currentFullName
                  .replaceAll(' ', '_')
                  .toLowerCase();
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    if (_profileRealtimeChannel != null) {
      supabase.removeChannel(_profileRealtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadUserContent();
  }

  Future<void> _loadUserContent({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isPostsLoading = true);
    try {
      final myId = supabase.auth.currentUser!.id;
      final results = await Future.wait<dynamic>([
        _socialService.fetchPosts(myId, authorId: widget.user.id),
        supabase.from('users').select().eq('id', widget.user.id).single(),
      ]);
      final posts = results[0] as List<dynamic>;
      final userData = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _userPosts = posts;
        _profileData = userData;
        _isPostsLoading = false;
        _isFirstLoad = false;
        currentAvatarUrl = userData['img_url'] ?? currentAvatarUrl;
        currentCoverUrl = userData['cover_url'] ?? currentCoverUrl;
        currentFullName = userData['full_name'] ?? currentFullName;
        currentBio = (userData['bio'] as String?)?.isNotEmpty == true
            ? userData['bio']
            : currentBio;
        followersCount = userData['followers_count'] ?? followersCount;
        currentUsername = currentFullName.replaceAll(' ', '_').toLowerCase();
      });
    } catch (e) {
      debugPrint("🦁 loadUserContent: $e");
      if (mounted) setState(() => _isPostsLoading = false);
    }
  }

  List<dynamic> get _filteredPosts {
    if (_postFilter == null) return _userPosts;
    return _userPosts.where((p) {
      final t = (p['type'] ?? 'TEXT').toString().toUpperCase();
      if (_postFilter == 'IMAGE') return t == 'IMAGE';
      if (_postFilter == 'VIDEO') return t == 'VIDEO';
      return t == 'TEXT';
    }).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _timeAgo(String s) {
    try {
      final d = DateTime.parse(s);
      final diff = DateTime.now().difference(d);
      if (diff.inSeconds < 60) return "À l'instant";
      if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "il y a ${diff.inHours} h";
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    } catch (_) {
      return "Récemment";
    }
  }

  List<String> _getMediaUrls(dynamic post) {
    final raw = post['media_urls'];
    if (raw is List && raw.isNotEmpty)
      return raw.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
    final s = post['media_url']?.toString() ?? '';
    return s.isNotEmpty ? [s] : [];
  }

  String _fmtCount(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  // ── Helper : rôle courant (depuis _profileData si dispo, sinon widget.user) ──
  String get _currentRole =>
      (_profileData['role'] ?? widget.user.role ?? 'supporter').toString();

  // ── Helper : l'user est-il certifié ? ──
  bool get _isCurrentlyCertified =>
      (_profileData['is_certified'] ?? widget.user.isCertified) == true;

  Future<void> _toggleLike(dynamic post) async {
    final bool liked = post['is_liked_by_me'] ?? false;
    setState(() {
      post['is_liked_by_me'] = !liked;
      post['likes_count'] = liked
          ? post['likes_count'] - 1
          : post['likes_count'] + 1;
    });
    try {
      await _socialService.toggleLike(
        post['id'].toString(),
        supabase.auth.currentUser!.id,
      );
    } catch (_) {
      _loadUserContent(silent: true);
    }
  }

  void _handleDoubleTap(dynamic post) {
    if (!(post['is_liked_by_me'] ?? false)) _toggleLike(post);
    HapticFeedback.mediumImpact();
    setState(() => _showLikeOverlay = true);
    _likeCtrl.forward(from: 0);
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showLikeOverlay = false);
    });
  }

  Future<void> _handleRepost(dynamic post) async {
    HapticFeedback.mediumImpact();
    try {
      await _socialService.repost(supabase.auth.currentUser!.id, post);
      await _loadUserContent(silent: true);
    } catch (_) {
      _loadUserContent(silent: true);
    }
  }

  void _showZoomedImage(String url) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Hero(
                tag: url,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
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
      ),
    );
  }

  void _navigateToProfile(dynamic ud) {
    if (ud == null) return;
    final uid = ud['id'] ?? ud['author_id'] ?? '';
    if (uid.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: User(
            id: uid,
            fullName: ud['full_name'] ?? 'Utilisateur',
            email: ud['email'] ?? '',
            role: ud['role'] ?? 'supporter',
            isCertified: ud['is_certified'] ?? false,
            img_url: ud['img_url'],
            bio: ud['bio'],
          ),
        ),
      ),
    ).then((_) => _loadUserContent(silent: true));
  }

  Future<void> _checkFollowingStatus() async {
    try {
      final myId = supabase.auth.currentUser!.id;
      final f = await _socialService.isFollowing(myId, widget.user.id);
      if (mounted) setState(() => isFollowing = f);
    } catch (e) {
      debugPrint("🦁 check follow: $e");
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final picker = ImagePicker();
    try {
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (img == null) return;
      HapticFeedback.mediumImpact();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.greenAccent,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  isCover
                      ? "Mise à jour couverture..."
                      : "Mise à jour photo profil...",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
          ),
        );
      final ok = await _socialService.updateProfileMedia(
        userId: widget.user.id,
        file: File(img.path),
        type: isCover ? 'cover' : 'avatar',
      );
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (ok) {
        await _socialService.createPost(
          userId: widget.user.id,
          content: isCover
              ? "🦁 A mis à jour sa couverture !"
              : "🦁 A mis à jour sa photo de profil !",
          type: 'TEXT',
        );
        await _loadUserContent();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCover
                    ? "Couverture mise à jour ✓"
                    : "Photo de profil mise à jour ✓",
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.greenAccent,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      debugPrint("🦁 pickImage: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Erreur : $e",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isMyProfile = widget.user.id == supabase.auth.currentUser?.id;
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
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      _buildStrategicButtons(),
                      const SizedBox(height: 12),
                      _buildCvSection(),
                      const SizedBox(height: 8),
                      _buildDashboardEntry(context),
                      const SizedBox(height: 8),
                      _buildFilterBar(),
                      _buildContentHeader(),
                    ],
                  ),
                ),
                ..._buildFeedSlivers(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
            if (_showLikeOverlay)
              IgnorePointer(child: Center(child: _buildLikeHeart())),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────────
  Widget _buildAppBar() {
    final coverUrl = (currentCoverUrl?.isNotEmpty ?? false)
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
                tag: 'cover_${widget.user.id}',
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  frameBuilder: (_, child, frame, sync) =>
                      (sync || frame != null)
                      ? child
                      : Container(color: const Color(0xFF1A1A1A)),
                ),
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

  // ─── AVATAR ───────────────────────────────────────────────────
  Widget _buildProfileAvatar() {
    final av = (currentAvatarUrl?.isNotEmpty ?? false) ? currentAvatarUrl! : "";
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
                onTap: av.isNotEmpty ? () => _showZoomedImage(av) : null,
                child: Hero(
                  tag: 'avatar_${widget.user.id}',
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.white10,
                    backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
                    child: av.isEmpty
                        ? FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                currentFullName.isNotEmpty
                                    ? currentFullName[0].toUpperCase()
                                    : "L",
                                style: const TextStyle(
                                  fontSize: 36,
                                  color: Colors.white24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
                padding: const EdgeInsets.all(7),
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
                  size: 15,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── USER INFO ────────────────────────────────────────────────
  // MODIFICATION : badge amber cliquable → écran certification du rôle
  Widget _buildUserInfo() {
    final isMyProfile = supabase.auth.currentUser?.id == widget.user.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  currentFullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),

              // ── BADGE : certifié (bleu fixe) ou non-certifié (amber cliquable) ──
              GestureDetector(
                // Cliquable seulement si NON certifié ET c'est mon profil
                onTap: (!_isCurrentlyCertified && isMyProfile)
                    ? () => _navigateToCertScreen(context, _currentRole)
                    : null,
                child: Tooltip(
                  message: _isCurrentlyCertified
                      ? 'Compte certifié ✓'
                      : 'Appuyer pour certifier votre compte',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: !_isCurrentlyCertified && isMyProfile
                        ? const EdgeInsets.all(5)
                        : EdgeInsets.zero,
                    decoration: !_isCurrentlyCertified && isMyProfile
                        ? BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.4),
                              width: 1.2,
                            ),
                          )
                        : null,
                    child: Icon(
                      _isCurrentlyCertified
                          ? Icons.verified
                          : Icons.stars_rounded,
                      color: _isCurrentlyCertified
                          ? Colors.blueAccent
                          : Colors.amber,
                      size: _isCurrentlyCertified ? 20 : 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "@${currentUsername.toLowerCase()}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // ── Sous le username : petite indication si non-certifié (mon profil) ──
          if (!_isCurrentlyCertified && isMyProfile) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _navigateToCertScreen(context, _currentRole),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Certifier mon compte ${_roleLabel(_currentRole)}",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.amber,
                      size: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          if (!isMyProfile) _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildFollowButton() => GestureDetector(
    onTap: _toggleFollow,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 11),
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
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    ),
  );

  Future<void> _toggleFollow() async {
    final myId = supabase.auth.currentUser?.id;
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
      await _socialService.toggleFollow(myId, widget.user.id);
    } catch (e) {
      if (mounted)
        setState(() {
          isFollowing = !isFollowing;
          isFollowing ? followersCount++ : followersCount--;
        });
    }
  }

  // ─── BIO ──────────────────────────────────────────────────────
  Widget _buildBioSection() {
    final isLong = currentBio.length > 90;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: GestureDetector(
        onTap: isLong ? () => setState(() => isExpanded = !isExpanded) : null,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: isExpanded || !isLong
                      ? currentBio
                      : "${currentBio.substring(0, currentBio.length < 90 ? currentBio.length : 90)}... ",
                ),
                if (isLong)
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

  // ─── STATS ────────────────────────────────────────────────────
  Widget _buildStatsRow() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _statItem(followersCount, "Abonnés")),
        Container(height: 28, width: 1, color: Colors.white10),
        Expanded(child: _statItem(widget.user.followingCount, "Abonnements")),
      ],
    ),
  );

  Widget _statItem(int count, String label) {
    final fmt = count >= 1000
        ? "${(count / 1000).toStringAsFixed(1)}k"
        : "$count";
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            fmt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ─── BOUTONS STRATÉGIQUES ─────────────────────────────────────
  Widget _buildStrategicButtons() {
    final isMyProfile = supabase.auth.currentUser?.id == widget.user.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (isMyProfile) ...[
            Expanded(
              child: _actionBtn(
                "MODIFIER LE PROFIL",
                _showEditProfileDialog,
                const Color(0xFF1A1A1A),
                Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (isMyProfile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessagesScreen(
                      currentUserId: supabase.auth.currentUser!.id,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatName: currentFullName,
                      targetId: widget.user.id,
                      currentUserId: supabase.auth.currentUser!.id,
                      isGroup: false,
                    ),
                  ),
                );
              }
            },
            child: Container(
              height: 48,
              width: isMyProfile ? 50 : null,
              padding: isMyProfile
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isMyProfile
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF3CFF7E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isMyProfile
                      ? Colors.white10
                      : const Color(0xFF3CFF7E).withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      color: isMyProfile
                          ? Colors.white
                          : const Color(0xFF3CFF7E),
                      size: 19,
                    ),
                    if (!isMyProfile) ...[
                      const SizedBox(width: 8),
                      const Text(
                        "MESSAGE",
                        style: TextStyle(
                          color: Color(0xFF3CFF7E),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, Color bg, Color fg) =>
      GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      );

  // ─── DASHBOARD ────────────────────────────────────────────────
  Widget _buildDashboardEntry(BuildContext context) {
    if (supabase.auth.currentUser?.id != widget.user.id)
      return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Colors.amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tableau de bord professionnel",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Analysez la portée de vos rugissements",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─── FILTRE POSTS ─────────────────────────────────────────────
  Widget _buildFilterBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(
      children: [
        _filterChip(null, Icons.grid_view_rounded, "Tous"),
        const SizedBox(width: 8),
        _filterChip('TEXT', Icons.text_fields_rounded, "Texte"),
        const SizedBox(width: 8),
        _filterChip('IMAGE', Icons.image_rounded, "Photos"),
        const SizedBox(width: 8),
        _filterChip('VIDEO', Icons.play_circle_outline_rounded, "Vidéos"),
      ],
    ),
  );

  Widget _filterChip(String? type, IconData icon, String label) {
    final isActive = _postFilter == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _postFilter = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF3CFF7E).withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF3CFF7E).withOpacity(0.5)
                : Colors.white.withOpacity(0.07),
            width: isActive ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? const Color(0xFF3CFF7E) : Colors.white38,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF3CFF7E) : Colors.white38,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER PUBLICATIONS ──────────────────────────────────────
  Widget _buildContentHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_mosaic_rounded,
          color: Colors.greenAccent,
          size: 16,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            "PUBLICATIONS STUDIO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            "${_filteredPosts.length} POSTS",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  // ─── FEED ─────────────────────────────────────────────────────
  List<Widget> _buildFeedSlivers() {
    if (_isFirstLoad && _isPostsLoading)
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ];
    final posts = _filteredPosts;
    if (posts.isEmpty)
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 50),
              Icon(
                Icons.layers_clear_rounded,
                color: Colors.white.withOpacity(0.05),
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                _postFilter == null
                    ? "Aucun rugissement dans le studio"
                    : "Aucun contenu de ce type",
                style: const TextStyle(color: Colors.white24, fontSize: 13),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ];
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              RepaintBoundary(child: _buildFeedItem(post: posts[i])),
          childCount: posts.length,
        ),
      ),
    ];
  }

  Widget _buildFeedItem({required dynamic post}) {
    final postType = (post['type'] ?? 'TEXT').toString().toUpperCase();
    final mediaUrls = _getMediaUrls(post);
    final content = post['content']?.toString() ?? '';
    final isLiked = post['is_liked_by_me'] ?? false;
    final likesCount = post['likes_count'] ?? 0;
    final commCount = post['comments_count'] ?? 0;
    final repostsCount = post['reposts_count'] ?? 0;
    final createdAt = post['created_at']?.toString() ?? '';
    final isRepost = post['is_repost'] ?? false;
    final origAuthor = post['original_author_name'] ?? "";
    final origImg = post['original_author_img'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost)
            GestureDetector(
              onTap: () => _navigateToProfile({
                'full_name': origAuthor,
                'img_url': origImg,
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, left: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3CFF7E).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.repeat_rounded,
                        color: Color(0xFF3CFF7E),
                        size: 11,
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (origImg != null && origImg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: CircleAvatar(
                          radius: 9,
                          backgroundImage: NetworkImage(origImg),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        "Republié par $origAuthor",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onDoubleTap: () => _handleDoubleTap(post),
            child: postType == 'TEXT' || mediaUrls.isEmpty
                ? _buildTextCard(
                    post: post,
                    content: content,
                    createdAt: createdAt,
                    isLiked: isLiked,
                    likes: likesCount,
                    comments: commCount,
                    reposts: repostsCount,
                  )
                : _buildMediaCard(
                    post: post,
                    urls: mediaUrls,
                    postType: postType,
                    content: content,
                    createdAt: createdAt,
                    isLiked: isLiked,
                    likes: likesCount,
                    comments: commCount,
                    reposts: repostsCount,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard({
    required dynamic post,
    required String content,
    required String createdAt,
    required bool isLiked,
    required int likes,
    required int comments,
    required int reposts,
  }) => _ExpandablePostCard(
    post: post,
    content: content,
    isLiked: isLiked,
    likes: likes,
    comments: comments,
    reposts: reposts,
    header: _postHeader(createdAt: createdAt, post: post),
    actions: _postActions(
      post: post,
      isLiked: isLiked,
      likes: likes,
      comments: comments,
      reposts: reposts,
      dark: false,
    ),
    richText: _richText,
  );

  Widget _buildMediaCard({
    required dynamic post,
    required List<String> urls,
    required String postType,
    required String content,
    required String createdAt,
    required bool isLiked,
    required int likes,
    required int comments,
    required int reposts,
  }) => _ProfileMediaPostCard(
    post: post,
    mediaUrls: urls,
    postType: postType,
    content: content,
    authorName: currentFullName,
    authorImg: currentAvatarUrl,
    isAuthorCertified: _isCurrentlyCertified,
    createdAt: createdAt,
    isLiked: isLiked,
    likesCount: likes,
    commentsCount: comments,
    repostsCount: reposts,
    timeAgo: _timeAgo,
    onImageTap: _showZoomedImage,
    onLike: () => _toggleLike(post),
    onComment: () => _showCommentsModal(post),
    onRepost: () => _handleRepost(post),
    onOptions: () => _showPostOptions(post),
  );

  Widget _postHeader({required String createdAt, required dynamic post}) => Row(
    children: [
      GestureDetector(
        onTap: () => _navigateToProfile({
          'id': widget.user.id,
          'full_name': currentFullName,
          'img_url': currentAvatarUrl,
          'is_certified': _isCurrentlyCertified,
        }),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [Colors.green, Colors.red, Colors.yellow, Colors.green],
            ),
          ),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: Colors.black,
            backgroundImage: (currentAvatarUrl?.isNotEmpty ?? false)
                ? NetworkImage(currentAvatarUrl!)
                : null,
            child: (currentAvatarUrl?.isEmpty ?? true)
                ? Text(
                    currentFullName.isNotEmpty
                        ? currentFullName[0].toUpperCase()
                        : "L",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: GestureDetector(
          onTap: () => _navigateToProfile({
            'id': widget.user.id,
            'full_name': currentFullName,
            'img_url': currentAvatarUrl,
            'is_certified': _isCurrentlyCertified,
          }),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isCurrentlyCertified
                        ? Icons.verified
                        : Icons.stars_rounded,
                    color: _isCurrentlyCertified
                        ? Colors.blueAccent
                        : Colors.amber,
                    size: 12,
                  ),
                ],
              ),
              Text(
                _timeAgo(createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
      GestureDetector(
        onTap: () => _showPostOptions(post),
        child: const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Icon(Icons.more_horiz, color: Colors.white54, size: 20),
        ),
      ),
    ],
  );

  Widget _richText(String content) {
    final words = content.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final isLast = i == words.length - 1;
      if (w.startsWith('#') || w.startsWith('@')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: TextStyle(
              color: w.startsWith('#')
                  ? const Color(0xFF3CFF7E)
                  : Colors.blueAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }

  Widget _postActions({
    required dynamic post,
    required bool isLiked,
    required int likes,
    required int comments,
    required int reposts,
    required bool dark,
  }) {
    final views = post['views_count'] ?? 0;
    return Row(
      children: [
        _pill(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          _fmtCount(likes),
          isLiked ? Colors.red : Colors.white,
          () => _toggleLike(post),
          dark,
        ),
        const SizedBox(width: 7),
        _pill(
          Icons.chat_bubble_outline_rounded,
          _fmtCount(comments),
          Colors.white,
          () => _showCommentsModal(post),
          dark,
        ),
        const SizedBox(width: 7),
        _pill(
          Icons.repeat_rounded,
          _fmtCount(reposts),
          reposts > 0 ? const Color(0xFF3CFF7E) : Colors.white,
          () => _handleRepost(post),
          dark,
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              size: 13,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 4),
            Text(
              _fmtCount(views),
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
    bool dark,
  ) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.10)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          if (label != '0') ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildFAB() => Padding(
    padding: const EdgeInsets.only(bottom: 10, right: 5),
    child: FloatingActionButton(
      backgroundColor: Colors.greenAccent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () => _showPublishMenu(context),
      child: const Icon(Icons.add_rounded, color: Colors.black, size: 32),
    ),
  );

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
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.green, Colors.red, Colors.yellow],
                stops: [0.33, 0.33, 0.66],
              ).createShader(b),
              child: const Icon(Icons.favorite, color: Colors.white, size: 130),
            ),
            const Positioned(
              top: 48,
              child: Icon(Icons.star, color: Colors.yellow, size: 36),
            ),
          ],
        ),
      ),
    ),
  );

  // ─── MODALS ───────────────────────────────────────────────────
  void _showCommentsModal(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => SharedCommentsSheet(
        post: post,
        socialService: _socialService,
        currentUserId: supabase.auth.currentUser!.id,
        currentUserImg: currentAvatarUrl,
        currentUserName: currentFullName,
        onCommentAdded: () => _loadUserContent(silent: true),
        onNavigateToProfile: _navigateToProfile,
      ),
    );
  }

  void _showPostOptions(dynamic post) {
    final isMine = post['author_id'] == supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "Supprimer ce post",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  await _socialService.deletePost(post['id']);
                  Navigator.pop(context);
                  _handleRefresh();
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white70),
                title: const Text(
                  "Signaler le contenu",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_flipped,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  "Bloquer l'utilisateur",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPublishMenu(BuildContext ctx) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 28,
          top: 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "CRÉATION STUDIO",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 26),
            _pubOption(
              Icons.add_photo_alternate_rounded,
              "Nouveau Rugissement",
              "Photo ou vidéo",
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateContentScreen(type: 'POST', user: widget.user),
                  ),
                );
              },
            ),
            _pubOption(
              Icons.history_toggle_off_rounded,
              "Statut Flash",
              "Visible 24h",
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
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

  Widget _pubOption(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
    leading: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Colors.greenAccent, size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
    subtitle: Text(
      sub,
      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
    ),
    onTap: onTap,
  );

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: currentFullName);
    final bioCtrl = TextEditingController(text: currentBio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "PARAMÈTRES DU STUDIO",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: nameCtrl,
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
            const SizedBox(height: 16),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                try {
                  // La mise à jour déclenche Realtime → l'UI se met à jour automatiquement
                  await supabase
                      .from('users')
                      .update({
                        'full_name': nameCtrl.text.trim(),
                        'bio': bioCtrl.text.trim(),
                      })
                      .eq('id', widget.user.id);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  debugPrint("🦁 update profil: $e");
                }
              },
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // CV SECTION
  // MODIFICATION : badge "CERTIFIER" amber cliquable dans le header
  // ═════════════════════════════════════════════════════════════

  Widget _buildCvSection() {
    if (_profileData.isEmpty) return const SizedBox.shrink();
    final role = _currentRole;
    final isMyProfile = supabase.auth.currentUser?.id == widget.user.id;
    if (!_hasCvData(role) && !isMyProfile) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3CFF7E).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF3CFF7E),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "PROFIL ${_roleLabel(role).toUpperCase()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.6,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ── BADGE CERTIFICATION dans le header CV ──
                if (_isCurrentlyCertified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.blueAccent,
                          size: 10,
                        ),
                        SizedBox(width: 3),
                        Text(
                          "CERTIFIÉ",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  )
                // ── Badge amber cliquable pour les non-certifiés (mon profil) ──
                else if (isMyProfile)
                  GestureDetector(
                    onTap: () => _navigateToCertScreen(context, role),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            color: Colors.amber,
                            size: 10,
                          ),
                          SizedBox(width: 3),
                          Text(
                            "CERTIFIER",
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: Colors.white.withOpacity(0.06), height: 22),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _buildCvBody(role),
          ),
        ],
      ),
    );
  }

  bool _hasCvData(String role) {
    final d = _profileData;
    switch (role) {
      case 'athlete':
        return [
          d['sport'],
          d['level'],
          d['current_club'],
          d['position'],
          d['experience'],
          d['city'],
          d['achievements'],
        ].any((v) => v != null && v.toString().isNotEmpty);
      case 'club':
        return [
          d['club_name'],
          d['league'],
          d['stadium'],
          d['founded_year'],
        ].any((v) => v != null && v.toString().isNotEmpty);
      case 'agent':
        return [
          d['agency_name'],
          d['markets'],
          d['nb_players'],
        ].any((v) => v != null && v.toString().isNotEmpty);
      case 'journaliste':
        return [
          d['media_name'],
          d['media_type'],
          d['press_card'],
        ].any((v) => v != null && v.toString().isNotEmpty);
      case 'supporter':
        return [
          d['favorite_club'],
          d['supporter_since'],
          d['sport'],
        ].any((v) => v != null && v.toString().isNotEmpty);
      default:
        return false;
    }
  }

  Widget _buildCvBody(String role) {
    switch (role) {
      case 'athlete':
        return _cvAthlete();
      case 'club':
        return _cvClub();
      case 'agent':
        return _cvAgent();
      case 'journaliste':
        return _cvJournaliste();
      case 'supporter':
        return _cvSupporter();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _cvAthlete() {
    final d = _profileData;
    final sport = d['sport']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (sport.isNotEmpty) _sportChip(sport),
            if (d['level'] != null)
              _levelChip(_levelLabel(d['level']?.toString())),
          ],
        ),
        const SizedBox(height: 14),
        _cvGrid([
          if (d['position'] != null)
            _CvItem(
              icon: Icons.place_rounded,
              label: 'Poste',
              value: _positionLabel(d['position']?.toString()),
            ),
          if (d['current_club'] != null)
            _CvItem(
              icon: Icons.shield_outlined,
              label: 'Club',
              value: d['current_club'].toString(),
            ),
          if (d['experience'] != null)
            _CvItem(
              icon: Icons.timeline_rounded,
              label: 'Expérience',
              value: '${d['experience']} ans',
            ),
          if (d['city'] != null)
            _CvItem(
              icon: Icons.location_on_outlined,
              label: 'Ville',
              value:
                  '${d['city']}${d['country'] != null ? ', ${d['country']}' : ''}',
            ),
          if (d['height_cm'] != null)
            _CvItem(
              icon: Icons.height_rounded,
              label: 'Taille',
              value: '${d['height_cm']} cm',
            ),
          if (d['strong_foot'] != null)
            _CvItem(
              icon: Icons.sports_soccer,
              label: 'Pied fort',
              value: d['strong_foot'].toString().replaceAll('_', ' '),
            ),
          if (d['dominant_hand'] != null)
            _CvItem(
              icon: Icons.back_hand_outlined,
              label: 'Main',
              value: d['dominant_hand'].toString(),
            ),
          if (d['ranking'] != null)
            _CvItem(
              icon: Icons.leaderboard_outlined,
              label: 'Classement',
              value: '#${d['ranking']} nat.',
            ),
          if (d['weight_class'] != null)
            _CvItem(
              icon: Icons.monitor_weight_outlined,
              label: 'Catégorie',
              value: d['weight_class'].toString(),
            ),
          if (d['record'] != null)
            _CvItem(
              icon: Icons.scoreboard_outlined,
              label: 'Record',
              value: d['record'].toString(),
            ),
          if (d['gym'] != null)
            _CvItem(
              icon: Icons.fitness_center_outlined,
              label: 'Gym',
              value: d['gym'].toString(),
            ),
          if (d['discipline'] != null)
            _CvItem(
              icon: Icons.directions_run,
              label: 'Discipline',
              value: d['discipline'].toString(),
            ),
          if (d['best_perf'] != null)
            _CvItem(
              icon: Icons.timer_outlined,
              label: 'Meilleure perf',
              value: d['best_perf'].toString(),
            ),
          if (d['grade'] != null)
            _CvItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Ceinture',
              value: d['grade'].toString(),
            ),
          if (d['dojo'] != null)
            _CvItem(
              icon: Icons.house_outlined,
              label: 'Dojo',
              value: d['dojo'].toString(),
            ),
        ]),
        if (d['achievements'] != null &&
            d['achievements'].toString().isNotEmpty)
          _achievementsBlock(d['achievements'].toString()),
      ],
    );
  }

  Widget _cvClub() {
    final d = _profileData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d['sport'] != null) _sportChip(d['sport'].toString()),
        const SizedBox(height: 14),
        _cvGrid([
          if (d['club_name'] != null)
            _CvItem(
              icon: Icons.shield_rounded,
              label: 'Nom officiel',
              value: d['club_name'].toString(),
            ),
          if (d['league'] != null)
            _CvItem(
              icon: Icons.emoji_events_outlined,
              label: 'Championnat',
              value: d['league'].toString(),
            ),
          if (d['founded_year'] != null)
            _CvItem(
              icon: Icons.calendar_today_outlined,
              label: 'Fondé en',
              value: d['founded_year'].toString(),
            ),
          if (d['stadium'] != null)
            _CvItem(
              icon: Icons.stadium_outlined,
              label: 'Stade / Salle',
              value: d['stadium'].toString(),
            ),
          if (d['city'] != null)
            _CvItem(
              icon: Icons.location_on_outlined,
              label: 'Ville',
              value: d['city'].toString(),
            ),
          if (d['website'] != null)
            _CvItem(
              icon: Icons.language_outlined,
              label: 'Site web',
              value: d['website'].toString(),
            ),
        ]),
        if (d['achievements'] != null &&
            d['achievements'].toString().isNotEmpty)
          _achievementsBlock(d['achievements'].toString()),
      ],
    );
  }

  Widget _cvAgent() {
    final d = _profileData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d['sport'] != null) _sportChip(d['sport'].toString()),
        const SizedBox(height: 14),
        _cvGrid([
          if (d['agency_name'] != null)
            _CvItem(
              icon: Icons.business_outlined,
              label: 'Agence',
              value: d['agency_name'].toString(),
            ),
          if (d['license_number'] != null)
            _CvItem(
              icon: Icons.badge_outlined,
              label: 'Licence',
              value: d['license_number'].toString(),
            ),
          if (d['experience'] != null)
            _CvItem(
              icon: Icons.timeline_rounded,
              label: 'Expérience',
              value: '${d['experience']} ans',
            ),
          if (d['nb_players'] != null)
            _CvItem(
              icon: Icons.people_outline,
              label: 'Athlètes',
              value: '${d['nb_players']}',
            ),
          if (d['city'] != null)
            _CvItem(
              icon: Icons.location_on_outlined,
              label: 'Localisation',
              value: d['city'].toString(),
            ),
        ]),
        if (d['markets'] != null && d['markets'].toString().isNotEmpty)
          _infoBlock(
            Icons.public_outlined,
            'Marchés couverts',
            d['markets'].toString(),
          ),
        if (d['bio'] != null && d['bio'].toString().isNotEmpty)
          _infoBlock(Icons.info_outline, 'Présentation', d['bio'].toString()),
      ],
    );
  }

  Widget _cvJournaliste() {
    final d = _profileData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d['sport'] != null) _sportChip(d['sport'].toString()),
        const SizedBox(height: 14),
        _cvGrid([
          if (d['media_name'] != null)
            _CvItem(
              icon: Icons.newspaper_outlined,
              label: 'Média',
              value: d['media_name'].toString(),
            ),
          if (d['media_type'] != null)
            _CvItem(
              icon: Icons.tv_outlined,
              label: 'Type',
              value: _mediaTypeLabel(d['media_type']?.toString()),
            ),
          if (d['experience'] != null)
            _CvItem(
              icon: Icons.timeline_rounded,
              label: 'Expérience',
              value: '${d['experience']} ans',
            ),
          if (d['press_card'] != null)
            _CvItem(
              icon: Icons.badge_outlined,
              label: 'Carte presse',
              value: d['press_card'].toString(),
            ),
          if (d['city'] != null)
            _CvItem(
              icon: Icons.location_on_outlined,
              label: 'Localisation',
              value: d['city'].toString(),
            ),
        ]),
        if (d['bio'] != null && d['bio'].toString().isNotEmpty)
          _infoBlock(Icons.info_outline, 'Biographie', d['bio'].toString()),
      ],
    );
  }

  Widget _cvSupporter() {
    final d = _profileData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d['sport'] != null) _sportChip(d['sport'].toString()),
        const SizedBox(height: 14),
        _cvGrid([
          if (d['favorite_club'] != null)
            _CvItem(
              icon: Icons.favorite_outline,
              label: 'Club de cœur',
              value: d['favorite_club'].toString(),
            ),
          if (d['supporter_since'] != null)
            _CvItem(
              icon: Icons.calendar_today_outlined,
              label: 'Supporter depuis',
              value: d['supporter_since'].toString(),
            ),
          if (d['city'] != null)
            _CvItem(
              icon: Icons.location_on_outlined,
              label: 'Localisation',
              value: d['city'].toString(),
            ),
        ]),
        if (d['bio'] != null && d['bio'].toString().isNotEmpty)
          _infoBlock(Icons.info_outline, 'Présentation', d['bio'].toString()),
      ],
    );
  }

  // ─── Widgets CV ───────────────────────────────────────────────
  Widget _sportChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF3CFF7E).withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF3CFF7E).withOpacity(0.22)),
    ),
    child: Text(
      _sportLabel(s).toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF3CFF7E),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
      ),
    ),
  );

  Widget _levelChip(String l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.amber.withOpacity(0.22)),
    ),
    child: Text(
      l.toUpperCase(),
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _cvGrid(List<_CvItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: w > 320 ? 2.5 : 2.0,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _cvCell(items[i]),
        );
      },
    );
  }

  Widget _cvCell(_CvItem item) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(
      children: [
        Icon(item.icon, color: Colors.white38, size: 13),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _achievementsBlock(String text) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber.withOpacity(0.14)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 14),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PALMARÈS",
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.65),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _infoBlock(IconData icon, String label, String text) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// CARTE POST TEXTE AVEC "VOIR PLUS" ET VUES
// ════════════════════════════════════════════════════════════════

class _ExpandablePostCard extends StatefulWidget {
  final dynamic post;
  final String content;
  final bool isLiked;
  final int likes, comments, reposts;
  final Widget header;
  final Widget actions;
  final Widget Function(String) richText;

  const _ExpandablePostCard({
    required this.post,
    required this.content,
    required this.isLiked,
    required this.likes,
    required this.comments,
    required this.reposts,
    required this.header,
    required this.actions,
    required this.richText,
  });

  @override
  State<_ExpandablePostCard> createState() => _ExpandablePostCardState();
}

class _ExpandablePostCardState extends State<_ExpandablePostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasLongText = widget.content.length > 120;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre gradient top
          Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3CFF7E), Color(0xFF00C8FF)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header auteur
                widget.header,
                if (widget.content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Texte 2 lignes max + voir plus
                  GestureDetector(
                    onTap: hasLongText
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRichText(
                          widget.content,
                          maxLines: _expanded ? null : 2,
                        ),
                        if (hasLongText && !_expanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            "voir plus",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (hasLongText && _expanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            "voir moins",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          // Actions + vues
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: widget.actions,
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String content, {int? maxLines}) {
    final words = content.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final isLast = i == words.length - 1;
      if (w.startsWith('#') || w.startsWith('@')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: TextStyle(
              color: w.startsWith('#')
                  ? const Color(0xFF3CFF7E)
                  : Colors.blueAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }
}

// ─── Modèle CV ────────────────────────────────────────────────────
class _CvItem {
  final IconData icon;
  final String label, value;
  const _CvItem({required this.icon, required this.label, required this.value});
}

// ═══════════════════════════════════════════════════════════════
// CAROUSEL MÉDIA
// ═══════════════════════════════════════════════════════════════

class _ProfileMediaPostCard extends StatefulWidget {
  final dynamic post;
  final List<String> mediaUrls;
  final String postType, content, createdAt, authorName;
  final String? authorImg;
  final bool isAuthorCertified, isLiked;
  final int likesCount, commentsCount, repostsCount;
  final String Function(String) timeAgo;
  final Function(String) onImageTap;
  final VoidCallback onLike, onComment, onRepost, onOptions;

  const _ProfileMediaPostCard({
    required this.post,
    required this.mediaUrls,
    required this.postType,
    required this.content,
    required this.authorName,
    this.authorImg,
    required this.isAuthorCertified,
    required this.createdAt,
    required this.isLiked,
    required this.likesCount,
    required this.commentsCount,
    required this.repostsCount,
    required this.timeAgo,
    required this.onImageTap,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onOptions,
  });

  @override
  State<_ProfileMediaPostCard> createState() => _ProfileMediaPostCardState();
}

class _ProfileMediaPostCardState extends State<_ProfileMediaPostCard> {
  final PageController _pg = PageController();
  int _cur = 0;
  bool _playing = false;
  bool _textExpanded = false;

  @override
  void dispose() {
    _pg.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _richText(String content, {int? maxLines}) {
    final words = content.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final isLast = i == words.length - 1;
      if (w.startsWith('#') || w.startsWith('@')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: TextStyle(
              color: w.startsWith('#')
                  ? const Color(0xFF3CFF7E)
                  : Colors.blueAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.mediaUrls.length;
    final views = widget.post['views_count'] ?? 0;
    final hasLong = widget.content.length > 120;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barre gradient top ──
          Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3CFF7E), Color(0xFF00C8FF)],
              ),
            ),
          ),

          // ── Header (avatar + nom + badge + date + menu) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.green,
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.black,
                    backgroundImage: (widget.authorImg?.isNotEmpty ?? false)
                        ? NetworkImage(widget.authorImg!)
                        : null,
                    child: (widget.authorImg?.isEmpty ?? true)
                        ? Text(
                            widget.authorName.isNotEmpty
                                ? widget.authorName[0].toUpperCase()
                                : 'L',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.authorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            widget.isAuthorCertified
                                ? Icons.verified
                                : Icons.stars_rounded,
                            color: widget.isAuthorCertified
                                ? Colors.blueAccent
                                : Colors.amber,
                            size: 12,
                          ),
                        ],
                      ),
                      Text(
                        widget.timeAgo(widget.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onOptions,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.more_horiz,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Texte PROPRE au-dessus de l'image ──
          if (widget.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: GestureDetector(
                onTap: hasLong
                    ? () => setState(() => _textExpanded = !_textExpanded)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _richText(
                      widget.content,
                      maxLines: _textExpanded ? null : 2,
                    ),
                    if (hasLong) ...[
                      const SizedBox(height: 4),
                      Text(
                        _textExpanded ? 'voir moins' : 'voir plus',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 10),

          // ── Media (image/vidéo/carousel) ──
          SizedBox(
            height: 300,
            child: widget.postType == 'VIDEO'
                ? (_playing
                      ? VideoPostPlayer(videoUrl: widget.mediaUrls[0])
                      : GestureDetector(
                          onTap: () => setState(() => _playing = true),
                          child: Container(
                            color: Colors.black,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Appuyer pour lire',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ))
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _pg,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _cur = i),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => widget.onImageTap(widget.mediaUrls[i]),
                          child: Image.network(
                            widget.mediaUrls[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (_, child, p) => p == null
                                ? child
                                : Container(
                                    color: const Color(0xFF1A1A1A),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF3CFF7E),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1A1A1A),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white24,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Compteur
                      if (total > 1)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.60),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3CFF7E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_cur + 1} / $total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Nav prev
                      if (total > 1 && _cur > 0)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _pg.previousPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Nav next
                      if (total > 1 && _cur < total - 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _pg.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Dots
                      if (total > 1 && total <= 10)
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(total, (i) {
                              final on = i == _cur;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: on ? 16 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: on
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.32),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
          ),

          // ── Thumbnail strip ──
          if (total > 1 && widget.postType != 'VIDEO') _strip(total),

          // ── Divider ──
          Divider(color: Colors.white.withOpacity(0.06), height: 1),

          // ── Actions bar : [❤️][💬][🔁] ··· [👁 vues] ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                _p(
                  widget.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  _fmt(widget.likesCount),
                  widget.isLiked ? Colors.red : Colors.white,
                  widget.onLike,
                ),
                const SizedBox(width: 7),
                _p(
                  Icons.chat_bubble_outline_rounded,
                  _fmt(widget.commentsCount),
                  Colors.white,
                  widget.onComment,
                ),
                const SizedBox(width: 7),
                _p(
                  Icons.repeat_rounded,
                  _fmt(widget.repostsCount),
                  widget.repostsCount > 0
                      ? const Color(0xFF3CFF7E)
                      : Colors.white,
                  widget.onRepost,
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 13,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(views),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _p(IconData icon, String label, Color c, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c, size: 15),
              if (label != '0') ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _strip(int total) {
    const max = 5;
    final show = total > max ? max - 1 : total;
    final over = total > max ? total - show : 0;
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: [
          ...List.generate(show, (i) {
            final on = i == _cur;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _pg.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 5),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: on
                        ? Colors.white.withOpacity(0.72)
                        : Colors.white.withOpacity(0.11),
                    width: on ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  widget.mediaUrls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1A1A1A)),
                ),
              ),
            );
          }),
          if (over > 0)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white.withOpacity(0.09)),
              ),
              child: Center(
                child: Text(
                  '+$over',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
