import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoxeMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const BoxeMatchDetailScreen({super.key, required this.matchId});

  @override
  State<BoxeMatchDetailScreen> createState() => _BoxeMatchDetailScreenState();
}

class _BoxeMatchDetailScreenState extends State<BoxeMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0; // 0: COMBAT, 1: SCORECARD, 2: RÈGLES

  static const Color kGold = Color(0xFFFFB800);
  static const Color kRed = Color(0xFFFF2D2D);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  Timer? _timer;
  int _timerSeconds = 180;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _initRealtime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE & DATA ---

  Future<void> _fetchInitialData() async {
    try {
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
    } catch (e) {
      debugPrint('Error: $e');
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
        .channel('boxing_${widget.matchId}')
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
                matchData = {...?matchData, ...payload.newRecord};
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

  // Getters
  List<dynamic> get _events => matchData?['events'] as List<dynamic>? ?? [];
  List<dynamic> get _rounds =>
      (matchData?['score']?['rounds'] as List<dynamic>?) ?? [];
  int get _redTotal =>
      _rounds.fold(0, (s, r) => s + ((r is Map ? r['red'] ?? 0 : 0) as int));
  int get _blueTotal =>
      _rounds.fold(0, (s, r) => s + ((r is Map ? r['blue'] ?? 0 : 0) as int));

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kGold)),
      );
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ?? 'BOXE',
          style: const TextStyle(
            color: kGold,
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
              kGold,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildRingHeader(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildRingHeader() {
    final isLive = matchData!['is_live'] == true;
    final timer = matchData!['timer']?.toString() ?? '3:00';
    final currentRnd = matchData!['current_round'] ?? 1;
    final totalRnds = matchData!['total_rounds'] ?? 12;
    final knockRed = _events
        .where(
          (e) => e is Map && e['corner'] == 'red' && e['type'] == 'knockdown',
        )
        .length;
    final knockBlue = _events
        .where(
          (e) => e is Map && e['corner'] == 'blue' && e['type'] == 'knockdown',
        )
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip('ROUND $currentRnd / $totalRnds', kGold),
              const SizedBox(width: 8),
              if (isLive) _liveBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _boxerSide(
                  name: matchData!['team1_name'],
                  photo: matchData!['fighter_red_photo'],
                  color: kRed,
                  knockdowns: knockRed,
                ),
              ),
              _scoreCenter(_redTotal, _blueTotal, timer, isLive),
              Expanded(
                child: _boxerSide(
                  name: matchData!['team2_name'],
                  photo: matchData!['fighter_blue_photo'],
                  color: kBlue,
                  knockdowns: knockBlue,
                  rtl: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreCenter(int red, int blue, String timer, bool isLive) {
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
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(color: Colors.white24, fontSize: 24),
                ),
              ),
              Text(
                '$blue',
                style: const TextStyle(
                  color: kBlue,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isLive ? kRed : kBg3,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isLive ? timer : "FIN",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 40,
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: ['COMBAT', 'SCORECARD', 'RÈGLES'].asMap().entries.map((e) {
          final sel = activeTab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => activeTab = e.key),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? kGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
        return _buildRulesTab();
      default:
        return const SizedBox();
    }
  }

  // --- TABS CONTENT ---

  Widget _buildCombatTab() {
    final knockRed = _events
        .where(
          (e) => e is Map && e['corner'] == 'red' && e['type'] == 'knockdown',
        )
        .length;
    final knockBlue = _events
        .where(
          (e) => e is Map && e['corner'] == 'blue' && e['type'] == 'knockdown',
        )
        .length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          children: [
            _statBox('$_redTotal', 'TOTAL ROUGE', kRed),
            const SizedBox(width: 10),
            _statBox('$_blueTotal', 'TOTAL BLEU', kBlue),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('ÉVÉNEMENTS'),
        const SizedBox(height: 10),
        if (_events.isEmpty)
          _emptyMsg('Aucun événement')
        else
          ..._events.reversed.map(
            (e) => _eventRow(
              e is Map ? Map<String, dynamic>.from(e) : {},
              e['corner'] == 'red' ? kRed : kBlue,
            ),
          ),
      ],
    );
  }

  Widget _buildScorecardTab() {
    final totalRnds = matchData!['total_rounds'] ?? 12;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              ...List.generate(totalRnds, (i) {
                final r = i < _rounds.length && _rounds[i] is Map
                    ? Map<String, dynamic>.from(_rounds[i] as Map)
                    : <String, dynamic>{};
                final red = (r['red'] as int?) ?? 0;
                final blue = (r['blue'] as int?) ?? 0;
                return ListTile(
                  title: Text(
                    'ROUND ${i + 1}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$red',
                        style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$blue',
                        style: const TextStyle(
                          color: kBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '$_redTotal',
                      style: const TextStyle(
                        color: kRed,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'TOTAL',
                      style: TextStyle(color: Colors.white38),
                    ),
                    Text(
                      '$_blueTotal',
                      style: const TextStyle(
                        color: kBlue,
                        fontSize: 24,
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

  Widget _buildRulesTab() {
    final rules = [
      ['🥊', 'SYSTÈME 10 POINTS', 'Vainqueur round 10 pts. Perdant 9 pts.'],
      ['⏱', 'DURÉE', 'Rounds de 3 minutes.'],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: rules.map((r) => _ruleCard(r[0], r[1], r[2])).toList(),
    );
  }

  // --- HELPERS ---

  Widget _statBox(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
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
              style: const TextStyle(color: Colors.white38, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventRow(Map<String, dynamic> ev, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        ev['desc'] ?? '',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _ruleCard(String icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxerSide({
    required String? name,
    required String? photo,
    required Color color,
    required int knockdowns,
    bool rtl = false,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: ClipOval(
            child: (photo != null && photo.isNotEmpty)
                ? Image.network(photo, fit: BoxFit.cover)
                : Icon(Icons.person, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name?.toUpperCase() ?? '—',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(color: c, fontSize: 8)),
  );
  Widget _appBarChip(String text, Color c) => Padding(
    padding: const EdgeInsets.only(right: 15),
    child: Center(
      child: Text(text, style: TextStyle(color: c, fontSize: 10)),
    ),
  );
  Widget _liveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: kRed,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 7,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  Widget _sectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      color: kGold,
      fontSize: 10,
      fontWeight: FontWeight.w900,
    ),
  );
  Widget _emptyMsg(String msg) => Center(
    child: Text(msg, style: const TextStyle(color: Colors.white24)),
  );
}
