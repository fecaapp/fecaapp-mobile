import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'match_detail_screen.dart';
import 'basketball_match_detail_screen.dart';
import 'handball_match_detail_screen.dart';
import 'athletics_match_detail_screen.dart';
import 'tennis_match_detail_screen.dart';
import 'volleyball_match_detail_screen.dart';
import 'karate_match_detail_screen.dart';
import 'boxe_match_detail_screen.dart';
import 'mma_match_detail_screen.dart';

class ScoreScreen extends StatefulWidget {
  final String sportType;

  const ScoreScreen({super.key, required this.sportType});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen>
    with AutomaticKeepAliveClientMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  // FIX : stream stable, créé une seule fois dans initState
  late final Stream<List<Map<String, dynamic>>> _matchStream;

  @override
  bool get wantKeepAlive => true;

  // -------------------------------------------------------
  // Couleurs et icônes par sport
  // -------------------------------------------------------
  static const Map<String, Color> _sportColors = {
    'football': Color(0xFF00FF85),
    'basketball': Color(0xFFFFA500),
    'handball': Color(0xFFFF3131),
    'athletics': Color(0xFFFF6B00),
    'tennis': Color(0xFFC8FF00),
    'volleyball': Color(0xFF9B59FF),
    'karate': Color(0xFFFF0044),
    'boxing': Color(0xFFFFB800),
    'mma': Color(0xFF00FF85),
  };

  static const Map<String, IconData> _sportIcons = {
    'football': Icons.sports_soccer,
    'basketball': Icons.sports_basketball,
    'handball': Icons.sports_handball,
    'athletics': Icons.directions_run,
    'tennis': Icons.sports_tennis,
    'volleyball': Icons.sports_volleyball,
    'karate': Icons.sports_martial_arts,
    'boxing': Icons.sports_mma,
    'mma': Icons.sports_mma,
  };

  Color get _color => _sportColors[widget.sportType] ?? const Color(0xFF00FF85);

  IconData get _icon => _sportIcons[widget.sportType] ?? Icons.sports_soccer;

  @override
  void initState() {
    super.initState();

    // FIX 1 : utiliser match_time (pas match_time qui n'existe pas)
    // FIX 2 : PAS de filtre is_locked → les matchs terminés restent visibles
    _matchStream = supabase
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('sport_type', widget.sportType)
        .order('match_time', ascending: true); // ✅ bon champ
  }

  // -------------------------------------------------------
  // Navigation sport-aware
  // -------------------------------------------------------
  void _navigateToDetail(Map<String, dynamic> match) {
    final String matchId = match['id'].toString();
    Widget screen;

    switch (widget.sportType) {
      case 'basketball':
        screen = BasketballMatchDetailScreen(matchId: matchId);
        break;
      case 'handball':
        screen = HandballMatchDetailScreen(matchId: matchId);
        break;
      case 'athletics':
        screen = AthleticsCompetitionDetailScreen(matchId: matchId);
        break;
      case 'tennis':
        screen = TennisMatchDetailScreen(matchId: matchId);
        break;
      case 'volleyball':
        screen = VolleyballMatchDetailScreen(matchId: matchId);
        break;
      case 'karate':
        screen = KarateMatchDetailScreen(matchId: matchId);
        break;
      case 'boxing':
        screen = BoxeMatchDetailScreen(matchId: matchId);
        break;
      case 'mma':
        screen = MmaMatchDetailScreen(matchId: matchId);
        break;
      default:
        screen = MatchDetailScreen(matchId: matchId);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // -------------------------------------------------------
  // Tri des matchs : LIVE → À venir → TERMINÉS
  // -------------------------------------------------------
  List<Map<String, dynamic>> _sortMatches(List<Map<String, dynamic>> raw) {
    final sorted = List<Map<String, dynamic>>.from(raw);
    sorted.sort((a, b) {
      int priority(Map m) {
        final bool isLive =
            m['is_timer_active'] == true && m['is_locked'] != true;
        final bool isLocked = m['is_locked'] == true;
        if (isLive) return 0;
        if (!isLocked) return 1;
        return 2;
      }

      final int pa = priority(a);
      final int pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);

      final DateTime tA =
          DateTime.tryParse(a['match_time'] ?? '') ?? DateTime(2099);
      final DateTime tB =
          DateTime.tryParse(b['match_time'] ?? '') ?? DateTime(2099);
      return tA.compareTo(tB);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _matchStream,
        builder: (context, snapshot) {
          // Chargement initial
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _color));
          }

          // FIX 3 : trier sans filtrer → les terminés restent affichés
          final matches = _sortMatches(snapshot.data ?? []);

          if (matches.isEmpty) {
            return _buildEmptyState();
          }

          // Séparer les sections pour un affichage structuré
          final liveMatches = matches
              .where(
                (m) => m['is_timer_active'] == true && m['is_locked'] != true,
              )
              .toList();
          final upcomingMatches = matches
              .where(
                (m) => m['is_timer_active'] != true && m['is_locked'] != true,
              )
              .toList();
          final finishedMatches = matches
              .where((m) => m['is_locked'] == true)
              .toList();

          return RefreshIndicator(
            color: _color,
            backgroundColor: const Color(0xFF111111),
            onRefresh: () async {
              // Le stream Supabase se rafraîchit automatiquement
              // mais on donne un feedback visuel
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // --- SECTION LIVE ---
                if (liveMatches.isNotEmpty) ...[
                  _buildSectionHeader(
                    "EN DIRECT",
                    _color,
                    Icons.circle,
                    count: liveMatches.length,
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildMatchCard(liveMatches[i]),
                      childCount: liveMatches.length,
                    ),
                  ),
                ],

                // --- SECTION À VENIR ---
                if (upcomingMatches.isNotEmpty) ...[
                  _buildSectionHeader(
                    "PROGRAMMÉS",
                    Colors.white38,
                    Icons.schedule,
                    count: upcomingMatches.length,
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildMatchCard(upcomingMatches[i]),
                      childCount: upcomingMatches.length,
                    ),
                  ),
                ],

                // --- SECTION TERMINÉS (FIX : toujours affichés) ---
                if (finishedMatches.isNotEmpty) ...[
                  _buildSectionHeader(
                    "TERMINÉS",
                    Colors.white24,
                    Icons.check_circle_outline,
                    count: finishedMatches.length,
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildMatchCard(finishedMatches[i]),
                      childCount: finishedMatches.length,
                    ),
                  ),
                ],

                const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
              ],
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF050505),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 18),
          const SizedBox(width: 10),
          Text(
            widget.sportType.toUpperCase(),
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Section header dans CustomScrollView
  // -------------------------------------------------------
  Widget _buildSectionHeader(
    String label,
    Color color,
    IconData icon, {
    int count = 0,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                height: 0.5,
                color: color.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Carte match améliorée
  // -------------------------------------------------------
  Widget _buildMatchCard(Map<String, dynamic> match) {
    // FIX 4 : utiliser is_timer_active et is_locked (cohérent avec dashboard)
    final bool isLive =
        match['is_timer_active'] == true && match['is_locked'] != true;
    final bool isLocked = match['is_locked'] == true;

    // FIX 5 : statut cohérent avec le dashboard JS
    //  Dashboard écrit : "EN DIRECT", "MI-TEMPS", "TERMINÉ", "PROGRAMMÉ"
    final String status = (match['status'] ?? "PROGRAMMÉ").toString();
    final bool isMT =
        status.toUpperCase().contains("MI-TEMPS") ||
        status.toUpperCase().contains("MT");
    final bool isTab = status.toUpperCase().contains("TIRS AU BUT");

    // Tirs au but
    final List p1 = match['pen1'] ?? [];
    final List p2 = match['pen2'] ?? [];
    final bool hasTAB = p1.isNotEmpty || p2.isNotEmpty;
    final int tabS1 = p1.where((e) => e == true).length;
    final int tabS2 = p2.where((e) => e == true).length;

    // FIX 6 : utiliser match_time (pas match_time)
    String startTime = "--:--";
    if (match['match_time'] != null) {
      try {
        startTime = DateFormat(
          'HH:mm',
        ).format(DateTime.parse(match['match_time']).toLocal());
      } catch (_) {}
    }

    final String journee = match['match_day'] != null
        ? "J${match['match_day']}"
        : match['journee'] ?? "";

    final Color borderColor = isLive
        ? _color.withOpacity(0.35)
        : isLocked
        ? Colors.white.withOpacity(0.03)
        : Colors.white.withOpacity(0.06);

    return GestureDetector(
      onTap: () => _navigateToDetail(match),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFF0A0A0A) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: isLive ? 1.2 : 0.8),
          boxShadow: isLive
              ? [
                  BoxShadow(
                    color: _color.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  // Journée
                  if (journee.isNotEmpty)
                    _buildPill(journee, _color.withOpacity(0.7)),
                  if (journee.isNotEmpty) const SizedBox(width: 8),
                  // Heure
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white24,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        startTime,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Badge statut
                  _buildStatusBadge(
                    isLive: isLive,
                    isMT: isMT,
                    isLocked: isLocked,
                    isTab: isTab,
                    time: match['time'],
                  ),
                ],
              ),
            ),

            // ── SCORES ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  // Équipe A
                  Expanded(
                    child: _teamSlot(
                      match['team_a_name'],
                      match['team_a_logo'],
                      dimmed: isLocked,
                    ),
                  ),

                  // Score central
                  Column(
                    children: [
                      Text(
                        "${match['score1'] ?? 0} - ${match['score2'] ?? 0}",
                        style: TextStyle(
                          color: isLocked ? Colors.white38 : Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      if (hasTAB) ...[
                        const SizedBox(height: 4),
                        _buildPill("TAB $tabS1 - $tabS2", _color),
                      ],
                      // Temps live affiché sous le score
                      if (isLive && !isMT) ...[
                        const SizedBox(height: 6),
                        _buildLiveTime(match),
                      ],
                    ],
                  ),

                  // Équipe B
                  Expanded(
                    child: _teamSlot(
                      match['team_b_name'],
                      match['team_b_logo'],
                      dimmed: isLocked,
                    ),
                  ),
                ],
              ),
            ),

            // ── BARRE LIVE ───────────────────────────────
            if (isLive && !isMT && !isLocked) _LiveBar(color: _color),

            // ── STADE ────────────────────────────────────
            if ((match['stadium'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.stadium_outlined,
                      color: Colors.white12,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (match['stadium'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white12,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
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

  Widget _buildStatusBadge({
    required bool isLive,
    required bool isMT,
    required bool isLocked,
    required bool isTab,
    dynamic time,
  }) {
    if (isLive && isMT) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
        ),
        child: const Text(
          "MI-TEMPS",
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (isTab) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
        ),
        child: const Text(
          "TIRS AU BUT",
          style: TextStyle(
            color: Colors.purpleAccent,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (isLive) {
      return _BlinkingLiveDot(color: _color);
    }

    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          "TERMINÉ",
          style: TextStyle(
            color: Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        "À VENIR",
        style: TextStyle(
          color: Colors.white38,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildLiveTime(Map<String, dynamic> match) {
    // FIX 7 : afficher le temps live avec la même logique que le dashboard
    const List<String> noApostrophe = [
      'basketball',
      'handball',
      'athletics',
      'tennis',
      'volleyball',
      'karate',
      'boxing',
      'mma',
    ];
    final bool useApostrophe = !noApostrophe.contains(widget.sportType);
    final String t = (match['time'] ?? '00:00').toString();
    final String extra = (match['extra_time'] ?? '0').toString();
    final bool hasExtra = extra != '0' && extra.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          useApostrophe ? "$t'" : t,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (useApostrophe && hasExtra)
          Text(
            " +$extra",
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _teamSlot(String? name, String? logo, {bool dimmed = false}) {
    return Column(
      children: [
        Opacity(
          opacity: dimmed ? 0.55 : 1.0,
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1A1A1A),
              backgroundImage: (logo != null && logo.isNotEmpty)
                  ? NetworkImage(logo)
                  : null,
              child: (logo == null || logo.isEmpty)
                  ? Icon(_icon, color: Colors.white10, size: 20)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (name ?? "ÉQUIPE").toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dimmed ? Colors.white30 : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color.withOpacity(0.15), size: 60),
          const SizedBox(height: 20),
          Text(
            "AUCUN MATCH\n${widget.sportType.toUpperCase()}",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _color.withOpacity(0.3),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// WIDGETS UTILITAIRES
// -------------------------------------------------------

/// Point LIVE animé (remplace l'ancien badge texte plein)
class _BlinkingLiveDot extends StatefulWidget {
  final Color color;
  const _BlinkingLiveDot({required this.color});
  @override
  State<_BlinkingLiveDot> createState() => _BlinkingLiveDotState();
}

class _BlinkingLiveDotState extends State<_BlinkingLiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              "LIVE",
              style: TextStyle(
                color: Colors.black,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de progression animée sous les matchs en direct
class _LiveBar extends StatefulWidget {
  final Color color;
  const _LiveBar({required this.color});
  @override
  State<_LiveBar> createState() => _LiveBarState();
}

class _LiveBarState extends State<_LiveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => LinearProgressIndicator(
        value: _anim.value,
        backgroundColor: Colors.white.withOpacity(0.04),
        color: widget.color,
        minHeight: 2,
      ),
    );
  }
}
