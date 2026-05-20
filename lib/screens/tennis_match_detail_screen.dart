import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TennisMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const TennisMatchDetailScreen({super.key, required this.matchId});

  @override
  State<TennisMatchDetailScreen> createState() =>
      _TennisMatchDetailScreenState();
}

class _TennisMatchDetailScreenState extends State<TennisMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0;

  static const Color kLime = Color(0xFFC8FF00);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kGold = Color(0xFFFFD700);

  // ✅ Helpers compatibles dashboard (team_a_name) ET ancien format (team1_name)
  String get _p1Name =>
      matchData!['team_a_name']?.toString() ??
      matchData!['team1_name']?.toString() ??
      'JOUEUR 1';

  String get _p2Name =>
      matchData!['team_b_name']?.toString() ??
      matchData!['team2_name']?.toString() ??
      'JOUEUR 2';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _initRealtime();
  }

  Future<void> _fetchInitialData() async {
    try {
      final data = await supabase
          .from('matches')
          .select('*')
          .eq('id', widget.matchId)
          .single();
      if (mounted)
        setState(() {
          matchData = data;
          isLoading = false;
        });
    } catch (e) {
      debugPrint('❌ Tennis match: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initRealtime() {
    supabase
        .channel('tennis_match_${widget.matchId}')
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
            if (mounted)
              setState(() => matchData = {...matchData!, ...payload.newRecord});
          },
        )
        .subscribe();
  }

  Map<String, dynamic> get _score {
    final raw = matchData!['score'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {
      'sets': List.generate(5, (_) => [0, 0]),
      'points': [0, 0],
      'currentSet': 0,
      'isTiebreak': false,
      'server': 'p1',
      'format': '3sets',
    };
  }

  Map<String, dynamic> get _stats {
    final raw = matchData!['stats'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {
      'aces': [0, 0],
      'doubleFautes': [0, 0],
      'firstServeIn': [0, 0],
      'firstServeWon': [0, 0],
      'breakPoints': [0, 0],
      'breakPointsConverted': [0, 0],
      'winners': [0, 0],
      'pointsTotal': [0, 0],
    };
  }

  List<dynamic> get _pointLog =>
      matchData!['point_log'] as List<dynamic>? ?? [];

  String _getPointLabel(int pts, bool isTiebreak) {
    if (isTiebreak) return '$pts';
    if (pts >= 4) return 'AV';
    return ['0', '15', '30', '40'][pts.clamp(0, 3)];
  }

  Color _getSurfaceColor(String? s) {
    switch (s) {
      case 'gazon':
        return const Color(0xFF00C850);
      case 'terre':
        return const Color(0xFFC85A00);
      case 'indoor':
        return const Color(0xFFAA77FF);
      default:
        return kBlue;
    }
  }

  String _getSurfaceLabel(String? s) {
    switch (s) {
      case 'gazon':
        return 'GAZON';
      case 'terre':
        return 'TERRE BATTUE';
      case 'indoor':
        return 'INDOOR';
      default:
        return 'DUR';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kLime)),
      );
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ?? 'TENNIS',
          style: const TextStyle(
            color: kLime,
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
              color: _getSurfaceColor(
                matchData!['surface']?.toString(),
              ).withOpacity(0.15),
              border: Border.all(
                color: _getSurfaceColor(matchData!['surface']?.toString()),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getSurfaceLabel(matchData!['surface']?.toString()),
              style: TextStyle(
                color: _getSurfaceColor(matchData!['surface']?.toString()),
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScoreBoard(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    final sc = _score;
    final isLive = matchData!['is_live'] == true;
    final format = sc['format']?.toString() ?? '3sets';
    final maxSets = format == '5sets' ? 5 : 3;
    final sets =
        (sc['sets'] as List<dynamic>?) ?? List.generate(5, (_) => [0, 0]);
    final points = (sc['points'] as List<dynamic>?) ?? [0, 0];
    final currentSet = sc['currentSet'] as int? ?? 0;
    final isTiebreak = sc['isTiebreak'] as bool? ?? false;
    final server = sc['server']?.toString() ?? 'p1';
    final surface = matchData!['surface']?.toString();
    final surfaceColor = _getSurfaceColor(surface);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header tour + surface
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    matchData!['tour']
                            ?.toString()
                            .replaceAll('_', ' ')
                            .toUpperCase() ??
                        '',
                    style: TextStyle(
                      color: surfaceColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kRed),
                        ),
                        child: const Text(
                          '🔴 LIVE',
                          style: TextStyle(
                            color: kRed,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isTiebreak ? 'TIE-BREAK' : 'SET ${currentSet + 1}',
                      style: TextStyle(
                        color: isTiebreak ? kGold : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sets header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                ...List.generate(
                  maxSets,
                  (i) => Expanded(
                    child: Text(
                      'S${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 55,
                  child: Text(
                    'JEU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kLime,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Player rows
          ...List.generate(2, (pi) {
            // ✅ Utilise les helpers _p1Name/_p2Name
            final name = pi == 0 ? _p1Name : _p2Name;
            final country = pi == 0
                ? matchData!['p1_country']?.toString()
                : matchData!['p2_country']?.toString();
            final seed = pi == 0
                ? matchData!['p1_seed']
                : matchData!['p2_seed'];
            final isServing = server == (pi == 0 ? 'p1' : 'p2');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isServing ? kLime.withOpacity(0.03) : Colors.transparent,
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.04)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          opacity: isServing ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: kLime,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      country ?? '',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (seed != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      seed.toString(),
                                      style: const TextStyle(
                                        color: kLime,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(maxSets, (si) {
                    final setList = sets[si];
                    final val = setList is List ? (setList[pi] ?? 0) : 0;
                    final opp = setList is List ? (setList[1 - pi] ?? 0) : 0;
                    final isCurrent = si == currentSet;
                    final isWon = !isCurrent && val > opp;
                    return Expanded(
                      child: Text(
                        '$val',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : isWon
                              ? kLime
                              : Colors.white24,
                          fontSize: isCurrent ? 18 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }),
                  SizedBox(
                    width: 55,
                    child: Text(
                      _getPointLabel((points[pi] as num).toInt(), isTiebreak),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isServing ? kLime : Colors.white54,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['SCORE', 'STATISTIQUES', 'HISTORIQUE'];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: activeTab == e.key ? kLime : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: activeTab == e.key
                              ? Colors.black
                              : Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
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
        return _buildScoreDetails();
      case 1:
        return _buildStats();
      case 2:
        return _buildHistory();
      default:
        return const SizedBox();
    }
  }

  Widget _buildScoreDetails() {
    final sc = _score;
    final format = sc['format']?.toString() ?? '3sets';
    final maxSets = format == '5sets' ? 5 : 3;
    final sets =
        (sc['sets'] as List<dynamic>?) ?? List.generate(5, (_) => [0, 0]);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '▸ DÉTAIL DES SETS',
                style: TextStyle(
                  color: kLime,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(flex: 2, child: SizedBox()),
                  ...List.generate(
                    maxSets,
                    (i) => Expanded(
                      child: Text(
                        'SET ${i + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(2, (pi) {
                final name = pi == 0 ? _p1Name : _p2Name; // ✅ helpers
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: TextStyle(
                            color: pi == 0 ? kLime : kBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...List.generate(maxSets, (si) {
                        final setList = sets[si];
                        final val = setList is List ? (setList[pi] ?? 0) : 0;
                        final opp = setList is List
                            ? (setList[1 - pi] ?? 0)
                            : 0;
                        return Expanded(
                          child: Text(
                            '$val',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: val > opp ? kGold : Colors.white38,
                              fontSize: 14,
                              fontWeight: val > opp
                                  ? FontWeight.w900
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildRulesCard(),
      ],
    );
  }

  Widget _buildRulesCard() {
    final format = _score['format']?.toString() ?? '3sets';
    final rules = format == '5sets'
        ? [
            '5 sets — meilleur de 5 (Grand Chelem)',
            'Tiebreak à 6-6 dans chaque set',
            'Tiebreak : 7 points minimum, écart de 2',
          ]
        : [
            '3 sets — meilleur de 3 (ATP/WTA standard)',
            'Tiebreak à 6-6 dans chaque set',
            'Avantage au 4e point si égalité',
          ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kLime.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '▸ FORMAT & RÈGLES ITF',
            style: TextStyle(
              color: kLime,
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
                    style: TextStyle(color: kLime, fontSize: 11),
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
    );
  }

  Widget _buildStats() {
    final stats = _stats;
    final rows = [
      {'key': 'aces', 'label': 'ACES'},
      {'key': 'doubleFautes', 'label': 'DOUBLES FAUTES'},
      {'key': 'firstServeIn', 'label': '1ER SERVICE IN'},
      {'key': 'firstServeWon', 'label': 'POINTS GAGNÉS 1ER SERV.'},
      {'key': 'breakPoints', 'label': 'BALLES DE BREAK'},
      {'key': 'breakPointsConverted', 'label': 'BREAKS RÉUSSIS'},
      {'key': 'winners', 'label': 'WINNERS'},
      {'key': 'pointsTotal', 'label': 'POINTS TOTAUX'},
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _p1Name,
                      style: const TextStyle(
                        color: kLime,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ), // ✅
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
                      _p2Name,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ), // ✅
                ],
              ),
              const SizedBox(height: 16),
              ...rows.map((s) {
                final val = stats[s['key']] as List<dynamic>? ?? [0, 0];
                final v1 = (val[0] as num).toDouble();
                final v2 = (val[1] as num).toDouble();
                final total = v1 + v2;
                final ratio = total == 0 ? 0.5 : v1 / total;
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${val[0]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              s['label']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${val[1]}',
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
                                flex: (ratio * 100).round(),
                                child: Container(color: kLime),
                              ),
                              Expanded(
                                flex: ((1 - ratio) * 100).round(),
                                child: Container(color: kBlue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    final log = _pointLog.reversed.toList();
    if (log.isEmpty)
      return const Center(
        child: Text(
          'AUCUN POINT JOUÉ',
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: log.length,
      itemBuilder: (_, i) {
        final point = log[i] is Map ? Map<String, dynamic>.from(log[i]) : {};
        final winner = point['winner']?.toString() ?? 'p1';
        final color = winner == 'p1' ? kLime : kBlue;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(7),
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: Row(
            children: [
              Text(
                point['time']?.toString() ?? '',
                style: const TextStyle(color: Colors.white24, fontSize: 9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  point['desc']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
