import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KarateMatchDetailScreen extends StatefulWidget {
  final String matchId;
  const KarateMatchDetailScreen({super.key, required this.matchId});

  @override
  State<KarateMatchDetailScreen> createState() =>
      _KarateMatchDetailScreenState();
}

class _KarateMatchDetailScreenState extends State<KarateMatchDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0; // 0: COMBAT  1: STATS  2: RÈGLES

  static const Color kRed = Color(0xFFFF0044);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kGreen = Color(0xFF00FF85);
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
        .channel('karate_${widget.matchId}')
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
        : {
            'aka': 0,
            'ao': 0,
            'penalties': {'aka': {}, 'ao': {}},
          };
  }

  List<dynamic> get _events => matchData!['events'] as List<dynamic>? ?? [];

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          matchData!['league_name']?.toString().toUpperCase() ?? 'KARATÉ',
          style: const TextStyle(
            color: kRed,
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
              kRed,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFightersHeader(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // FIGHTERS HEADER
  // ──────────────────────────────────────────────────────────
  Widget _buildFightersHeader() {
    final sc = _score;
    final akaScore = sc['aka'] ?? 0;
    final aoScore = sc['ao'] ?? 0;
    final isLive = matchData!['is_live'] == true;
    final timer = matchData!['timer']?.toString() ?? '3:00';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          // META ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip(
                matchData!['discipline']?.toString().toUpperCase() ?? 'KUMITE',
                kRed,
              ),
              const SizedBox(width: 8),
              _chip(
                matchData!['tour']?.toString().toUpperCase() ?? '',
                Colors.white24,
              ),
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
                  country: matchData!['fighter_aka_country'],
                  club: matchData!['fighter_aka_club'],
                  photo: matchData!['fighter_aka_photo'],
                  color: kRed,
                  label: '🔴 AKA',
                ),
              ),
              _scoreCenter(akaScore, aoScore, timer, isLive),
              Expanded(
                child: _fighterSide(
                  name: matchData!['team2_name'],
                  country: matchData!['fighter_ao_country'],
                  club: matchData!['fighter_ao_club'],
                  photo: matchData!['fighter_ao_photo'],
                  color: kBlue,
                  label: '🔵 AO',
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
    required String? country,
    required String? club,
    required String? photo,
    required Color color,
    required String label,
    bool rtl = false,
  }) {
    final cross = rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = Container(
      width: 58,
      height: 58,
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
                    Icon(Icons.sports_martial_arts, color: color, size: 28),
              )
            : Icon(Icons.sports_martial_arts, color: color, size: 28),
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
        if (country != null)
          Text(
            country,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        if (club != null)
          Text(
            club,
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

  Widget _scoreCenter(int aka, int ao, String timer, bool isLive) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$aka',
                style: const TextStyle(
                  color: kRed,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(color: Colors.white24, fontSize: 28),
                ),
              ),
              Text(
                '$ao',
                style: const TextStyle(
                  color: kBlue,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLive ? kRed.withOpacity(0.1) : Colors.white10,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isLive ? kRed : Colors.white24),
            ),
            child: Text(
              timer,
              style: TextStyle(
                color: isLive ? kRed : Colors.white,
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
    const tabs = ['COMBAT', 'STATS', 'RÈGLES'];
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
                      color: activeTab == e.key ? kRed : Colors.transparent,
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
        return _buildCombatTab();
      case 1:
        return _buildStatsTab();
      case 2:
        return _buildRulesTab();
      default:
        return const SizedBox();
    }
  }

  // ──────────────────────────────────────────────────────────
  // COMBAT TAB
  // ──────────────────────────────────────────────────────────
  Widget _buildCombatTab() {
    final sc = _score;
    final pen = sc['penalties'] as Map? ?? {};
    final akaPen = Map<String, dynamic>.from(pen['aka'] as Map? ?? {});
    final aoPen = Map<String, dynamic>.from(pen['ao'] as Map? ?? {});

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          children: [
            Expanded(child: _penaltyCard('🔴 PÉNALITÉS AKA', akaPen, kRed)),
            const SizedBox(width: 10),
            Expanded(child: _penaltyCard('🔵 PÉNALITÉS AO', aoPen, kBlue)),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('▸ HISTORIQUE DU COMBAT'),
        const SizedBox(height: 10),
        if (_events.isEmpty)
          _emptyMsg('Aucun événement enregistré')
        else
          ..._events.reversed.map((e) {
            final ev = e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{};
            final side = ev['side']?.toString() ?? '';
            return _eventRow(ev, side == 'aka' ? kRed : kBlue);
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _penaltyCard(String label, Map<String, dynamic> pen, Color color) {
    final c = pen['chukoku'] as int? ?? 0;
    final k = pen['keikoku'] as int? ?? 0;
    final h = pen['hansoku'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              Color dot = Colors.white12;
              if (i < c) {
                dot = kGold;
              } else if (i < c + k)
                dot = Colors.orange;
              else if (i < c + k + h)
                dot = kRed;
              return Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Chukoku ×$c  •  Keikoku ×$k  •  Hansoku ×$h',
            style: const TextStyle(color: Colors.white24, fontSize: 8),
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
            ev['icon']?.toString() ?? '🥋',
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
  // STATS TAB
  // ──────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    final sc = _score;
    final evs = _events;
    int cnt(String side, String type) => evs
        .where((e) => e is Map && e['side'] == side && e['type'] == type)
        .length;

    final rows = [
      {'label': 'SCORE TOTAL', 'aka': sc['aka'] ?? 0, 'ao': sc['ao'] ?? 0},
      {
        'label': 'IPPON (×3 PTS)',
        'aka': cnt('aka', 'ippon'),
        'ao': cnt('ao', 'ippon'),
      },
      {
        'label': 'WAZA-ARI (×2)',
        'aka': cnt('aka', 'wazaari'),
        'ao': cnt('ao', 'wazaari'),
      },
      {
        'label': 'YUKO (×1)',
        'aka': cnt('aka', 'yuko'),
        'ao': cnt('ao', 'yuko'),
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
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      matchData!['team1_name']?.toString() ?? 'AKA',
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
                      matchData!['team2_name']?.toString() ?? 'AO',
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
                final a = (r['aka'] as int?) ?? 0;
                final b = (r['ao'] as int?) ?? 0;
                final t = a + b;
                final ratio = t == 0 ? 0.5 : a / t;
                return _statBar(
                  a.toString(),
                  r['label'].toString(),
                  b.toString(),
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
        '🥋',
        'SYSTÈME DE POINTS WKF',
        'YUKO = 1 pt (poing en zone) • WAZA-ARI = 2 pts (pied moyen) • IPPON = 3 pts (pied tête, projection, attaque dos) → Victoire immédiate',
      ],
      [
        '⏱',
        'DURÉE DU COMBAT',
        'ÉLITE Hommes : 3 min • ÉLITE Femmes : 2 min • Juniors : 2 min',
      ],
      [
        '🏆',
        'VICTOIRE PAR IPPON / SENSHU',
        'IPPON = Victoire immédiate. SENSHU = Avantage si égalité en fin de temps.',
      ],
      [
        '🔄',
        'ENCHO-SEN',
        'Prolongation si égalité. Le premier point remporte le combat.',
      ],
      [
        '🏅',
        'ÉCART DE 8 POINTS',
        'Victoire automatique par écart de 8 points (règle WKF).',
      ],
      [
        '🚨',
        'PÉNALITÉS',
        'Chukoku (+1) → Keikoku (+2) → Hansoku (DQ + IPPON adversaire)',
      ],
      [
        '🛡',
        'ZONES DE CONTACT',
        'Tête, visage, cou, abdomen, poitrine, dos, flancs. Force contrôlée obligatoire.',
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
        border: Border.all(color: kRed.withOpacity(0.12)),
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
                    color: kRed,
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
      color: kRed,
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
