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
  int activeTab = 0; // 0: STATS, 1: JOUEURS
  Timer? _countDownTimer;
  int _currentSeconds = 720; // 12 minutes par défaut

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
    List<String> parts = timeStr.split(':');
    if (parts.length == 2) {
      _currentSeconds = (int.parse(parts[0]) * 60) + int.parse(parts[1]);
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
          int mins = _currentSeconds ~/ 60;
          int secs = _currentSeconds % 60;
          matchData!['time'] =
              "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
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
          child: CircularProgressIndicator(color: Color(0xFF00FF85)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ??
              "ÉLITE BASKETBALL",
          style: const TextStyle(
            color: Color(0xFF00FF85),
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
    bool isLive = matchData!['is_timer_active'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _teamInfo(matchData!['team1_name'], matchData!['team1_logo']),
          Column(
            children: [
              Text(
                "${matchData!['score1']} - ${matchData!['score2']}",
                style: const TextStyle(
                  color: Colors.white,
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
                  color: isLive
                      ? const Color(0xFF00FF85).withOpacity(0.1)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isLive ? const Color(0xFF00FF85) : Colors.white24,
                  ),
                ),
                child: Text(
                  matchData!['time'] ?? "12:00",
                  style: TextStyle(
                    color: isLive ? const Color(0xFF00FF85) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                matchData!['status']?.toString().toUpperCase() ?? "1ER QUART",
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          _teamInfo(matchData!['team2_name'], matchData!['team2_logo']),
        ],
      ),
    );
  }

  Widget _teamInfo(String? name, String? logo) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white10,
            backgroundImage: logo != null ? NetworkImage(logo) : null,
          ),
          const SizedBox(height: 8),
          Text(
            name?.toUpperCase() ?? "TEAM",
            textAlign: TextAlign.center,
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
    final q1 = matchData!['q1'] ?? [0, 0];
    final q2 = matchData!['q2'] ?? [0, 0];
    final q3 = matchData!['q3'] ?? [0, 0];
    final q4 = matchData!['q4'] ?? [0, 0];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _qCol("Q1", q1[0], q1[1]),
          _qCol("Q2", q2[0], q2[1]),
          _qCol("Q3", q3[0], q3[1]),
          _qCol("Q4", q4[0], q4[1]),
          _qCol(
            "TOT",
            matchData!['score1'],
            matchData!['score2'],
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
          "$s1",
          style: TextStyle(
            color: isBold ? const Color(0xFF00FF85) : Colors.white70,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          "$s2",
          style: TextStyle(
            color: isBold ? const Color(0xFF00FF85) : Colors.white70,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    List<String> tabs = ["STATS", "JOUEURS"];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
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
                      color: activeTab == e.key
                          ? const Color(0xFF00FF85)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: activeTab == e.key
                            ? Colors.black
                            : Colors.white38,
                        fontSize: 10,
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
    if (activeTab == 0) return _buildStats();
    if (activeTab == 1) return _buildLineup();
    return const SizedBox();
  }

  Widget _buildLineup() {
    final List<dynamic> lineup1 = matchData!['lineup1'] ?? [];
    final List<dynamic> lineup2 = matchData!['lineup2'] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _playerListColumn(
              matchData!['team1_name'],
              lineup1,
              const Color(0xFF00FF85),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _playerListColumn(
              matchData!['team2_name'],
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
    List<dynamic> players,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName?.toUpperCase() ?? "ÉQUIPE",
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Divider(color: Colors.white10),
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
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: const Text(
                    "N°",
                    style: TextStyle(color: Colors.white38, fontSize: 8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.toString(),
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
    final stats = matchData!['stats'] ?? {};
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
        final val = stats[s['key']] ?? [0, 0];
        double total =
            (double.tryParse(val[0].toString()) ?? 0) +
            (double.tryParse(val[1].toString()) ?? 0);
        double ratio = total == 0
            ? 0.5
            : (double.tryParse(val[0].toString()) ?? 0) / total;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${val[0]}",
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
                    "${val[1]}",
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
                color: const Color(0xFF00FF85),
                minHeight: 4,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
