import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/soccer_field_widget.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? liveData;
  List<dynamic> matchEvents = [];
  RealtimeChannel? _matchChannel;
  RealtimeChannel? _eventsChannel;
  int activeTab = 0;
  Timer? _realtimeClock;
  int _currentSeconds = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatchInitialData();
    _fetchMatchEvents();
    _initSupabaseRealtime();
    _startClock();
  }

  // ── Helpers lecture colonnes dashboard ──────────────────────
  // Supporte team_a_name (dashboards) ET team1_name (ancien format)
  String get _teamAName =>
      liveData!['team_a_name']?.toString() ??
      liveData!['team1_name']?.toString() ??
      'ÉQUIPE A';

  String get _teamBName =>
      liveData!['team_b_name']?.toString() ??
      liveData!['team2_name']?.toString() ??
      'ÉQUIPE B';

  String get _teamALogo =>
      liveData!['team_a_logo']?.toString() ??
      liveData!['team1_logo']?.toString() ??
      '';

  String get _teamBLogo =>
      liveData!['team_b_logo']?.toString() ??
      liveData!['team2_logo']?.toString() ??
      '';

  // Score : d'abord score1/score2 (football direct),
  // sinon dans le JSONB score.setsWon (volleyball),
  // sinon dans score JSONB red/blue (boxe/mma)
  int get _scoreA {
    if (liveData!['score1'] != null) {
      return int.tryParse(liveData!['score1'].toString()) ?? 0;
    }
    final sc = liveData!['score'];
    if (sc is Map) {
      if (sc['setsWon'] is List) return (sc['setsWon'] as List)[0] ?? 0;
      if (sc['red'] != null) return int.tryParse(sc['red'].toString()) ?? 0;
    }
    return 0;
  }

  int get _scoreB {
    if (liveData!['score2'] != null) {
      return int.tryParse(liveData!['score2'].toString()) ?? 0;
    }
    final sc = liveData!['score'];
    if (sc is Map) {
      if (sc['setsWon'] is List) return (sc['setsWon'] as List)[1] ?? 0;
      if (sc['blue'] != null) return int.tryParse(sc['blue'].toString()) ?? 0;
    }
    return 0;
  }

  // ── Chargement ───────────────────────────────────────────────
  Future<void> _fetchMatchInitialData() async {
    try {
      final data = await supabase
          .from('matches')
          .select('*')
          .eq('id', widget.matchId)
          .single();
      if (mounted) {
        setState(() {
          liveData = data;
          _parseInitialTime();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement match: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMatchEvents() async {
    try {
      final data = await supabase
          .from('events')
          .select('*')
          .eq('match_id', widget.matchId)
          .order('id', ascending: false);
      if (mounted) setState(() => matchEvents = data);
    } catch (e) {
      debugPrint("❌ Erreur events: $e");
    }
  }

  void _parseInitialTime() {
    if (liveData == null) return;
    String timeStr = liveData!['time']?.toString() ?? "00:00";
    List<String> parts = timeStr.split(':');
    if (parts.length == 2) {
      _currentSeconds =
          (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
  }

  void _startClock() {
    _realtimeClock?.cancel();
    _realtimeClock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && liveData != null && liveData!['is_timer_active'] == true) {
        setState(() {
          _currentSeconds++;
          int mins = _currentSeconds ~/ 60;
          int secs = _currentSeconds % 60;
          liveData!['time'] =
              "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
        });
      }
    });
  }

  void _initSupabaseRealtime() {
    _matchChannel = supabase
        .channel('match_updates_${widget.matchId}')
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
            if (mounted && payload.newRecord.isNotEmpty) {
              setState(() {
                liveData = {...liveData!, ...payload.newRecord};
                _parseInitialTime();
              });
            }
          },
        )
        .subscribe();

    _eventsChannel = supabase
        .channel('event_updates_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) => _fetchMatchEvents(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeClock?.cancel();
    if (_matchChannel != null) supabase.removeChannel(_matchChannel!);
    if (_eventsChannel != null) supabase.removeChannel(_eventsChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || liveData == null) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          liveData!['stadium']?.toString().toUpperCase() ?? "FECAAPP LIVE",
          style: const TextStyle(
            color: Color(0xFF00FF85),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildScoreHeader(),
          _buildTabs(),
          Expanded(child: _buildActiveContent()),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    bool isLive = liveData!['is_timer_active'] == true;
    String extra = liveData!['extra_time']?.toString() ?? "0";
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      child: Column(
        children: [
          Row(
            children: [
              _teamHeader(_teamAName, _teamALogo),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      "$_scoreA - $_scoreB",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 50,
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLive
                              ? const Color(0xFF00FF85)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        "${liveData!['time'] ?? '00:00'}${extra != "0" ? " +$extra" : ""}",
                        style: TextStyle(
                          color: isLive
                              ? const Color(0xFF00FF85)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      liveData!['status']?.toString().toUpperCase() ?? "",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _teamHeader(_teamBName, _teamBLogo),
            ],
          ),
          _buildTABRow(),
        ],
      ),
    );
  }

  Widget _teamHeader(String name, String logo) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white10,
            backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
            child: logo.isEmpty
                ? const Icon(Icons.shield, color: Colors.white24)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            name.toUpperCase(),
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

  Widget _buildTABRow() {
    List p1 = liveData!['pen1'] ?? [];
    List p2 = liveData!['pen2'] ?? [];
    if (p1.isEmpty && p2.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDots(p1),
          const Text(
            "TIRS AU BUT",
            style: TextStyle(
              color: Color(0xFF00FF85),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          _buildDots(p2),
        ],
      ),
    );
  }

  Widget _buildDots(List pens) {
    return Row(
      children: pens
          .map(
            (s) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s == true ? const Color(0xFF00FF85) : Colors.redAccent,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTabs() {
    List<String> labels = ["STATS", "ÉVÉNEMENTS", "LINEUP"];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: labels
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
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildActiveContent() {
    switch (activeTab) {
      case 0:
        return _buildStats();
      case 1:
        return _buildEvents();
      case 2:
        return _buildLineup();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStats() {
    final stats = liveData!['stats'] is Map ? liveData!['stats'] as Map : {};
    final List<Map<String, String>> statRows = [
      {'key': 'possession', 'label': 'POSSESSION (%)'},
      {'key': 'tirscadres', 'label': 'TIRS CADRÉS'},
      {'key': 'tirsoff', 'label': 'TIRS NON CADRÉS'},
      {'key': 'fautes', 'label': 'FAUTES'},
      {'key': 'horsjeu', 'label': 'HORS-JEU'},
      {'key': 'corners', 'label': 'CORNERS'},
      {'key': 'jaunes', 'label': 'CARTONS JAUNES'},
      {'key': 'rouges', 'label': 'CARTONS ROUGES'},
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      children: statRows.map((stat) {
        final values = stats[stat['key']] ?? [0, 0];
        double v1 = double.tryParse(values[0].toString()) ?? 0;
        double v2 = double.tryParse(values[1].toString()) ?? 0;
        double total = v1 + v2;
        double ratio1 = total == 0 ? 0.5 : v1 / total;
        double ratio2 = total == 0 ? 0.5 : v2 / total;
        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${v1.toInt()}${stat['key'] == 'possession' ? '%' : ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    stat['label']!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "${v2.toInt()}${stat['key'] == 'possession' ? '%' : ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 5,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (ratio1 * 1000).toInt(),
                        child: Container(color: const Color(0xFF00FF85)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: (ratio2 * 1000).toInt(),
                        child: Container(color: Colors.white10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEvents() {
    if (matchEvents.isEmpty) {
      return const Center(
        child: Text(
          "AUCUN ÉVÉNEMENT POUR LE MOMENT",
          style: TextStyle(
            color: Colors.white10,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: matchEvents.length,
      padding: const EdgeInsets.all(25),
      itemBuilder: (c, i) {
        final e = matchEvents[i];
        bool isT1 = e['team'].toString() == "1";
        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            mainAxisAlignment: isT1
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (isT1) _buildEventIcon(e),
              if (isT1) const SizedBox(width: 15),
              Column(
                crossAxisAlignment: isT1
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (!isT1)
                        Text(
                          "${e['time']}'",
                          style: const TextStyle(
                            color: Color(0xFF00FF85),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      if (!isT1) const SizedBox(width: 8),
                      Text(
                        e['player']?.toString().toUpperCase() ?? "JOUEUR",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (isT1) const SizedBox(width: 8),
                      if (isT1)
                        Text(
                          "${e['time']}'",
                          style: const TextStyle(
                            color: Color(0xFF00FF85),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  if (e['type'] == 'sub')
                    Text(
                      "▲ EN : ${e['player']} / ▼ HS : ${e['assist']}",
                      style: const TextStyle(
                        color: Color(0xFF00FF85),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (e['assist'] != null &&
                      e['assist'].toString().isNotEmpty)
                    Text(
                      "PASSE DE : ${e['assist']}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
              if (!isT1) const SizedBox(width: 15),
              if (!isT1) _buildEventIcon(e),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventIcon(Map e) {
    String type = e['type']?.toString().toLowerCase() ?? "";
    if (type.contains("goal")) {
      return const Text("⚽", style: TextStyle(fontSize: 20));
    }
    if (type.contains("yellow")) return _card(Colors.yellow);
    if (type.contains("red")) return _card(Colors.red);
    if (type.contains("sub")) {
      return const Icon(
        Icons.swap_vert_circle,
        color: Color(0xFF00FF85),
        size: 22,
      );
    }
    return const Icon(
      Icons.access_time_filled,
      color: Colors.white24,
      size: 20,
    );
  }

  Widget _card(Color c) => Container(
    width: 11,
    height: 15,
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 5)],
    ),
  );

  Widget _buildLineup() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        SoccerFieldWidget(
          lineup1: _parseLineup(liveData?['lineup1']),
          lineup2: _parseLineup(liveData?['lineup2']),
          positions: liveData?['positions'],
          stadium: (liveData?['stadium'] ?? "STADE NON DÉFINI").toString(),
        ),
        _buildInfoSection(
          "📊 FORMATION",
          liveData!['formation1']?.toString() ?? "-",
          liveData!['formation2']?.toString() ?? "-",
        ),
        _buildInfoSection(
          "🛡️ XI ENTRANTS",
          _formatList(liveData!['lineup1']),
          _formatList(liveData!['lineup2']),
        ),
        _buildInfoSection(
          "🔄 REMPLAÇANTS",
          _formatList(liveData!['subs1']),
          _formatList(liveData!['subs2']),
        ),
        _buildInfoSection(
          "🏥 BLESSÉS / ABSENTS",
          _formatList(liveData!['hurt1']),
          _formatList(liveData!['hurt2']),
        ),
        _buildInfoSection(
          "👔 ENTRAÎNEUR",
          liveData!['coach1']?.toString() ?? "-",
          liveData!['coach2']?.toString() ?? "-",
        ),
        _buildSingleInfoSection(
          "⚖️ ARBITRE PRINCIPAL",
          liveData!['referee_main']?.toString() ?? "-",
        ),
        _buildSingleInfoSection(
          "🚩 ARBITRES DE TOUCHES",
          liveData!['referees_side']?.toString() ?? "-",
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  String _formatList(dynamic data) {
    if (data == null) return "-";
    if (data is List) return data.join('\n');
    return data.toString();
  }

  List<String> _parseLineup(dynamic data) {
    if (data == null) return [];
    if (data is List) return data.map((e) => e.toString()).toList();
    if (data is String) {
      return data.split('\n').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Widget _buildInfoSection(String title, String v1, String v2) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00FF85),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const Divider(color: Colors.white10, height: 25),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  v1,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  v2,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleInfoSection(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00FF85),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
