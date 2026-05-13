import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'chat_screen.dart';
import 'create_group_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String currentUserId;
  const MessagesScreen({super.key, required this.currentUserId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;

  // ── Recherche
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<dynamic> _searchResults = [];
  Timer? _searchDebounce;

  // ── Cache local persistant pendant toute la session
  static List<dynamic> _cachedPrivateConvs = [];
  static List<dynamic> _cachedMyGroups = [];
  static List<dynamic> _cachedDiscoverGroups = [];
  static bool _hasCachedData = false;

  List<dynamic> privateConvs = [];
  List<dynamic> myGroups = [];
  List<dynamic> discoverGroups = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (_hasCachedData) {
      privateConvs = List.from(_cachedPrivateConvs);
      myGroups = List.from(_cachedMyGroups);
      discoverGroups = List.from(_cachedDiscoverGroups);
      _isLoading = false;
    }

    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    if (!_hasCachedData) setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchPrivateConvs(), _fetchMyGroups()]);
      await _fetchDiscoverGroups();
      _hasCachedData = true;
    } catch (e) {
      debugPrint("Erreur chargement : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── FETCH ────────────────────────────────────────────────────

  Future<void> _fetchPrivateConvs() async {
    final response = await supabase
        .from('messages')
        .select(
          '*, sender:sender_id(full_name, img_url, is_certified), receiver:receiver_id(full_name, img_url, is_certified)',
        )
        .or(
          'sender_id.eq.${widget.currentUserId},receiver_id.eq.${widget.currentUserId}',
        )
        .isFilter('group_id', null)
        .order('created_at', ascending: false);

    final Map<String, dynamic> unique = {};
    for (var m in response) {
      final partnerId = m['sender_id'] == widget.currentUserId
          ? m['receiver_id']
          : m['sender_id'];
      if (partnerId != null && !unique.containsKey(partnerId)) {
        unique[partnerId] = m;
      }
    }
    final result = unique.values.toList();
    if (mounted) setState(() => privateConvs = result);
    _cachedPrivateConvs = result;
  }

  Future<void> _fetchMyGroups() async {
    final response = await supabase
        .from('group_members')
        .select('role, group_id, groups(*)')
        .eq('user_id', widget.currentUserId)
        .inFilter('role', ['MEMBER', 'ADMIN']);

    if (mounted) setState(() => myGroups = response);
    _cachedMyGroups = response;
  }

  Future<void> _fetchDiscoverGroups() async {
    final response = await supabase.from('groups').select('*').limit(20);
    final myGroupIds = myGroups.map((g) => g['group_id']).toList();
    final result = response
        .where((g) => !myGroupIds.contains(g['id']))
        .toList();
    if (mounted) setState(() => discoverGroups = result);
    _cachedDiscoverGroups = result;
  }

  // ── RECHERCHE UTILISATEURS ────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      await _searchUsers(query.trim());
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    try {
      final response = await supabase
          .from('users')
          .select('id, full_name, img_url, is_certified, role')
          .ilike('full_name', '%$query%')
          .neq('id', widget.currentUserId)
          .limit(15);

      if (mounted) {
        setState(() {
          _searchResults = response;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  void _openChat(dynamic user) {
    HapticFeedback.lightImpact();
    // Ferme la recherche
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatName: user['full_name'] ?? 'Lion',
          targetId: user['id'],
          currentUserId: widget.currentUserId,
          isGroup: false,
        ),
      ),
    ).then((_) => _refreshAll());
  }

  // ── ACTIONS GROUPES ──────────────────────────────────────────

  void _shareInvite(String? inviteCode) {
    if (inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: "lionapp://join/$inviteCode"));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Lien copié 🦁",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3CFF7E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _joinRequest(String groupId) async {
    try {
      await supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': widget.currentUserId,
        'role': 'PENDING',
      });
      HapticFeedback.mediumImpact();
      _refreshAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Demande envoyée !",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF3CFF7E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {}
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(),
      body: _isLoading && !_hasCachedData
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3CFF7E),
                strokeWidth: 2,
              ),
            )
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [_buildMessagesList(), _buildTribesSection()],
                ),
                // Overlay recherche
                if (_isSearching) _buildSearchOverlay(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: _isSearching
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
                FocusScope.of(context).unfocus();
              },
            )
          : IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Rechercher un Lion...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            )
          : const Text(
              "MESSAGES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
      actions: [
        if (!_isSearching) ...[
          // Bouton recherche
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {
              setState(() => _isSearching = true);
            },
          ),
          // Bouton créer groupe
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3CFF7E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3CFF7E).withOpacity(0.2),
                ),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: Color(0xFF3CFF7E),
                size: 20,
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
            ).then((_) => _refreshAll()),
          ),
          const SizedBox(width: 4),
        ],
      ],
      bottom: _isSearching
          ? null
          : TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF3CFF7E),
              indicatorWeight: 2,
              labelColor: const Color(0xFF3CFF7E),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
              tabs: const [
                Tab(text: "MESSAGES"),
                Tab(text: "TRIBUS"),
              ],
            ),
    );
  }

  // ── OVERLAY RECHERCHE ────────────────────────────────────────

  Widget _buildSearchOverlay() {
    return Container(
      color: const Color(0xFF050505),
      child: Column(
        children: [
          // Résultats
          Expanded(
            child: _isSearchLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3CFF7E),
                      strokeWidth: 2,
                    ),
                  )
                : _searchController.text.trim().isEmpty
                ? _buildSearchHint()
                : _searchResults.isEmpty
                ? _buildSearchEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.04),
                      height: 1,
                      indent: 76,
                    ),
                    itemBuilder: (context, i) {
                      final user = _searchResults[i];
                      return _buildUserResult(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              color: Colors.white.withOpacity(0.1),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Tape le nom d'un Lion",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Pour lui envoyer un message direct",
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_dissatisfied_rounded,
            color: Colors.white.withOpacity(0.1),
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun Lion trouvé",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResult(dynamic user) {
    final String name = user['full_name'] ?? 'Lion';
    final String? imgUrl = user['img_url'];
    final bool isCertified = user['is_certified'] ?? false;
    final String role = user['role'] ?? 'USER';

    return InkWell(
      onTap: () => _openChat(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
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
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF1A1A1A),
                backgroundImage: (imgUrl?.isNotEmpty ?? false)
                    ? NetworkImage(imgUrl!)
                    : null,
                child: (imgUrl?.isEmpty ?? true)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'L',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCertified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified,
                          color: Colors.blueAccent,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Bouton message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3CFF7E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3CFF7E).withOpacity(0.25),
                ),
              ),
              child: const Text(
                "ÉCRIRE",
                style: TextStyle(
                  color: Color(0xFF3CFF7E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MESSAGES PRIVÉS ──────────────────────────────────────────

  Widget _buildMessagesList() {
    if (privateConvs.isEmpty) {
      return _emptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: "Aucun message",
        subtitle: "Appuie sur 🔍 pour contacter un Lion",
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF3CFF7E),
      backgroundColor: const Color(0xFF151515),
      onRefresh: _refreshAll,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: privateConvs.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.04),
          height: 1,
          indent: 76,
        ),
        itemBuilder: (context, index) {
          final conv = privateConvs[index];
          final partner = conv['sender_id'] == widget.currentUserId
              ? conv['receiver']
              : conv['sender'];
          if (partner == null) return const SizedBox.shrink();

          final bool isUnread =
              !(conv['is_read'] ?? true) &&
              conv['sender_id'] != widget.currentUserId;
          final String time = _formatTime(conv['created_at']);
          final String preview = _buildPreview(conv);
          final String partnerId = conv['sender_id'] == widget.currentUserId
              ? conv['receiver_id']
              : conv['sender_id'];

          return _ConvTile(
            name: partner['full_name'] ?? 'Lion',
            imgUrl: partner['img_url'],
            isCertified: partner['is_certified'] ?? false,
            preview: preview,
            time: time,
            isUnread: isUnread,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatName: partner['full_name'] ?? 'Lion',
                  targetId: partnerId,
                  currentUserId: widget.currentUserId,
                  isGroup: false,
                ),
              ),
            ).then((_) => _refreshAll()),
          );
        },
      ),
    );
  }

  String _buildPreview(Map<String, dynamic> conv) {
    final type = conv['type'] ?? 'TEXT';
    if (type == 'IMAGE') return '📷 Photo';
    if (type == 'VIDEO') return '🎥 Vidéo';
    if (type == 'VOICE') return '🎙️ Message vocal';
    return conv['content'] ?? '';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return DateFormat('EEE', 'fr').format(dt);
    return DateFormat('dd/MM').format(dt);
  }

  // ── TRIBUS ───────────────────────────────────────────────────

  Widget _buildTribesSection() {
    return RefreshIndicator(
      color: const Color(0xFF3CFF7E),
      backgroundColor: const Color(0xFF151515),
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (myGroups.isNotEmpty) ...[
            _sectionHeader(
              "MES TRIBUS",
              "${myGroups.length}",
              const Color(0xFF3CFF7E),
            ),
            ...myGroups.map((g) => _buildGroupCard(g['groups'], true)),
          ],
          _sectionHeader(
            "DÉCOUVRIR",
            "${discoverGroups.length}",
            Colors.white38,
          ),
          if (discoverGroups.isEmpty)
            _emptyState(
              icon: Icons.explore_outlined,
              title: "Aucune tribu disponible",
              subtitle: "Crée la première tribu !",
            )
          else
            ...discoverGroups.map((g) => _buildGroupCard(g, false)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String count, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(dynamic group, bool isMember) {
    if (group == null) return const SizedBox.shrink();
    int count = group['members_count'] ?? 0;
    if (isMember && count == 0) count = 1;
    final String type = group['type'] ?? 'Match';
    final Color typeColor = _typeColor(type);

    return GestureDetector(
      onTap: isMember
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatName: group['name'],
                  targetId: group['id'],
                  currentUserId: widget.currentUserId,
                  isGroup: true,
                ),
              ),
            ).then((_) => _refreshAll())
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMember
                ? const Color(0xFF3CFF7E).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withOpacity(0.3),
                      typeColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image:
                      (group['image_url'] != null &&
                          group['image_url'].toString().isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(group['image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                  border: Border.all(
                    color: typeColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child:
                    (group['image_url'] == null ||
                        group['image_url'].toString().isEmpty)
                    ? Icon(_typeIcon(type), color: typeColor, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group['name'] ?? 'Tribu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3CFF7E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "MEMBRE",
                              style: TextStyle(
                                color: Color(0xFF3CFF7E),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.people_outline_rounded,
                          color: Colors.white38,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          "$count membre${count > 1 ? 's' : ''}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (group['description'] != null &&
                        group['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          group['description'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (isMember)
                GestureDetector(
                  onTap: () => _shareInvite(group['invite_code']),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(
                      Icons.share_outlined,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _joinRequest(group['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withOpacity(0.2),
                          typeColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      "REJOINDRE",
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Match':
        return const Color(0xFF3CFF7E);
      case 'Club':
        return Colors.blueAccent;
      case 'Ultras':
        return Colors.orangeAccent;
      case 'Analyse':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF3CFF7E);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Match':
        return Icons.sports_soccer_rounded;
      case 'Club':
        return Icons.shield_rounded;
      case 'Ultras':
        return Icons.local_fire_department_rounded;
      case 'Analyse':
        return Icons.analytics_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.1), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TUILE DE CONVERSATION ────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final String name;
  final String? imgUrl;
  final bool isCertified;
  final String preview;
  final String time;
  final bool isUnread;
  final VoidCallback onTap;

  const _ConvTile({
    required this.name,
    this.imgUrl,
    required this.isCertified,
    required this.preview,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
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
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: (imgUrl?.isNotEmpty ?? false)
                        ? NetworkImage(imgUrl!)
                        : null,
                    child: (imgUrl?.isEmpty ?? true)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'L',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                if (isCertified)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        time,
                        style: TextStyle(
                          color: isUnread
                              ? const Color(0xFF3CFF7E)
                              : Colors.white38,
                          fontSize: 10,
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          preview,
                          style: TextStyle(
                            color: isUnread ? Colors.white60 : Colors.white38,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3CFF7E),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
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
