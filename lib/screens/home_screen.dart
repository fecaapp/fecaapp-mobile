import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:ui' as java_ui;
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../services/social_service.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'museum_screen.dart';
import 'local_league_screen.dart';
import 'avis_screen.dart';
import 'talents_screen.dart';
import 'tickets_premium_screen.dart';
import 'settings_screen.dart';
import 'premium_subscription_screen.dart';
import 'standings_screen.dart';
import 'create_content_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'finance_education_screen.dart';
import 'saga_kings_screen.dart';
import '../widgets/video_post_player.dart';
import 'fecaai_screen.dart';

// ═══════════════════════════════════════════════════════════════
// MODÈLE COMMENTAIRE (partagé Home + Profile)
// ═══════════════════════════════════════════════════════════════

class CommentItem {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorImg;
  final bool isCertified;
  final String content;
  final DateTime createdAt;
  int likesCount;
  bool isLikedByMe;
  bool showReplies;
  bool showReplyBox;
  List<CommentItem> replies;

  CommentItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorImg,
    this.isCertified = false,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.showReplies = false,
    this.showReplyBox = false,
    this.replies = const [],
  });

  factory CommentItem.fromMap(Map<String, dynamic> m) {
    return CommentItem(
      id: m['id']?.toString() ?? '',
      authorId: m['author_id'] ?? '',
      authorName: m['author_name'] ?? 'Lion anonyme',
      authorImg: m['author_img_url'],
      isCertified: m['is_certified'] == true,
      content: m['content'] ?? '',
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      likesCount: m['likes_count'] ?? 0,
      isLikedByMe: m['is_liked_by_me'] ?? false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final SocialService _socialService = SocialService();
  final Color goldColor = const Color(0xFFD4AF37);

  List<dynamic> _posts = [];
  List<dynamic> _groupedStatuses = [];
  bool _isLoading = true;
  int _currentBottomIndex = 0;

  bool _isBottomBarVisible = true;
  bool _showLikeOverlay = false;
  int _unreadCount = 0;
  RealtimeChannel? _unreadChannel;
  late AnimationController _likeController;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _moveUp;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
    _listenUnread();

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isBottomBarVisible) setState(() => _isBottomBarVisible = false);
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_isBottomBarVisible) setState(() => _isBottomBarVisible = true);
      }
    });

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
  }

  void _setupRealtime() {
    _socialService.subscribeToPosts(() {
      if (mounted) _loadData();
    });
  }

  void _listenUnread() {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    _fetchUnreadCount();
    _unreadChannel = supabase.channel('home_unread_$myId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final msg = payload.newRecord;
          if (msg['receiver_id'] == myId && msg['is_read'] == false) {
            if (mounted) setState(() => _unreadCount++);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          if (payload.newRecord['is_read'] == true &&
              payload.oldRecord['is_read'] == false) {
            _fetchUnreadCount();
          }
        },
      ).subscribe();
  }

  Future<void> _fetchUnreadCount() async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final response = await supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', myId)
          .eq('is_read', false)
          .isFilter('group_id', null);
      if (mounted) setState(() => _unreadCount = (response as List).length);
    } catch (e) {
      debugPrint('Erreur unread: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _socialService.fetchPosts(widget.user.id),
        _socialService.fetchStatuses(widget.user.id),
      ]);
      if (mounted) {
        final allStatuses = results[1];
        final Map<String, dynamic> uniqueUsers = {};
        for (var s in allStatuses) {
          final userId = s['author_id'] ?? s['user_id'];
          if (userId != null && !uniqueUsers.containsKey(userId)) {
            uniqueUsers[userId] = s;
          }
        }
        setState(() {
          _posts = results[0];
          _groupedStatuses = uniqueUsers.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String dateTimeStr) {
    try {
      final postDate = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(postDate);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
      return '${postDate.day}/${postDate.month}/${postDate.year}';
    } catch (e) {
      return 'Récemment';
    }
  }

  List<String> _getMediaUrls(dynamic post) {
    final raw = post['media_urls'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
    }
    final single = post['media_url']?.toString() ?? '';
    if (single.isNotEmpty) return [single];
    return [];
  }

  String _formatCount(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _likeController.dispose();
    if (_unreadChannel != null) {
      Supabase.instance.client.removeChannel(_unreadChannel!);
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _toggleLike(dynamic post) async {
    final bool isLiked = post['is_liked_by_me'] ?? false;
    setState(() {
      post['is_liked_by_me'] = !isLiked;
      post['likes_count'] = isLiked
          ? post['likes_count'] - 1
          : post['likes_count'] + 1;
    });
    try {
      await _socialService.toggleLike(post['id'].toString(), widget.user.id);
    } catch (e) {
      _loadData();
    }
  }

  Future<void> _handleRepost(dynamic post) async {
    HapticFeedback.mediumImpact();
    try {
      await _socialService.repost(widget.user.id, post);
      await _loadData();
    } catch (e) {
      _loadData();
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

  void _showZoomedImage(String imageUrl) {
    if (imageUrl.isEmpty) return;
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
                tag: imageUrl,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
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

  void _navigateToProfile(dynamic userData) {
    if (userData == null) return;
    final userId = userData['id'] ?? userData['author_id'] ?? '';
    if (userId.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: User(
            id: userId,
            fullName: userData['full_name'] ?? 'Utilisateur',
            email: userData['email'] ?? '',
            role: userData['role'] ?? 'USER',
            isCertified: userData['is_certified'] ?? false,
            img_url: userData['img_url'],
            bio: userData['bio'],
          ),
        ),
      ),
    ).then((_) => _loadData());
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.menu_open_rounded,
            color: Colors.greenAccent,
            size: 28,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text(
        'FECAAPP',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: 3,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesScreen(currentUserId: widget.user.id),
            ),
          ).then((_) => _fetchUnreadCount()),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(
                      color: _unreadCount > 0
                          ? const Color(0xFF3CFF7E).withOpacity(0.35)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Icon(
                    _unreadCount > 0
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    color: _unreadCount > 0
                        ? const Color(0xFF3CFF7E)
                        : Colors.white60,
                    size: 22,
                  ),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(user: widget.user),
            ),
          ).then((_) => _loadData()),
          child: Padding(
            padding: const EdgeInsets.only(right: 15, left: 8),
            child: Container(
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
                backgroundImage: (widget.user.img_url?.isNotEmpty ?? false)
                    ? NetworkImage(widget.user.img_url!)
                    : null,
                child: (widget.user.img_url?.isEmpty ?? true)
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DRAWER
  // ─────────────────────────────────────────────────────────────

  Widget _buildDrawerHeader() {
    final bool isCertified = widget.user.isCertified;
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 25),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.3),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset('assets/logo_fecaapp.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isCertified ? Icons.verified : Icons.stars_rounded,
                color: isCertified ? Colors.blueAccent : Colors.amber,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.role.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _drawerTile(
            Icons.person_outline_rounded,
            'Mon Profil',
            Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(user: widget.user),
                ),
              ).then((_) => _loadData());
            },
          ),
          _drawerTile(
            Icons.smart_toy_outlined,
            'FecaAI',
            Colors.greenAccent,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FecaAIScreen()),
              );
            },
          ),
          _drawerTile(
            Icons.account_balance_outlined,
            'Musée du Foot',
            Colors.orangeAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MuseumScreen()),
              );
            },
          ),
          _drawerTile(
            Icons.history_edu_rounded,
            'Saga des Rois',
            Colors.amber,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SagaKingsScreen(),
                ),
              );
            },
          ),
          _drawerTile(
            Icons.star_outline_rounded,
            'Talents',
            Colors.greenAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TalentsScreen(user: widget.user),
                ),
              );
            },
          ),
          _drawerTile(
            Icons.leaderboard_outlined,
            'Classements',
            Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StandingsScreen(),
                ),
              );
            },
          ),
          _drawerTile(
            Icons.sports_soccer_rounded,
            'Championnats Locaux',
            Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocalLeagueScreen(),
                ),
              );
            },
          ),
          _drawerTile(
            Icons.rate_review_outlined,
            'Avis & Critiques',
            Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AvisScreen()),
              );
            },
          ),
          _buildStyledDivider('ACCÈS PREMIUM'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: goldColor.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                _drawerTile(
                  Icons.monetization_on_outlined,
                  'Éducation Financière',
                  goldColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FinanceEducationScreen(),
                      ),
                    );
                  },
                ),
                _drawerTile(
                  Icons.workspace_premium_outlined,
                  'Abonnement Premium',
                  goldColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PremiumSubscriptionScreen(),
                      ),
                    );
                  },
                ),
                _drawerTile(
                  Icons.confirmation_num_outlined,
                  'Paiement Billets',
                  goldColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TicketsPremiumScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildStyledDivider('PARAMÈTRES'),
          _drawerTile(
            Icons.settings_outlined,
            'Paramètres',
            Colors.white38,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _drawerTile(
            Icons.logout_rounded,
            'Déconnexion',
            Colors.redAccent,
            onTap: () async {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBody: true,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          RefreshIndicator(
            backgroundColor: const Color(0xFF151515),
            color: Colors.greenAccent,
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.greenAccent),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 1200,
                    itemCount: _posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildStoriesSection();
                      final post = _posts[index - 1];
                      return RepaintBoundary(
                        child: _buildFeedItem(post: post, index: index - 1),
                      );
                    },
                  ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            bottom: _isBottomBarVisible ? 0 : -110,
            left: 0,
            right: 0,
            child: _buildBottomNavBar(),
          ),
          if (_showLikeOverlay) Center(child: _buildLikeHeart()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STORIES
  // ─────────────────────────────────────────────────────────────

  Widget _buildStoriesSection() {
    return Container(
      height: 135,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        itemCount: _groupedStatuses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildAddStory();
          return _buildStoryItem(_groupedStatuses[index - 1]);
        },
      ),
    );
  }

  Widget _buildAddStory() {
    return GestureDetector(
      onTap: _showStatusTypeSelector,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: (widget.user.img_url?.isNotEmpty ?? false)
                        ? NetworkImage(widget.user.img_url!)
                        : null,
                    child:
                        (widget.user.img_url == null ||
                            widget.user.img_url!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 30,
                          )
                        : null,
                  ),
                ),
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.greenAccent,
                  child: Icon(Icons.add, size: 16, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Mon Statut',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(dynamic status) {
    final userData = status['users'];
    final String authorImg = userData != null
        ? (userData['img_url'] ?? '')
        : '';
    final String authorName = userData != null
        ? (userData['full_name'] ?? 'Utilisateur')
        : 'Utilisateur';
    final bool isViewed = status['isViewed'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isViewed
                  ? null
                  : const LinearGradient(
                      colors: [Colors.green, Colors.red, Colors.yellow],
                    ),
              color: isViewed ? Colors.white10 : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white12,
                backgroundImage: authorImg.isNotEmpty
                    ? NetworkImage(authorImg)
                    : null,
                child: authorImg.isEmpty
                    ? const Icon(Icons.person, color: Colors.white24)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              authorName.split(' ')[0],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isViewed ? Colors.white38 : Colors.white,
                fontSize: 11,
                fontWeight: isViewed ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'RUGIR UN STATUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusTypeBtn(
                  Icons.text_fields_rounded,
                  'Texte',
                  Colors.blueAccent,
                  'TEXT',
                ),
                _statusTypeBtn(
                  Icons.image_rounded,
                  'Photo',
                  Colors.greenAccent,
                  'IMAGE',
                ),
                _statusTypeBtn(
                  Icons.videocam_rounded,
                  'Vidéo',
                  Colors.redAccent,
                  'VIDEO',
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _statusTypeBtn(IconData icon, String label, Color color, String type) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreateContentScreen(type: type, user: widget.user),
          ),
        ).then((_) => _loadData());
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FEED
  // ─────────────────────────────────────────────────────────────

  Widget _buildFeedItem({required dynamic post, required int index}) {
    final userData = post['users'];
    final bool isRepost = post['is_repost'] ?? false;
    final String originalAuthor = post['original_author_name'] ?? '';
    final bool isAuthorCertified = userData?['is_certified'] ?? false;
    final String postType = (post['type'] ?? 'TEXT').toString().toUpperCase();
    final List<String> mediaUrls = _getMediaUrls(post);
    final String content = post['content']?.toString() ?? '';
    final bool isLiked = post['is_liked_by_me'] ?? false;
    final int likesCount = post['likes_count'] ?? 0;
    final int commentCount = post['comments_count'] ?? 0;
    final int repostCount = post['reposts_count'] ?? 0;
    final String authorName = userData?['full_name'] ?? 'Utilisateur';
    final String? authorImg = userData?['img_url'];
    final String createdAt = post['created_at']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost)
            Padding(
              padding: const EdgeInsets.only(left: 55, bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    color: Colors.white38,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Republication de $originalAuthor',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onDoubleTap: () => _handleDoubleTap(post),
            child: postType == 'TEXT' || mediaUrls.isEmpty
                ? _buildTextPostCard(
                    post: post,
                    content: content,
                    authorName: authorName,
                    authorImg: authorImg,
                    isAuthorCertified: isAuthorCertified,
                    createdAt: createdAt,
                    isLiked: isLiked,
                    likesCount: likesCount,
                    commentCount: commentCount,
                    repostCount: repostCount,
                  )
                : _buildMediaPostCard(
                    post: post,
                    mediaUrls: mediaUrls,
                    postType: postType,
                    content: content,
                    authorName: authorName,
                    authorImg: authorImg,
                    isAuthorCertified: isAuthorCertified,
                    createdAt: createdAt,
                    isLiked: isLiked,
                    likesCount: likesCount,
                    commentCount: commentCount,
                    repostCount: repostCount,
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TEXT POST CARD — header + texte (2L max + voir plus) + divider + actions + vues
  // ─────────────────────────────────────────────────────────────

  Widget _buildTextPostCard({
    required dynamic post,
    required String content,
    required String authorName,
    required String? authorImg,
    required bool isAuthorCertified,
    required String createdAt,
    required bool isLiked,
    required int likesCount,
    required int commentCount,
    required int repostCount,
  }) {
    return _ExpandableHomePostCard(
      post: post,
      content: content,
      isLiked: isLiked,
      likesCount: likesCount,
      commentCount: commentCount,
      repostCount: repostCount,
      header: _buildPostHeader(
        authorName: authorName,
        authorImg: authorImg,
        isAuthorCertified: isAuthorCertified,
        createdAt: createdAt,
        post: post,
      ),
      onLike: () => _toggleLike(post),
      onComment: () => _showCommentsModal(post),
      onRepost: () => _handleRepost(post),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MEDIA POST CARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildMediaPostCard({
    required dynamic post,
    required List<String> mediaUrls,
    required String postType,
    required String content,
    required String authorName,
    required String? authorImg,
    required bool isAuthorCertified,
    required String createdAt,
    required bool isLiked,
    required int likesCount,
    required int commentCount,
    required int repostCount,
  }) {
    return _MediaPostCard(
      post: post,
      mediaUrls: mediaUrls,
      postType: postType,
      content: content,
      authorName: authorName,
      authorImg: authorImg,
      isAuthorCertified: isAuthorCertified,
      createdAt: createdAt,
      isLiked: isLiked,
      likesCount: likesCount,
      commentCount: commentCount,
      repostCount: repostCount,
      timeAgo: _timeAgo,
      onImageTap: _showZoomedImage,
      onLike: () => _toggleLike(post),
      onComment: () => _showCommentsModal(post),
      onRepost: () => _handleRepost(post),
      onOptions: () => _showPostOptions(post),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // POST HEADER (partagé text + media)
  // ─────────────────────────────────────────────────────────────

  Widget _buildPostHeader({
    required String authorName,
    required String? authorImg,
    required bool isAuthorCertified,
    required String createdAt,
    required dynamic post,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [Colors.green, Colors.red, Colors.yellow, Colors.green],
            ),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black,
            backgroundImage: (authorImg?.isNotEmpty ?? false)
                ? NetworkImage(authorImg!)
                : null,
            child: (authorImg?.isEmpty ?? true)
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'L',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isAuthorCertified ? Icons.verified : Icons.stars_rounded,
                    color: isAuthorCertified ? Colors.blueAccent : Colors.amber,
                    size: 13,
                  ),
                ],
              ),
              Text(
                _timeAgo(createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showPostOptions(post),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.more_horiz, color: Colors.white70, size: 22),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIKE HEART OVERLAY
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // COMMENTAIRES
  // ─────────────────────────────────────────────────────────────

  void _showCommentsModal(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => SharedCommentsSheet(
        post: post,
        socialService: _socialService,
        currentUserId: widget.user.id,
        currentUserImg: widget.user.img_url,
        currentUserName: widget.user.fullName,
        onCommentAdded: () => _loadData(),
        onNavigateToProfile: _navigateToProfile,
      ),
    );
  }

  void _showPostOptions(dynamic post) {
    final bool isMyPost = post['author_id'] == widget.user.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                'Supprimer ce post',
                Colors.redAccent,
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  await _socialService.deletePost(post['id']);
                  Navigator.pop(context);
                  _loadData();
                },
              )
            else ...[
              _drawerTile(
                Icons.flag_outlined,
                'Signaler le contenu',
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

  // ─────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ─────────────────────────────────────────────────────────────

  Widget _buildBottomNavBar() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      offset: _isBottomBarVisible ? Offset.zero : const Offset(0, 2),
      child: Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 30, left: 30, right: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: java_ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navBtn(Icons.home_filled, _currentBottomIndex == 0, () {
                  setState(() => _currentBottomIndex = 0);
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                  );
                }),
                _navBtn(
                  Icons.stars_rounded,
                  _currentBottomIndex == 1,
                  () {
                    setState(() => _currentBottomIndex = 1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TalentsScreen(user: widget.user),
                      ),
                    );
                  },
                  specialColor: Colors.greenAccent,
                ),
                _navBtn(Icons.search_rounded, _currentBottomIndex == 2, () {
                  setState(() => _currentBottomIndex = 2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                }),
                _navBtn(
                  Icons.notifications_active_outlined,
                  _currentBottomIndex == 3,
                  () {
                    setState(() => _currentBottomIndex = 3);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(
    IconData icon,
    bool isActive,
    VoidCallback onTap, {
    Color? specialColor,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? (specialColor ?? Colors.greenAccent) : Colors.white38,
        size: 28,
      ),
      onPressed: onTap,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS UI
  // ─────────────────────────────────────────────────────────────

  Widget _drawerTile(IconData i, String t, Color c, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(i, color: c, size: 22),
      ),
      title: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }

  Widget _buildStyledDivider(String l) => Padding(
    padding: const EdgeInsets.fromLTRB(25, 30, 25, 10),
    child: Row(
      children: [
        Text(
          l,
          style: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(color: Colors.white.withOpacity(0.05), thickness: 1),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// CARTE TEXTE AVEC "VOIR PLUS" ET VUES
// Structure : header → texte (2L + voir plus) → divider → [❤️][💬][🔁] ··· [👁 vues]
// ═══════════════════════════════════════════════════════════════

class _ExpandableHomePostCard extends StatefulWidget {
  final dynamic post;
  final String content;
  final Widget header;
  final bool isLiked;
  final int likesCount, commentCount, repostCount;
  final VoidCallback onLike, onComment, onRepost;

  const _ExpandableHomePostCard({
    required this.post,
    required this.content,
    required this.header,
    required this.isLiked,
    required this.likesCount,
    required this.commentCount,
    required this.repostCount,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
  });

  @override
  State<_ExpandableHomePostCard> createState() =>
      _ExpandableHomePostCardState();
}

class _ExpandableHomePostCardState extends State<_ExpandableHomePostCard> {
  bool _expanded = false;

  String _fmt(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLong = widget.content.length > 120;
    final int views = widget.post['views_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header auteur
                widget.header,

                // Texte en haut — 2 lignes max avec voir plus
                if (widget.content.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: hasLong
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _richText(
                          widget.content,
                          maxLines: _expanded ? null : 2,
                        ),
                        if (hasLong) ...[
                          const SizedBox(height: 5),
                          Text(
                            _expanded ? 'voir moins' : 'voir plus',
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
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),

          // Actions + vues
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                // Like
                _actionPill(
                  icon: widget.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: _fmt(widget.likesCount),
                  color: widget.isLiked ? Colors.red : Colors.white,
                  onTap: widget.onLike,
                ),
                const SizedBox(width: 8),

                // Commentaire
                _actionPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _fmt(widget.commentCount),
                  color: Colors.white,
                  onTap: widget.onComment,
                ),
                const SizedBox(width: 8),

                // Repost
                _actionPill(
                  icon: Icons.repeat_rounded,
                  label: _fmt(widget.repostCount),
                  color: widget.repostCount > 0
                      ? const Color(0xFF3CFF7E)
                      : Colors.white,
                  onTap: widget.onRepost,
                ),

                const Spacer(),

                // Vues — sobre, visible par tous
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
                        fontSize: 12,
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

  Widget _actionPill({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            if (label != '0') ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _richText(String content, {int? maxLines}) {
    final words = content.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final bool isLast = i == words.length - 1;
      if (word.startsWith('#') || word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: word + (isLast ? '' : ' '),
            style: TextStyle(
              color: word.startsWith('#')
                  ? const Color(0xFF3CFF7E)
                  : Colors.blueAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: word + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEDIA POST CARD
// Structure : header + texte (2L en haut) + media + actions + vues
// ═══════════════════════════════════════════════════════════════

class _MediaPostCard extends StatefulWidget {
  final dynamic post;
  final List<String> mediaUrls;
  final String postType;
  final String content;
  final String authorName;
  final String? authorImg;
  final bool isAuthorCertified;
  final String createdAt;
  final bool isLiked;
  final int likesCount;
  final int commentCount;
  final int repostCount;
  final String Function(String) timeAgo;
  final Function(String) onImageTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onRepost;
  final VoidCallback onOptions;

  const _MediaPostCard({
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
    required this.commentCount,
    required this.repostCount,
    required this.timeAgo,
    required this.onImageTap,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onOptions,
  });

  @override
  State<_MediaPostCard> createState() => _MediaPostCardState();
}

class _MediaPostCardState extends State<_MediaPostCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isPlayingVideo = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.mediaUrls.length;
    final int views = widget.post['views_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 430,
            child: Stack(
              children: [
                // ── Media ──
                Positioned.fill(
                  child: widget.postType == 'VIDEO'
                      ? _isPlayingVideo
                            ? VideoPostPlayer(videoUrl: widget.mediaUrls[0])
                            : GestureDetector(
                                onTap: () =>
                                    setState(() => _isPlayingVideo = true),
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
                                            size: 72,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Appuyer pour lire',
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
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: total,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => widget.onImageTap(widget.mediaUrls[i]),
                            child: Image.network(
                              widget.mediaUrls[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
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
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),

                // ── Gradient top ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Gradient bottom ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.88),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Header auteur (top) ──
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
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
                          radius: 18,
                          backgroundColor: Colors.black,
                          backgroundImage:
                              (widget.authorImg?.isNotEmpty ?? false)
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
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                                      fontSize: 13,
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
                                  size: 13,
                                ),
                              ],
                            ),
                            Text(
                              widget.timeAgo(widget.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onOptions,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Texte EN HAUT juste après le header (2L max) ──
                if (widget.content.isNotEmpty)
                  Positioned(
                    top: 68,
                    left: 14,
                    right: 14,
                    child: Text(
                      widget.content,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.93),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // ── Compteur photos (top right, décalé si texte présent) ──
                if (total > 1)
                  Positioned(
                    top: widget.content.isNotEmpty ? 100 : 68,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                // ── Nav prev ──
                if (total > 1 && _currentPage > 0)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
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
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Nav next ──
                if (total > 1 && _currentPage < total - 1)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
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
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Dots indicateur ──
                if (total > 1 && total <= 10)
                  Positioned(
                    bottom: 58,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (i) {
                        final bool isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 18 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }),
                    ),
                  ),

                // ── Actions bar bas : [❤️][💬][🔁] ··· [👁 vues] ──
                Positioned(
                  bottom: 0,
                  left: 14,
                  right: 14,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        _pill(
                          icon: widget.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: _fmt(widget.likesCount),
                          color: widget.isLiked ? Colors.red : Colors.white,
                          onTap: widget.onLike,
                        ),
                        const SizedBox(width: 8),
                        _pill(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: _fmt(widget.commentCount),
                          color: Colors.white,
                          onTap: widget.onComment,
                        ),
                        const SizedBox(width: 8),
                        _pill(
                          icon: Icons.repeat_rounded,
                          label: _fmt(widget.repostCount),
                          color: widget.repostCount > 0
                              ? const Color(0xFF3CFF7E)
                              : Colors.white,
                          onTap: widget.onRepost,
                        ),
                        const Spacer(),
                        // Vues sobres
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 13,
                              color: Colors.white.withOpacity(0.55),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _fmt(views),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Thumbnail strip (si multi-photos) ──
          if (total > 1 && widget.postType != 'VIDEO')
            _buildThumbnailStrip(total),
        ],
      ),
    );
  }

  Widget _pill({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            if (label != '0') ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(int total) {
    const int maxVisible = 5;
    final int showCount = total > maxVisible ? maxVisible - 1 : total;
    final int overflow = total > maxVisible ? total - showCount : 0;
    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          ...List.generate(showCount, (i) {
            final bool isActive = i == _currentPage;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 5),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? Colors.white.withOpacity(0.75)
                        : Colors.white.withOpacity(0.12),
                    width: isActive ? 1.5 : 1,
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
          if (overflow > 0)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Center(
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
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

// ═══════════════════════════════════════════════════════════════
// SHARED COMMENTS SHEET
// ═══════════════════════════════════════════════════════════════

class SharedCommentsSheet extends StatefulWidget {
  final dynamic post;
  final SocialService socialService;
  final String currentUserId;
  final String? currentUserImg;
  final String currentUserName;
  final VoidCallback onCommentAdded;
  final Function(dynamic) onNavigateToProfile;

  const SharedCommentsSheet({
    super.key,
    required this.post,
    required this.socialService,
    required this.currentUserId,
    this.currentUserImg,
    required this.currentUserName,
    required this.onCommentAdded,
    required this.onNavigateToProfile,
  });

  @override
  State<SharedCommentsSheet> createState() => _SharedCommentsSheetState();
}

class _SharedCommentsSheetState extends State<SharedCommentsSheet> {
  final TextEditingController _mainController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _replyControllers = {};
  List<CommentItem> _comments = [];
  bool _isLoading = true;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _scrollController.dispose();
    for (final c in _replyControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final postId = widget.post['id'].toString();
      final raw = await widget.socialService.getCommentsStream(postId).first;
      if (mounted) {
        setState(() {
          _comments = raw.map((m) => CommentItem.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _fmt(int n) {
    if (n == 0) return '0';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Future<void> _sendComment(String text, {String? parentId}) async {
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await widget.socialService.addComment(
        widget.post['id'].toString(),
        widget.currentUserId,
        text.trim(),
      );
      if (parentId == null) {
        widget.onCommentAdded();
        _mainController.clear();
        setState(() {
          _replyingToId = null;
          _replyingToName = null;
        });
      } else {
        _replyControllers[parentId]?.clear();
        setState(() {
          _replyingToId = null;
          _replyingToName = null;
        });
      }
      await _loadComments();
    } catch (e) {
      debugPrint('Erreur commentaire: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'COMMENTAIRES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3CFF7E).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF3CFF7E).withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.post['comments_count'] ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF3CFF7E),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'RÉCENTS ▾',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3CFF7E),
                      strokeWidth: 2,
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Text(
                      'Soyez le premier à commenter !',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.04),
                      height: 4,
                      thickness: 1,
                      indent: 12,
                      endIndent: 12,
                    ),
                    itemBuilder: (_, i) => _buildCommentItem(_comments[i]),
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 16,
              right: 16,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3CFF7E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Réponse à $_replyingToName',
                          style: const TextStyle(
                            color: Color(0xFF3CFF7E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyingToId = null;
                            _replyingToName = null;
                          }),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 10),
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
                      padding: const EdgeInsets.all(1.5),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF1A1A1A),
                        backgroundImage:
                            (widget.currentUserImg?.isNotEmpty ?? false)
                            ? NetworkImage(widget.currentUserImg!)
                            : null,
                        child: (widget.currentUserImg?.isEmpty ?? true)
                            ? Text(
                                widget.currentUserName.isNotEmpty
                                    ? widget.currentUserName[0].toUpperCase()
                                    : 'L',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _mainController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _replyingToName != null
                              ? 'Répondre à $_replyingToName...'
                              : 'Ajouter un commentaire...',
                          hintStyle: const TextStyle(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFF3CFF7E),
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _sendComment(
                        _mainController.text,
                        parentId: _replyingToId,
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3CFF7E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
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

  Widget _buildCommentItem(CommentItem c) {
    _replyControllers.putIfAbsent(c.id, () => TextEditingController());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => widget.onNavigateToProfile({
                  'id': c.authorId,
                  'full_name': c.authorName,
                  'img_url': c.authorImg,
                }),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
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
                    radius: 18,
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: (c.authorImg?.isNotEmpty ?? false)
                        ? NetworkImage(c.authorImg!)
                        : null,
                    child: (c.authorImg?.isEmpty ?? true)
                        ? Text(
                            c.authorName.isNotEmpty
                                ? c.authorName[0].toUpperCase()
                                : 'L',
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onNavigateToProfile({
                            'id': c.authorId,
                            'full_name': c.authorName,
                            'img_url': c.authorImg,
                          }),
                          child: Text(
                            c.authorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (c.isCertified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blueAccent,
                            size: 13,
                          ),
                        const Spacer(),
                        Text(
                          _formatDate(c.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _richText(c.content, fontSize: 13),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _actBtn(
                          icon: c.isLikedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: _fmt(c.likesCount),
                          color: c.isLikedByMe
                              ? Colors.red
                              : Colors.white.withOpacity(0.4),
                          onTap: () => setState(() {
                            c.isLikedByMe = !c.isLikedByMe;
                            c.likesCount += c.isLikedByMe ? 1 : -1;
                          }),
                        ),
                        _dot(),
                        _actBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Répondre',
                          color: c.showReplyBox
                              ? const Color(0xFF3CFF7E)
                              : Colors.white.withOpacity(0.4),
                          onTap: () => setState(() {
                            c.showReplyBox = !c.showReplyBox;
                            if (c.showReplyBox) {
                              _replyingToId = c.id;
                              _replyingToName = c.authorName;
                            } else {
                              _replyingToId = null;
                              _replyingToName = null;
                            }
                          }),
                        ),
                        _dot(),
                        _actBtn(
                          icon: Icons.share_outlined,
                          label: 'Partager',
                          color: Colors.white.withOpacity(0.4),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (c.showReplyBox)
          Padding(
            padding: const EdgeInsets.only(left: 46, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyControllers[c.id],
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Répondre à ${c.authorName}...',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF3CFF7E),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF3CFF7E),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: const Color(0xFF3CFF7E).withOpacity(0.3),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                    ),
                    onSubmitted: (text) {
                      _sendComment(text, parentId: c.id);
                      setState(() => c.showReplyBox = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _sendComment(
                      _replyControllers[c.id]?.text ?? '',
                      parentId: c.id,
                    );
                    setState(() => c.showReplyBox = false);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3CFF7E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (c.replies.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => c.showReplies = !c.showReplies),
            child: Padding(
              padding: const EdgeInsets.only(left: 46, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    c.showReplies
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF3CFF7E),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c.showReplies
                        ? 'Masquer'
                        : 'Voir ${c.replies.length} réponse${c.replies.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF3CFF7E),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (c.showReplies)
          ...c.replies.asMap().entries.map(
            (e) => _buildReplyItem(
              e.value,
              c,
              isLast: e.key == c.replies.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _buildReplyItem(
    CommentItem r,
    CommentItem parent, {
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: CustomPaint(painter: _TreeLinePainter(isLast: isLast)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => widget.onNavigateToProfile({
                        'id': r.authorId,
                        'full_name': r.authorName,
                        'img_url': r.authorImg,
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
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
                          radius: 14,
                          backgroundColor: const Color(0xFF1A1A1A),
                          backgroundImage: (r.authorImg?.isNotEmpty ?? false)
                              ? NetworkImage(r.authorImg!)
                              : null,
                          child: (r.authorImg?.isEmpty ?? true)
                              ? Text(
                                  r.authorName.isNotEmpty
                                      ? r.authorName[0].toUpperCase()
                                      : 'L',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => widget.onNavigateToProfile({
                                  'id': r.authorId,
                                  'full_name': r.authorName,
                                  'img_url': r.authorImg,
                                }),
                                child: Text(
                                  r.authorName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (r.isCertified)
                                const Icon(
                                  Icons.verified,
                                  color: Colors.blueAccent,
                                  size: 11,
                                ),
                              const Spacer(),
                              Text(
                                _formatDate(r.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _richText(r.content, fontSize: 12),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _replyAct(
                                icon: r.isLikedByMe
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                label: _fmt(r.likesCount),
                                color: r.isLikedByMe
                                    ? Colors.red
                                    : Colors.white.withOpacity(0.3),
                                onTap: () => setState(() {
                                  r.isLikedByMe = !r.isLikedByMe;
                                  r.likesCount += r.isLikedByMe ? 1 : -1;
                                }),
                              ),
                              const SizedBox(width: 12),
                              _replyAct(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Répondre',
                                color: Colors.white.withOpacity(0.3),
                                onTap: () => setState(() {
                                  parent.showReplyBox = true;
                                  _replyingToId = parent.id;
                                  _replyingToName = r.authorName;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _richText(String text, {double fontSize = 13}) {
    final words = text.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final bool isLast = i == words.length - 1;
      if (w.startsWith('@')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (w.startsWith('#')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: const TextStyle(
              color: Color(0xFF3CFF7E),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: fontSize,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _actBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replyAct({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
      width: 2.5,
      height: 2.5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─── Painter arbre réponses ───────────────────────────────────

class _TreeLinePainter extends CustomPainter {
  final bool isLast;
  _TreeLinePainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, isLast ? size.height * 0.45 : size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TreeLinePainter old) => old.isLast != isLast;
}
