import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MmaMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const MmaMatchDetailScreen({super.key, required this.matchId});

  @override
  State<MmaMatchDetailScreen> createState() => _MmaMatchDetailScreenState();
}

class _MmaMatchDetailScreenState extends State<MmaMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0; // 0: COMBAT  1: SCORECARD  2: STATS  3: RÈGLES

  static const Color kGreen = Color(0xFF00FF85);
  static const Color kRed = Color(0xFFFF2D2D);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  Timer? _timer;
  int _timerSeconds = 300;

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
        _parseTimer(data['timer']);
        isLoading = false;
      });
      if (data['is_timer_active'] == true) _startTimer();
    }
  }

  void _parseTimer(String? t) {
    if (t == null) return;
    final p = t.split(':');
    if (p.length == 2) _timerSeconds = int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _timerSeconds > 0 &&
          matchData?['is_timer_active'] == true) {
        setState(() {
          _timerSeconds--;
          final m = _timerSeconds ~/ 60;
          final s = _timerSeconds % 60;
          matchData!['timer'] =
              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _initRealtime() {
    supabase
        .channel('mma_${widget.matchId}')
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
                _parseTimer(payload.newRecord['timer']);
              });
              if (payload.newRecord['is_timer_active'] == true) {
                _startTimer();
              } else {
                _timer?.cancel();
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _score {
    final r = matchData!['score'];
    return r is Map
        ? Map<String, dynamic>.from(r)
        : {'red': 0, 'blue': 0, 'rounds': []};
  }

  Map<String, dynamic> get _stats {
    final r = matchData!['stats'];
    return r is Map
        ? Map<String, dynamic>.from(r)
        : {
            'strikes': [0, 0],
            'takedowns': [0, 0],
            'submissions': [0, 0],
            'groundTime': [0, 0],
            'significantStrikes': [0, 0],
          };
  }

  List<dynamic> get _events => matchData!['events'] as List<dynamic>? ?? [];
  List<dynamic> get _rounds => (_score['rounds'] as List<dynamic>?) ?? [];

  int get _redTotal =>
      _rounds.fold(0, (s, r) => s + ((r is Map ? r['red'] ?? 0 : 0) as int));
  int get _blueTotal =>
      _rounds.fold(0, (s, r) => s + ((r is Map ? r['blue'] ?? 0 : 0) as int));

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ?? 'MMA',
          style: const TextStyle(
            color: kGreen,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (matchData!['weight_class'] != null)
            _appBarChip(
              matchData!['weight_class'].toString().toUpperCase(),
              kGreen,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildOctagonHeader(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // OCTAGON HEADER
  // ──────────────────────────────────────────────────────────
  Widget _buildOctagonHeader() {
    final isLive = matchData!['is_live'] == true;
    final timer = matchData!['timer']?.toString() ?? '5:00';
    final curRound = matchData!['current_round'] ?? 1;
    final totRounds = matchData!['total_rounds'] ?? 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          // META
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip('ROUND $curRound / $totRounds', kGreen),
              const SizedBox(width: 8),
              _chip(
                matchData!['weight_class']?.toString() ?? '',
                Colors.white24,
              ),
              if (matchData!['title2'] != null) ...[
                const SizedBox(width: 8),
                _chip('🏆 TITRE', kGold),
              ],
              if (isLive) ...[const SizedBox(width: 8), _liveBadge()],
            ],
          ),
          const SizedBox(height: 14),

          // FIGHTERS
          Row(
            children: [
              Expanded(
                child: _fighterSide(
                  name: matchData!['team1_name'],
                  record: matchData!['fighter_red_record'],
                  country: matchData!['fighter_red_country'],
                  stance: matchData!['fighter_red_stance'],
                  photo: matchData!['fighter_red_photo'],
                  color: kRed,
                  label: '🔴 COIN ROUGE',
                ),
              ),
              _scoreCenter(_redTotal, _blueTotal, timer, isLive, curRound),
              Expanded(
                child: _fighterSide(
                  name: matchData!['team2_name'],
                  record: matchData!['fighter_blue_record'],
                  country: matchData!['fighter_blue_country'],
                  stance: matchData!['fighter_blue_stance'],
                  photo: matchData!['fighter_blue_photo'],
                  color: kBlue,
                  label: '🔵 COIN BLEU',
                  rtl: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fighterSide({
    required String? name,
    required String? record,
    required String? country,
    required String? stance,
    required String? photo,
    required Color color,
    required String label,
    bool rtl = false,
  }) {
    final cross = rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.sports_mma, color: color, size: 30),
              )
            : Icon(Icons.sports_mma, color: color, size: 30),
      ),
    );

    final info = Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name?.toUpperCase() ?? '—',
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (record != null)
          Text(
            record,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (country != null)
          Text(
            country,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        if (stance != null)
          Text(
            stance.toUpperCase(),
            style: const TextStyle(color: Colors.white24, fontSize: 8),
          ),
      ],
    );

    return rtl
        ? Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              avatar,
            ],
          )
        : Row(
            children: [
              avatar,
              const SizedBox(width: 8),
              Expanded(child: info),
            ],
          );
  }

  Widget _scoreCenter(int red, int blue, String timer, bool isLive, int round) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$red',
                style: const TextStyle(
                  color: kRed,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(color: Colors.white24, fontSize: 26),
                ),
              ),
              Text(
                '$blue',
                style: const TextStyle(
                  color: kBlue,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLive ? kGreen.withOpacity(0.1) : Colors.white10,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isLive ? kGreen : Colors.white24),
            ),
            child: Text(
              timer,
              style: TextStyle(
                color: isLive ? kGreen : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            matchData!['status']?.toString().toUpperCase() ?? 'EN COURS',
            style: const TextStyle(color: Colors.white24, fontSize: 7),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TABS
  // ──────────────────────────────────────────────────────────
  Widget _buildTabs() {
    const tabs = ['COMBAT', 'SCORECARD', 'STATS', 'RÈGLES'];
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
                      color: activeTab == e.key ? kGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
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
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (activeTab) {
      case 0:
        return _buildCombatTab();
      case 1:
        return _buildScorecardTab();
      case 2:
        return _buildStatsTab();
      case 3:
        return _buildRulesTab();
      default:
        return const SizedBox();
    }
  }

  // ──────────────────────────────────────────────────────────
  // COMBAT TAB
  // ──────────────────────────────────────────────────────────
  Widget _buildCombatTab() {
    final st = _stats;
    final str = (st['strikes'] as List<dynamic>?) ?? [0, 0];
    final tds = (st['takedowns'] as List<dynamic>?) ?? [0, 0];
    final sub = (st['submissions'] as List<dynamic>?) ?? [0, 0];
    final sig = (st['significantStrikes'] as List<dynamic>?) ?? [0, 0];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // QUICK STATS GRID
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _miniStat(str[0].toString(), 'FRAPPES R.', kRed),
            _miniStat(str[1].toString(), 'FRAPPES B.', kBlue),
            _miniStat(tds[0].toString(), 'TAKEDOWN R.', kRed),
            _miniStat(tds[1].toString(), 'TAKEDOWN B.', kBlue),
          ],
        ),
        const SizedBox(height: 20),

        // WINNER BANNER (si combat terminé)
        if (matchData!['status'] == 'TERMINÉ' && matchData!['winner'] != null)
          _winnerBanner(),

        // EVENTS
        _sectionLabel('▸ ÉVÉNEMENTS DU COMBAT'),
        const SizedBox(height: 10),
        if (_events.isEmpty)
          _emptyMsg('Aucun événement enregistré')
        else
          ..._events.reversed.map((e) {
            final ev = e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{};
            final c = ev['corner']?.toString() == 'red'
                ? kRed
                : ev['corner']?.toString() == 'blue'
                ? kBlue
                : kGold;
            return _eventRow(ev, c);
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _miniStat(String val, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _winnerBanner() {
    final winner = matchData!['winner']?.toString() ?? '';
    final name = winner == 'red'
        ? matchData!['team1_name']
        : matchData!['team2_name'];
    final color = winner == 'red'
        ? kRed
        : winner == 'blue'
        ? kBlue
        : kGold;
    final lastEv = _events.isNotEmpty ? _events.last : null;
    final method = lastEv is Map ? lastEv['desc']?.toString() ?? '' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            '🏆 VAINQUEUR',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name?.toString().toUpperCase() ?? '—',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (method.isNotEmpty)
            Text(
              method,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _eventRow(Map<String, dynamic> ev, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        children: [
          Text(
            ev['time']?.toString() ?? '',
            style: const TextStyle(color: Colors.white24, fontSize: 9),
          ),
          const SizedBox(width: 10),
          Text(
            ev['icon']?.toString() ?? '🥊',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ev['desc']?.toString() ?? '',
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
  }

  // ──────────────────────────────────────────────────────────
  // SCORECARD TAB — 10 points Unified Rules
  // ──────────────────────────────────────────────────────────
  Widget _buildScorecardTab() {
    final totalRnds = matchData!['total_rounds'] ?? 3;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        matchData!['team1_name']?.toString() ?? 'ROUGE',
                        style: const TextStyle(
                          color: kRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text(
                      '10 POINTS',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        matchData!['team2_name']?.toString() ?? 'BLEU',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: kBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 20),

              ...List.generate(totalRnds, (i) {
                final r = i < _rounds.length && _rounds[i] is Map
                    ? Map<String, dynamic>.from(_rounds[i] as Map)
                    : <String, dynamic>{};
                final red = (r['red'] as int?) ?? 0;
                final blue = (r['blue'] as int?) ?? 0;
                final played = red > 0 || blue > 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.01),
                    border: const Border(
                      bottom: BorderSide(color: Colors.white10, width: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 55,
                        child: Text(
                          'ROUND ${i + 1}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          played ? '$red' : '—',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: played
                                ? (red > blue ? kGold : kRed)
                                : Colors.white12,
                            fontSize: played ? 18 : 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 30,
                        child: Text(
                          'VS',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white12, fontSize: 8),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          played ? '$blue' : '—',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: played
                                ? (blue > red ? kGold : kBlue)
                                : Colors.white12,
                            fontSize: played ? 18 : 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          played
                              ? (red > blue
                                    ? '🔴'
                                    : blue > red
                                    ? '🔵'
                                    : '➖')
                              : '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // TOTAL
              Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '$_redTotal',
                      style: const TextStyle(
                        color: kRed,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_blueTotal',
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // STATS TAB
  // ──────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    final st = _stats;
    final rows = [
      {
        'label': 'FRAPPES TOTALES',
        'vals': (st['strikes'] as List<dynamic>?) ?? [0, 0],
      },
      {
        'label': 'FRAPPES SIGNIFICATIVES',
        'vals': (st['significantStrikes'] as List<dynamic>?) ?? [0, 0],
      },
      {
        'label': 'TAKEDOWNS',
        'vals': (st['takedowns'] as List<dynamic>?) ?? [0, 0],
      },
      {
        'label': 'TENTATIVES SOUMISSION',
        'vals': (st['submissions'] as List<dynamic>?) ?? [0, 0],
      },
      {
        'label': 'TEMPS AU SOL (MIN)',
        'vals': (st['groundTime'] as List<dynamic>?) ?? [0, 0],
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
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
                      matchData!['team1_name']?.toString() ?? 'ROUGE',
                      style: const TextStyle(
                        color: kRed,
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
                      letterSpacing: 1,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      matchData!['team2_name']?.toString() ?? 'BLEU',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...rows.map((r) {
                final vals = r['vals'] as List<dynamic>;
                final v1 = (vals[0] as num).toDouble();
                final v2 = (vals[1] as num).toDouble();
                final total = v1 + v2;
                final ratio = total == 0 ? 0.5 : v1 / total;
                return _statBar(
                  vals[0].toString(),
                  r['label'] as String,
                  vals[1].toString(),
                  ratio,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBar(String v1, String label, String v2, double ratio) {
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
                    child: Container(color: kRed),
                  ),
                  Expanded(
                    flex: ((1 - ratio) * 100).round().clamp(1, 99),
                    child: Container(color: kBlue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // RÈGLES TAB
  // ──────────────────────────────────────────────────────────
  Widget _buildRulesTab() {
    final rules = [
      [
        '🏆',
        'SYSTÈME 10 POINTS (UNIFIED)',
        'Vainqueur du round = 10 pts. Perdant = 9 pts. Knockdown = 10-8. Deux knockdowns ou domination totale = 10-7.',
      ],
      [
        '⏱',
        'DURÉE DES ROUNDS',
        'Rounds de 5 minutes. 1 minute de repos. Combat non-titre = 3 rounds. Combat de titre = 5 rounds.',
      ],
      [
        '💥',
        'KO / TKO',
        'KO : Combattant inconscient. TKO : L\'arbitre stoppe le combat (protection, coin jette l\'éponge, combattant ne répond plus).',
      ],
      [
        '🤼',
        'SOUMISSION',
        'Tap-out sur le tapis ou l\'adversaire. Abandon verbal accepté. La prise doit être légale et appliquée correctement.',
      ],
      [
        '📋',
        'TYPES DE DÉCISION',
        'Unanime : 3 juges pour le même. Partagée : 2 pour A, 1 pour B. Majoritaire : 2 pour A, 1 nul. Match nul : scores égaux.',
      ],
      [
        '❌',
        'COUPS ILLÉGAUX',
        'Arrière de la tête, coups bas, morsure, coup d\'œil, colonne vertébrale. Pénalité = point déduit. Récidive = Disqualification.',
      ],
      [
        '⚖️',
        'CATÉGORIES DE POIDS',
        'Paille -52kg • Mouche -57kg • Coq -61kg • Plume -66kg • Léger -70kg • Super léger -77kg • Welter -84kg • Super welter -93kg • Lourd -120kg',
      ],
      [
        '🛡',
        'TECHNIQUES AUTORISÉES',
        'Poings, pieds, coudes, genoux debout / au sol. Projections. Jiu-jitsu brésilien. Lutte. Tout contact légal dans les zones autorisées.',
      ],
      [
        '🔢',
        'CRITÈRES DE SCORING',
        '1. Dommages causés (prioritaire) 2. Tentatives de finition 3. Takedowns + contrôle au sol 4. Agression et dominance générale',
      ],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: rules.map((r) => _ruleCard(r[0], r[1], r[2])).toList(),
    );
  }

  Widget _ruleCard(String icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGreen.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
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

  // ──────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      color: kGreen,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
    ),
  );

  Widget _liveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: kRed.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: kRed),
    ),
    child: const Text(
      '🔴 LIVE',
      style: TextStyle(color: kRed, fontSize: 8, fontWeight: FontWeight.w900),
    ),
  );

  Widget _appBarChip(String label, Color c) => Container(
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: c.withOpacity(0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900),
    ),
  );

  Widget _emptyMsg(String msg) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(
      child: Text(
        msg,
        style: const TextStyle(color: Colors.white24, fontSize: 10),
      ),
    ),
  );
}
