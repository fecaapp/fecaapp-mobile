import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BasketballMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const BasketballMatchDetailScreen({super.key, required this.matchId});

  @override
  State<BasketballMatchDetailScreen> createState() =>
      _BasketballMatchDetailScreenState();
}

class _BasketballMatchDetailScreenState
    extends State<BasketballMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0;
  Timer? _countDownTimer;
  int _currentSeconds = 720;

  static const Color _sportColor = Color(0xFFFFA500);

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
        _parseTime(data['time']);
        isLoading = false;
      });
      if (data['is_timer_active'] == true) _startTimer();
    }
  }

  void _parseTime(String? timeStr) {
    if (timeStr == null) return;
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      _currentSeconds =
          (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
  }

  void _startTimer() {
    _countDownTimer?.cancel();
    _countDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted &&
          _currentSeconds > 0 &&
          matchData?['is_timer_active'] == true) {
        setState(() {
          _currentSeconds--;
          final mins = _currentSeconds ~/ 60;
          final secs = _currentSeconds % 60;
          matchData!['time'] =
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _initRealtime() {
    supabase
        .channel('basket_match_${widget.matchId}')
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
                _parseTime(payload.newRecord['time']);
              });
              if (payload.newRecord['is_timer_active'] == true) {
                _startTimer();
              } else {
                _countDownTimer?.cancel();
              }
            }
          },
        )
        .subscribe();
  }

  // ── Parser robuste pour lineup (String ou List) ────────────────
  List<String> _parseLineup(dynamic raw) {
    if (raw == null) return [];
    // Déjà une liste
    if (raw is List) return raw.map((e) => e.toString()).toList();
    // String séparée par virgules (venant du textarea dashboard)
    if (raw is String) {
      if (raw.trim().isEmpty) return [];
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  void dispose() {
    _countDownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFA500)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ??
              'ÉLITE BASKETBALL',
          style: const TextStyle(
            color: _sportColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildScoreHeader(),
          _buildQuarterTable(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    final bool isLive = matchData!['is_timer_active'] == true;
    final bool isLocked = matchData!['is_locked'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(bottom: BorderSide(color: _sportColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _teamInfo(
            matchData!['team_a_name'] ?? matchData!['team1_name'],
            matchData!['team_a_logo'] ?? matchData!['team1_logo'],
          ),
          Column(
            children: [
              Text(
                '${matchData!['score1'] ?? 0} - ${matchData!['score2'] ?? 0}',
                style: TextStyle(
                  color: isLocked ? Colors.white38 : Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isLive ? _sportColor.withOpacity(0.1) : Colors.white10,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isLive ? _sportColor : Colors.white24,
                  ),
                ),
                child: Text(
                  matchData!['time'] ?? '12:00',
                  style: TextStyle(
                    color: isLive ? _sportColor : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                matchData!['status']?.toString().toUpperCase() ?? '1ER QUART',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          _teamInfo(
            matchData!['team_b_name'] ?? matchData!['team2_name'],
            matchData!['team_b_logo'] ?? matchData!['team2_logo'],
          ),
        ],
      ),
    );
  }

  Widget _teamInfo(String? name, String? logo) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _sportColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1A1A1A),
              backgroundImage: (logo != null && logo.isNotEmpty)
                  ? NetworkImage(logo)
                  : null,
              child: (logo == null || logo.isEmpty)
                  ? const Icon(
                      Icons.sports_basketball,
                      color: Colors.white24,
                      size: 24,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name?.toUpperCase() ?? 'TEAM',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterTable() {
    // Parser robuste pour les quarts (peuvent être List ou Map)
    List<dynamic> parseQ(dynamic raw) {
      if (raw == null) return [0, 0];
      if (raw is List) return raw.length >= 2 ? raw : [0, 0];
      return [0, 0];
    }

    final q1 = parseQ(matchData!['q1']);
    final q2 = parseQ(matchData!['q2']);
    final q3 = parseQ(matchData!['q3']);
    final q4 = parseQ(matchData!['q4']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _sportColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _qCol('Q1', q1[0], q1[1]),
          _qCol('Q2', q2[0], q2[1]),
          _qCol('Q3', q3[0], q3[1]),
          _qCol('Q4', q4[0], q4[1]),
          _qCol(
            'TOT',
            matchData!['score1'] ?? 0,
            matchData!['score2'] ?? 0,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _qCol(String label, dynamic s1, dynamic s2, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$s1',
          style: TextStyle(
            color: isBold ? _sportColor : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: isBold ? 14 : 12,
          ),
        ),
        Text(
          '$s2',
          style: TextStyle(
            color: isBold ? _sportColor : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: isBold ? 14 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    const tabs = ['STATS', 'JOUEURS'];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final isActive = activeTab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => activeTab = e.key),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? _sportColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white38,
                    fontSize: 10,
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
    if (activeTab == 0) return _buildStats();
    if (activeTab == 1) return _buildLineup();
    return const SizedBox();
  }

  Widget _buildLineup() {
    // ✅ FIX : parser robuste — accepte String ou List
    final List<String> lineup1 = _parseLineup(
      matchData!['lineup1'] ?? matchData!['lineup_a'],
    );
    final List<String> lineup2 = _parseLineup(
      matchData!['lineup2'] ?? matchData!['lineup_b'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _playerListColumn(
              matchData!['team_a_name'] ?? matchData!['team1_name'],
              lineup1,
              _sportColor,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _playerListColumn(
              matchData!['team_b_name'] ?? matchData!['team2_name'],
              lineup2,
              Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerListColumn(
    String? teamName,
    List<String> players,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName?.toUpperCase() ?? 'ÉQUIPE',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Divider(color: color.withOpacity(0.2)),
        if (players.isEmpty)
          Text(
            'Aucun joueur',
            style: TextStyle(color: color.withOpacity(0.3), fontSize: 11),
          ),
        ...players.map(
          (p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.sports_basketball,
                  size: 16,
                  color: color.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final stats = matchData!['stats'];
    // Parser robuste pour les stats
    Map<String, dynamic> statsMap = {};
    if (stats is Map) {
      statsMap = Map<String, dynamic>.from(stats);
    }

    final rows = [
      {'key': '3pts', 'label': 'TIRS À 3 POINTS'},
      {'key': '2pts', 'label': 'TIRS À 2 POINTS'},
      {'key': 'ft', 'label': 'LANCERS FRANCS'},
      {'key': 'rebounds', 'label': 'REBONDS'},
      {'key': 'assists', 'label': 'PASSES DÉCISIVES'},
      {'key': 'fouls', 'label': 'FAUTES D\'ÉQUIPE'},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      children: rows.map((s) {
        final raw = statsMap[s['key']];
        final List<dynamic> val = (raw is List && raw.length >= 2)
            ? raw
            : [0, 0];
        final double v0 = double.tryParse(val[0].toString()) ?? 0;
        final double v1 = double.tryParse(val[1].toString()) ?? 0;
        final double total = v0 + v1;
        final double ratio = total == 0 ? 0.5 : v0 / total;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
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
                    ),
                  ),
                  Text(
                    s['label']!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${val[1]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white10,
                color: _sportColor,
                minHeight: 4,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
