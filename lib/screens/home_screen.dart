import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:ui' as java_ui;
import 'package:flutter/services.dart';

// Tes imports synchronisés
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

  // Variables pour les données dynamiques
  List<dynamic> _posts = [];
  List<dynamic> _groupedStatuses = [];
  bool _isLoading = true;
  int _currentBottomIndex = 0;

  bool _isBottomBarVisible = true;
  bool _showLikeOverlay = false;
  late AnimationController _likeController;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _moveUp;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();

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
      print("Erreur de chargement Home: $e");
    }
  }

  // --- UTILITAIRE : timeAgo extrait au niveau classe pour éviter rebuild ---
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

  @override
  void dispose() {
    _scrollController.dispose();
    _likeController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DES ACTIONS ---

  Future<void> _toggleLike(dynamic post) async {
    final bool isLiked = post['is_liked_by_me'] ?? false;
    setState(() {
      post['is_liked_by_me'] = !isLiked;
      post['likes_count'] = isLiked
          ? (post['likes_count'] - 1)
          : (post['likes_count'] + 1);
    });

    try {
      await _socialService.toggleLike(post['id'].toString(), widget.user.id);
    } catch (e) {
      _loadData();
    }
  }

  Future<void> _handleRepost(dynamic post) async {
    try {
      await _socialService.repost(widget.user.id, post['id']);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Rugissement partagé !")));
      _loadData();
    } catch (e) {
      print("Erreur repost: $e");
    }
  }

  void _handleDoubleTap(dynamic post) {
    if (!(post['is_liked_by_me'] ?? false)) {
      _toggleLike(post);
    }
    HapticFeedback.mediumImpact();

    setState(() => _showLikeOverlay = true);
    _likeController.forward(from: 0);
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showLikeOverlay = false);
    });
  }

  // --- UI COMPONENTS ---

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
              "RUGIR UN STATUT",
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
                  "Texte",
                  Colors.blueAccent,
                  'TEXT',
                ),
                _statusTypeBtn(
                  Icons.image_rounded,
                  "Photo",
                  Colors.greenAccent,
                  'IMAGE',
                ),
                _statusTypeBtn(
                  Icons.videocam_rounded,
                  "Vidéo",
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
        "FECAAPP",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: 3,
        ),
      ),
      actions: [
        // --- ICÔNE MESSAGES CHIC ---
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MessagesScreen(currentUserId: widget.user.id),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.mark_chat_unread_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFFF4757),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Text(
                      "3",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // --- AVATAR PROFIL ---
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

  // --- Suite des méthodes UI standard ---
  Widget _buildAppBarAction(
    IconData icon,
    VoidCallback onTap, {
    bool hasBadge = false,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          if (hasBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    bool isCertified = widget.user.isCertified;
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
            "Mon Profil",
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
            Icons.account_balance_outlined,
            "Musée du Foot",
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
            "Saga des Rois",
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
            "Talents",
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
            "Classements",
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
            "Championnats Locaux",
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
            "Avis & Critiques",
            Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AvisScreen()),
              );
            },
          ),
          _buildStyledDivider("ACCÈS PREMIUM"),
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
                  "Éducation Financière",
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
                  "Abonnement Premium",
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
                  "Paiement Billets",
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
          _buildStyledDivider("PARAMÈTRES"),
          _drawerTile(
            Icons.settings_outlined,
            "Paramètres",
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
            "Déconnexion",
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
                    // --- SCROLL FLUIDE : cacheExtent ajouté ---
                    cacheExtent: 1000,
                    itemCount: _posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildStoriesSection();
                      final post = _posts[index - 1];
                      // --- SCROLL FLUIDE : RepaintBoundary sur chaque item ---
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

  /* ================= SECTION STATUS (STORIES) DYNAMIQUE ================= */
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
          final status = _groupedStatuses[index - 1];
          return _buildStoryItem(status);
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
                    backgroundImage:
                        widget.user.img_url != null &&
                            widget.user.img_url!.isNotEmpty
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
              "Mon Statut",
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
        ? (userData['img_url'] ?? "")
        : "";
    final String authorName = userData != null
        ? (userData['full_name'] ?? "Utilisateur")
        : "Utilisateur";

    bool isViewed = status['isViewed'] ?? false;

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
          // --- OVERFLOW CORRIGÉ : maxLines + ellipsis ---
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

  /* ================= FEED ITEM : VERSION INTÉGRALE & PROPRE ================= */
  Widget _buildFeedItem({required dynamic post, required int index}) {
    final String? mediaUrl = post['media_url'];
    final List<String> mediaUrls = mediaUrl != null ? [mediaUrl] : [];

    final userData = post['users'];
    final bool isRepost = post['is_repost'] ?? false;
    final String originalAuthor = post['original_author_name'] ?? "";
    final bool isAuthorCertified = userData?['is_certified'] ?? false;
    final String postType = post['type'] ?? "TEXT";

    final int likesCount = post['likes_count'] ?? 0;
    final int commentCount = post['comments_count'] ?? 0;
    final int repostCount = post['reposts_count'] ?? 0;

    bool isLiked = post['is_liked_by_me'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          if (isRepost)
            Padding(
              padding: const EdgeInsets.only(left: 45, bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    color: Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Republication de $originalAuthor",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
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
            child: Container(
              height: 520,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
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
              child: Stack(
                children: [
                  // --- PHOTOS PLUS CLAIRES : BoxFit.cover ---
                  Positioned.fill(
                    child: mediaUrls.isNotEmpty
                        ? (postType == "VIDEO"
                              ? VideoPostPlayer(videoUrl: mediaUrls[0])
                              : GestureDetector(
                                  onTap: () => _showZoomedImage(mediaUrls[0]),
                                  child: Image.network(
                                    mediaUrls[0],
                                    fit: BoxFit.cover,
                                  ),
                                ))
                        : Container(color: const Color(0xFF1A1A1A)),
                  ),
                  // Gradient (IgnorePointer pour laisser passer les clics vers la vidéo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.3, 1.0],
                            colors: [
                              // --- PHOTOS PLUS CLAIRES : opacités réduites ---
                              Colors.black.withOpacity(0.25),
                              Colors.transparent,
                              Colors.black.withOpacity(0.70),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header (Infos Profil)
                  Positioned(
                    top: 15,
                    left: 15,
                    right: 15,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white12,
                          backgroundImage:
                              (userData?['img_url']?.isNotEmpty ?? false)
                              ? NetworkImage(userData['img_url'])
                              : null,
                          child: (userData?['img_url']?.isEmpty ?? true)
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- OVERFLOW CORRIGÉ : Flexible autour du nom ---
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userData?['full_name'] ?? "Utilisateur",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (isAuthorCertified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                // --- SCROLL FLUIDE : _timeAgo() de la classe ---
                                _timeAgo(post['created_at']),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                          ),
                          onPressed: () => _showPostOptions(post),
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions (Boutons Likes, Comments, Repost)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post['content'] != null &&
                            post['content'].isNotEmpty)
                          Text(
                            post['content'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _interactionItem(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              "$likesCount",
                              isLiked ? Colors.red : Colors.white,
                              onTap: () => _toggleLike(post),
                            ),
                            _interactionItem(
                              Icons.chat_bubble_outline_rounded,
                              "$commentCount",
                              Colors.white,
                              onTap: () => _showCommentsModal(post),
                            ),
                            _interactionItem(
                              Icons.repeat_rounded,
                              "$repostCount",
                              repostCount > 0
                                  ? Colors.greenAccent
                                  : Colors.white,
                              onTap: () => _handleRepost(post),
                            ),
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.amber,
                              size: 20,
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
    );
  }

  Widget _interactionItem(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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

  /* ================= NOUVELLES FONCTIONS : PLEIN ÉCRAN & TEXTE ================= */

  void _showZoomedImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableText(String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        );
        final tp = TextPainter(
          text: span,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Voir la suite...",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }
        return Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white54,
          size: 60,
        ),
      ),
    );
  }

  /* ================= LOGIQUE : COMMENTAIRES & OPTIONS ================= */

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
                            widget.user.id,
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
    bool isMyPost = post['author_id'] == widget.user.id;
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
                  _loadData();
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

  /* ================= L'ANIMATION DU CŒUR LION ================= */
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

  /* ================= BARRE DE NAVIGATION : ORDRE CORRIGÉ ================= */
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
