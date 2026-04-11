import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HandballMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const HandballMatchDetailScreen({super.key, required this.matchId});

  @override
  State<HandballMatchDetailScreen> createState() =>
      _HandballMatchDetailScreenState();
}

class _HandballMatchDetailScreenState extends State<HandballMatchDetailScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0;
  Timer? _gameTimer;
  int _currentSeconds = 0;

  final Color handColor = const Color(0xFF00FF85);
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _fetchInitialData();
    _initRealtime();
  }

  Future<void> _fetchInitialData() async {
    try {
      final data = await supabase
          .from('matches')
          .select('*, leagues(name)')
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
    } catch (e) {
      debugPrint("❌ Erreur Initial Data: $e");
    }
  }

  void _parseTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return;
    List<String> parts = timeStr.split(':');
    _currentSeconds = (int.parse(parts[0]) * 60) + int.parse(parts[1]);
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && matchData?['is_timer_active'] == true) {
        setState(() {
          _currentSeconds++;
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
        .channel('hand_match_${widget.matchId}')
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
                // On garde l'ancien matchData pour ne pas perdre l'objet 'leagues'
                final oldLeagues = matchData?['leagues'];
                matchData = {...matchData!, ...payload.newRecord};
                matchData!['leagues'] = oldLeagues;
                _parseTime(payload.newRecord['time']);
              });
              if (payload.newRecord['is_timer_active'] == true) {
                _startTimer();
              } else {
                _gameTimer?.cancel();
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Center(child: CircularProgressIndicator(color: handColor)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matchData!['is_timer_active'] == true)
              ScaleTransition(
                scale: _pulseController,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: handColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              matchData!['leagues']?['name']?.toString().toUpperCase() ??
                  "FECAAPP HAND",
              style: TextStyle(
                color: handColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildScoreHeader(),
          _buildPeriodStats(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    bool isLive = matchData!['is_timer_active'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          _teamInfo(matchData!['team1_name'], matchData!['team1_logo']),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  child: Text(
                    "${matchData!['score1']} - ${matchData!['score2']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLive ? handColor.withOpacity(0.1) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLive ? handColor : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    matchData!['time'] ?? "00:00",
                    style: TextStyle(
                      color: isLive ? handColor : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  matchData!['status']?.toString().toUpperCase() ??
                      "EN ATTENTE",
                  style: TextStyle(
                    color: isLive ? handColor : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          _teamInfo(matchData!['team2_name'], matchData!['team2_logo']),
        ],
      ),
    );
  }

  Widget _teamInfo(String? name, String? logo) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: handColor.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF151515),
              backgroundImage: (logo != null && logo.isNotEmpty)
                  ? NetworkImage(logo)
                  : null,
              child: (logo == null || logo.isEmpty)
                  ? Icon(
                      Icons.shield,
                      color: handColor.withOpacity(0.5),
                      size: 30,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name?.toUpperCase() ?? "CLUB",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStats() {
    final List<dynamic> m1Raw = matchData!['m1'] ?? [0, 0];
    final List<dynamic> m2Raw = matchData!['m2'] ?? [0, 0];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _periodCol("M.T 1", "${m1Raw[0]} - ${m1Raw[1]}"),
          _periodDivider(),
          _periodCol("M.T 2", "${m2Raw[0]} - ${m2Raw[1]}"),
          _periodDivider(),
          _periodCol(
            "TOTAL",
            "${matchData!['score1']} - ${matchData!['score2']}",
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _periodDivider() =>
      Container(width: 1, height: 20, color: Colors.white10);

  Widget _periodCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? handColor : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: ["STATS", "SANCTIONS"].asMap().entries.map((e) {
          bool isSelected = activeTab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => activeTab = e.key),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? handColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
    return activeTab == 0 ? _buildStats() : _buildSanctions();
  }

  Widget _buildStats() {
    final stats = matchData!['stats'] ?? {};
    final scorers1 = Map<String, dynamic>.from(stats['scorers1'] ?? {});
    final scorers2 = Map<String, dynamic>.from(stats['scorers2'] ?? {});

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader("COMPARAISON ÉQUIPES"),
        _statRow(stats, '7m', 'JETS DE 7 MÈTRES'),
        _statRow(stats, 'saves', 'ARRÊTS GARDIEN'),
        _statRow(stats, 'turnovers', 'PERTES DE BALLE'),
        _statRow(stats, 'fastbreaks', 'CONTRE-ATTAQUES'),
        const SizedBox(height: 25),
        if (scorers1.isNotEmpty || scorers2.isNotEmpty) ...[
          _sectionHeader("BUTEURS"),
          _buildScorersList(scorers1, scorers2),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          color: handColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _statRow(Map stats, String key, String label) {
    final val = stats[key] ?? [0, 0];
    double ratio = (val[0] + val[1]) == 0 ? 0.5 : val[0] / (val[0] + val[1]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${val[0]}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                "${val[1]}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white10,
            color: handColor,
            minHeight: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildScorersList(Map<String, dynamic> s1, Map<String, dynamic> s2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: s1.entries
                .map((e) => _scorerTile(e.key, e.value as int, true))
                .toList(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: s2.entries
                .map((e) => _scorerTile(e.key, e.value as int, false))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _scorerTile(String name, int goals, bool isLeft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (!isLeft)
            Text(
              "$goals",
              style: TextStyle(
                color: handColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          if (!isLeft) const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: isLeft ? TextAlign.start : TextAlign.end,
            ),
          ),
          if (isLeft) const SizedBox(width: 8),
          if (isLeft)
            Text(
              "$goals",
              style: TextStyle(
                color: handColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSanctions() {
    final stats = matchData!['stats'] ?? {};
    final exclusions1 = List<String>.from(matchData!['exclusions1'] ?? []);
    final exclusions2 = List<String>.from(matchData!['exclusions2'] ?? []);
    final yellow1 = List<String>.from(stats['yellow_names1'] ?? []);
    final yellow2 = List<String>.from(stats['yellow_names2'] ?? []);
    final red1 = List<String>.from(stats['red_names1'] ?? []);
    final red2 = List<String>.from(stats['red_names2'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sanctionSection(
          "EXCLUSIONS 2 MINUTES",
          Colors.orange,
          exclusions1,
          exclusions2,
          prefix: "2' ",
        ),
        const SizedBox(height: 25),
        _sanctionSection("CARTONS JAUNES", Colors.yellow, yellow1, yellow2),
        const SizedBox(height: 25),
        _sanctionSection("CARTONS ROUGES", Colors.red, red1, red2),
      ],
    );
  }

  Widget _sanctionSection(
    String title,
    Color color,
    List<String> l1,
    List<String> l2, {
    String prefix = "",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 12, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: l1
                    .map((n) => _sanctionCard("$prefix$n", color, true))
                    .toList(),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                children: l2
                    .map((n) => _sanctionCard("$prefix$n", color, false))
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sanctionCard(String text, Color color, bool isLeft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          if (isLeft) _miniIndicator(color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: isLeft ? TextAlign.start : TextAlign.end,
            ),
          ),
          if (!isLeft) const SizedBox(width: 6),
          if (!isLeft) _miniIndicator(color),
        ],
      ),
    );
  }

  Widget _miniIndicator(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
