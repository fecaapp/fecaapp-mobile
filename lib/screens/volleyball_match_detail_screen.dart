import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VolleyballMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const VolleyballMatchDetailScreen({super.key, required this.matchId});

  @override
  State<VolleyballMatchDetailScreen> createState() =>
      _VolleyballMatchDetailScreenState();
}

class _VolleyballMatchDetailScreenState
    extends State<VolleyballMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0; // 0: SCORE, 1: STATS, 2: COMPOSITION

  static const Color kPurple = Color(0xFF9B59FF);
  static const Color kCyan = Color(0xFF00D1FF);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kGreen = Color(0xFF00FF85);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _initRealtime();
  }

  Future<void> _fetchInitialData() async {
    final data = await supabase
        .from('matches')
        .select('*')
        .eq('id', widget.matchId)
        .single();
    if (mounted) {
      setState(() {
        matchData = data;
        isLoading = false;
      });
    }
  }

  void _initRealtime() {
    supabase
        .channel('vb_match_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.matchId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                matchData = {...matchData!, ...payload.newRecord};
              });
            }
          },
        )
        .subscribe();
  }

  Map<String, dynamic> get _score {
    final raw = matchData!['score'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {
      'sets': List.generate(5, (_) => [0, 0]),
      'currentSet': 0,
      'setsWon': [0, 0],
      'points': [0, 0],
      'server': 'p1',
      'timeouts': [2, 2],
    };
  }

  Map<String, dynamic> get _stats {
    final raw = matchData!['stats'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {
      'aces': [0, 0],
      'blocks': [0, 0],
      'attacks': [0, 0],
      'errors': [0, 0],
      'serves': [0, 0],
      'digs': [0, 0],
      'pointsTotal': [0, 0],
    };
  }

  bool get _isBeach => matchData!['match_type']?.toString() == 'beach';

  int get _maxSets => _isBeach ? 3 : 5;
  int get _setsToWin => _isBeach ? 2 : 3;

  int _setThreshold(int setIndex) {
    if (_isBeach) return setIndex == 2 ? 15 : 21;
    return setIndex == 4 ? 15 : 25;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kPurple)),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ?? 'VOLLEYBALL',
          style: const TextStyle(
            color: kPurple,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kPurple.withOpacity(0.1),
              border: Border.all(color: kPurple.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _isBeach ? 'BEACH 2×2' : 'INDOOR 6×6',
              style: const TextStyle(
                color: kPurple,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScoreHeader(),
          _buildSetDetailTable(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ============================================================
  // SCORE HEADER
  // ============================================================
  Widget _buildScoreHeader() {
    final sc = _score;
    final isLive = matchData!['is_live'] == true;
    final setsWon = (sc['setsWon'] as List<dynamic>?) ?? [0, 0];
    final points = (sc['points'] as List<dynamic>?) ?? [0, 0];
    final currentSet = sc['currentSet'] as int? ?? 0;
    final server = sc['server']?.toString() ?? 'p1';
    final timeouts = (sc['timeouts'] as List<dynamic>?) ?? [2, 2];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _teamInfo(
                matchData!['team1_name'],
                matchData!['team1_logo'],
                (setsWon[0] as num).toInt(),
                server == 'p1',
                kPurple,
                (timeouts[0] as num).toInt(),
              ),
              // CENTER
              Column(
                children: [
                  // Points du set en cours
                  Text(
                    '${points[0]}  —  ${points[1]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isLive
                          ? kPurple.withOpacity(0.12)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLive ? kPurple : Colors.white24,
                      ),
                    ),
                    child: Text(
                      isLive ? '🔴 LIVE — SET ${currentSet + 1}' : 'TERMINÉ',
                      style: TextStyle(
                        color: isLive ? kPurple : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OBJECTIF : ${_setThreshold(currentSet)} pts',
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ],
              ),
              _teamInfo(
                matchData!['team2_name'],
                matchData!['team2_logo'],
                (setsWon[1] as num).toInt(),
                server == 'p2',
                kCyan,
                (timeouts[1] as num).toInt(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamInfo(
    String? name,
    String? logo,
    int setsWon,
    bool isServing,
    Color color,
    int timeoutsLeft,
  ) {
    return SizedBox(
      width: 85,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: logo != null ? NetworkImage(logo) : null,
                child: logo == null
                    ? Icon(Icons.sports_volleyball, color: color, size: 26)
                    : null,
              ),
              if (isServing)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name?.toUpperCase() ?? 'ÉQUIPE',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$setsWon',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'SETS',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // TIMEOUTS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (i) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < timeoutsLeft ? color : Colors.white12,
                ),
              ),
            ),
          ),
          Text(
            'T.M.',
            style: const TextStyle(color: Colors.white24, fontSize: 7),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETS TABLE
  // ============================================================
  Widget _buildSetDetailTable() {
    final sc = _score;
    final sets =
        (sc['sets'] as List<dynamic>?) ?? List.generate(5, (_) => [0, 0]);
    final currentSet = sc['currentSet'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...List.generate(_maxSets, (i) {
            final setList = sets[i];
            final s1 = setList is List ? setList[0] ?? 0 : 0;
            final s2 = setList is List ? setList[1] ?? 0 : 0;
            final isCurrent = i == currentSet;
            final wonP1 = !isCurrent && s1 > s2;
            final wonP2 = !isCurrent && s2 > s1;
            return _setCol(
              'SET ${i + 1}',
              s1,
              s2,
              isCurrent: isCurrent,
              wonP1: wonP1,
              wonP2: wonP2,
            );
          }),
          _setCol(
            'TOTAL',
            sc['setsWon']?[0] ?? 0,
            sc['setsWon']?[1] ?? 0,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _setCol(
    String label,
    dynamic s1,
    dynamic s2, {
    bool isCurrent = false,
    bool wonP1 = false,
    bool wonP2 = false,
    bool isTotal = false,
  }) {
    final color = isTotal
        ? kPurple
        : isCurrent
        ? kGold
        : Colors.white38;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? kGold : Colors.white24,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$s1',
          style: TextStyle(
            color: wonP1
                ? kPurple
                : isTotal
                ? kPurple
                : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
        Text(
          '$s2',
          style: TextStyle(
            color: wonP2
                ? kCyan
                : isTotal
                ? kCyan
                : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TABS
  // ============================================================
  Widget _buildTabs() {
    final tabs = ['SCORE', 'STATISTIQUES', 'COMPOSITION'];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => activeTab = e.key),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeTab == e.key ? kPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: activeTab == e.key
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (activeTab) {
      case 0:
        return _buildScoreInfo();
      case 1:
        return _buildStats();
      case 2:
        return _buildComposition();
      default:
        return const SizedBox();
    }
  }

  // ============================================================
  // SCORE INFO
  // ============================================================
  Widget _buildScoreInfo() {
    final sc = _score;
    final isBeach = _isBeach;
    final rules = isBeach
        ? [
            'Sets 1 et 2 : premier à 21 points, écart minimum de 2 points',
            'Set 3 (tie-break) : premier à 15 points, écart minimum de 2',
            'Changement de côté tous les 7 points au set 3',
            'Chaque équipe dispose de 2 temps morts par set',
          ]
        : [
            'Sets 1 à 4 : premier à 25 points, écart minimum de 2 points',
            'Set 5 (tie-break) : premier à 15 points, écart minimum de 2',
            'Temps morts techniques automatiques à 8 et 16 points (sets 1-4)',
            'Chaque équipe dispose de 2 temps morts par set',
            '6 joueurs sur le terrain, rotation dans le sens des aiguilles d\'une montre',
            'Le Libéro peut remplacer n\'importe quel joueur arrière sans limite',
          ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Stats rapides
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            _quickStat(
              'ACES',
              '${(_stats['aces'] as List?)?.fold(0, (a, b) => (a) + (b as int)) ?? 0}',
              kPurple,
            ),
            _quickStat(
              'BLOCKS',
              '${(_stats['blocks'] as List?)?.fold(0, (a, b) => (a) + (b as int)) ?? 0}',
              kCyan,
            ),
            _quickStat(
              'ATTAQUES',
              '${(_stats['attacks'] as List?)?.fold(0, (a, b) => (a) + (b as int)) ?? 0}',
              kGreen,
            ),
            _quickStat(
              'FAUTES',
              '${(_stats['errors'] as List?)?.fold(0, (a, b) => (a) + (b as int)) ?? 0}',
              kRed,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kPurple.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '▸ RÈGLES FIVB — ${isBeach ? "BEACH VOLLEY" : "INDOOR 6×6"}',
                style: const TextStyle(
                  color: kPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              ...rules.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: kPurple, fontSize: 11),
                      ),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickStat(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTIQUES
  // ============================================================
  Widget _buildStats() {
    final stats = _stats;
    final rows = [
      {'key': 'pointsTotal', 'label': 'POINTS TOTAUX'},
      {'key': 'aces', 'label': 'ACES (SERVICE DIRECT)'},
      {'key': 'blocks', 'label': 'CONTRES (BLOCKS)'},
      {'key': 'attacks', 'label': 'ATTAQUES GAGNANTES'},
      {'key': 'digs', 'label': 'RÉCEPTIONS'},
      {'key': 'errors', 'label': 'FAUTES DIRECTES'},
      {'key': 'serves', 'label': 'SERVICES TENTÉS'},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      matchData!['team1_name']?.toString() ?? 'ÉQ.A',
                      style: const TextStyle(
                        color: kPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    'STATISTIQUES',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      matchData!['team2_name']?.toString() ?? 'ÉQ.B',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: kCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...rows.map((s) {
                final val = stats[s['key']] as List<dynamic>? ?? [0, 0];
                final v1 = (val[0] as num).toDouble();
                final v2 = (val[1] as num).toDouble();
                final total = v1 + v2;
                final ratio = total == 0 ? 0.5 : v1 / total;
                return _statRow('${val[0]}', s['label']!, '${val[1]}', ratio);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String v1, String label, String v2, double ratio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                v1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                v2,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: (ratio * 100).round().clamp(1, 99),
                    child: Container(color: kPurple),
                  ),
                  Expanded(
                    flex: ((1 - ratio) * 100).round().clamp(1, 99),
                    child: Container(color: kCyan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPOSITION
  // ============================================================
  Widget _buildComposition() {
    final lineup1 = matchData!['lineup1'] as List<dynamic>? ?? [];
    final lineup2 = matchData!['lineup2'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _lineupColumn(matchData!['team1_name'], lineup1, kPurple),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _lineupColumn(matchData!['team2_name'], lineup2, kCyan),
          ),
        ],
      ),
    );
  }

  Widget _lineupColumn(String? teamName, List<dynamic> players, Color color) {
    const positions = [
      'Pointu',
      'Passeur',
      'Central',
      'Libéro',
      'Réceptionneur',
      'Opposé',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName?.toUpperCase() ?? 'ÉQUIPE',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        Divider(color: color.withOpacity(0.2), thickness: 0.5),
        if (players.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Aucun joueur',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
          )
        else
          ...players.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final name = p is Map ? p['name']?.toString() : p.toString();
            final number = p is Map ? p['number']?.toString() : '${i + 1}';
            final position = p is Map
                ? p['position']?.toString()
                : positions[i % positions.length];
            final isLibero = p is Map && p['isLibero'] == true;
            final isCaptain = p is Map && p['captain'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: kBg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLibero
                      ? kGold.withOpacity(0.3)
                      : Colors.white.withOpacity(0.04),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLibero
                          ? kGold.withOpacity(0.15)
                          : color.withOpacity(0.12),
                      border: Border.all(
                        color: isLibero ? kGold : color.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      number ?? '${i + 1}',
                      style: TextStyle(
                        color: isLibero ? kGold : color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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
                            Expanded(
                              child: Text(
                                name ?? '—',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCaptain)
                              const Text(
                                ' ©',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          position ?? '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLibero)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: kGold.withOpacity(0.5)),
                      ),
                      child: const Text(
                        'L',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
