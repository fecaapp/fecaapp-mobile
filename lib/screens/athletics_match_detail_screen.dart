import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// AthleticsCompetitionDetailScreen — v5.3
// ✅ Corrections :
//   1. Fallback gender depuis matches.gender + leagues.gender
//   2. _parsePerf robuste (virgule, "m", espaces)
//   3. Badge genre affiché dans le header
//   4. Realtime préserve leagues + gender au merge du payload
//   5. Unsubscribe propre dans dispose()
// ================================================================

class AthleticsCompetitionDetailScreen extends StatefulWidget {
  final String matchId;
  const AthleticsCompetitionDetailScreen({super.key, required this.matchId});

  @override
  State<AthleticsCompetitionDetailScreen> createState() =>
      _AthleticsCompetitionDetailScreenState();
}

class _AthleticsCompetitionDetailScreenState
    extends State<AthleticsCompetitionDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? matchData;
  bool isLoading = true;
  int activeTab = 0; // 0: RÉSULTATS, 1: RECORDS, 2: ATHLÈTES
  RealtimeChannel? _channel;

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kGreen = Color(0xFF00FF85);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  // Disciplines de sauts/lancers (pas de couloir, pas de vent)
  static const _throwOrJump = {
    'LONGUEUR',
    'HAUTEUR',
    'PERCHE',
    'TRIPLE SAUT',
    'POIDS',
    'DISQUE',
    'JAVELOT',
    'MARTEAU',
  };

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _initRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final data = await supabase
          .from('matches')
          .select('*, leagues(name, gender)')
          .eq('id', widget.matchId)
          .single();
      if (mounted) {
        setState(() {
          matchData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur Athletics Detail: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initRealtime() {
    _channel = supabase
        .channel('ath_detail_${widget.matchId}')
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
                // ✅ FIX : on préserve leagues ET gender au merge du payload
                final oldLeagues = matchData?['leagues'];
                final oldGender = matchData?['gender'];
                matchData = {...matchData!, ...payload.newRecord};
                matchData!['leagues'] = oldLeagues;
                // gender peut venir du payload ou de l'ancienne valeur
                matchData!['gender'] ??= oldGender;
              });
            }
          },
        )
        .subscribe();
  }

  // ── Tri des résultats ─────────────────────────────────────────
  List<Map<String, dynamic>> get _sortedResults {
    final raw = matchData!['athletics_results'] as List<dynamic>? ?? [];
    final results = raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final valid = results.where((r) => r['dnf'] != true).toList()
      ..sort(
        (a, b) => _parsePerf(
          a['performance'],
        ).compareTo(_parsePerf(b['performance'])),
      );
    final dnf = results.where((r) => r['dnf'] == true).toList();
    return [...valid, ...dnf];
  }

  // ✅ Parser robuste : "9.87", "2:01.34", "8.45m", "8,45m"
  double _parsePerf(String? perf) {
    if (perf == null || perf.trim().isEmpty) return 9999;
    final p = perf.trim().replaceAll(',', '.').replaceAll('m', '');
    if (p.contains(':')) {
      final parts = p.split(':');
      if (parts.length == 2) {
        return (double.tryParse(parts[0]) ?? 0) * 60 +
            (double.tryParse(parts[1]) ?? 0);
      }
    }
    return double.tryParse(p) ?? 9999;
  }

  // ✅ Gender : priorité leagues.gender → matches.gender → 'Masculin'
  String get _gender =>
      matchData?['leagues']?['gender']?.toString() ??
      matchData?['gender']?.toString() ??
      'Masculin';

  String get _leagueName =>
      matchData?['leagues']?['name']?.toString() ??
      matchData?['league_name']?.toString() ??
      'ATHLÉTISME';

  String get _discipline => matchData?['discipline']?.toString() ?? '';

  String _getFlagEmoji(String? code) {
    const flags = {
      'CMR': '🇨🇲',
      'USA': '🇺🇸',
      'KEN': '🇰🇪',
      'ETH': '🇪🇹',
      'JAM': '🇯🇲',
      'FRA': '🇫🇷',
      'GBR': '🇬🇧',
      'NGA': '🇳🇬',
      'RSA': '🇿🇦',
      'MAR': '🇲🇦',
      'UGA': '🇺🇬',
      'TAN': '🇹🇿',
      'CIV': '🇨🇮',
      'GHA': '🇬🇭',
      'SEN': '🇸🇳',
    };
    return flags[code?.toUpperCase()] ?? '🏴';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || matchData == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _leagueName.toUpperCase(),
          style: const TextStyle(
            color: kOrange,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          // ✅ Badge genre dynamique (Masculin / Féminin / Mixte)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _genderColor.withOpacity(0.1),
              border: Border.all(color: _genderColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _genderLabel,
              style: TextStyle(
                color: _genderColor,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCompetitionHeader(),
          _buildPhaseBar(),
          _buildTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Color get _genderColor {
    switch (_gender) {
      case 'Féminin':
        return kGold;
      case 'Mixte':
        return kGreen;
      default:
        return kOrange;
    }
  }

  String get _genderLabel {
    switch (_gender) {
      case 'Féminin':
        return 'FEMMES';
      case 'Mixte':
        return 'MIXTE';
      default:
        return 'HOMMES';
    }
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildCompetitionHeader() {
    final results = _sortedResults;
    final pbCount = results.where((r) => r['is_pb'] == true).length;
    final wrCount = results.where((r) => r['is_wr'] == true).length;
    final dnfCount = results.where((r) => r['dnf'] == true).length;
    final isLive = matchData!['is_timer_active'] == true;
    final stadium = matchData!['stadium']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _discipline.isNotEmpty ? _discipline : 'COMPÉTITION',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (stadium.isNotEmpty)
                          Text(
                            stadium,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        if (isLive) ...[
                          const SizedBox(width: 10),
                          _liveBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kOrange.withOpacity(0.1),
                  border: Border.all(color: kOrange.withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: kOrange,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip('${results.length}', 'ATHLÈTES', kOrange),
              const SizedBox(width: 8),
              _statChip('$pbCount', 'REC. PERSO', kGold),
              const SizedBox(width: 8),
              _statChip('$wrCount', 'REC. MONDE', kGreen),
              const SizedBox(width: 8),
              _statChip('$dnfCount', 'DNF', kRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
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
    ),
  );

  // ── Phase bar ─────────────────────────────────────────────────
  Widget _buildPhaseBar() {
    final phase = matchData!['phase']?.toString() ?? 'series';
    final phases = ['series', 'demi', 'finale'];
    final labels = ['SÉRIES', 'DEMI-FINALES', 'FINALE'];
    final currentIdx = phases.indexOf(phase);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(phases.length, (i) {
          final isActive = i == currentIdx;
          final isPast = i < currentIdx;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? kOrange : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive
                      ? Colors.black
                      : isPast
                      ? kOrange.withOpacity(0.5)
                      : Colors.white24,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────
  Widget _buildTabs() {
    const tabs = ['RÉSULTATS', 'RECORDS', 'ATHLÈTES'];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      color: activeTab == e.key ? kOrange : Colors.transparent,
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
        return _buildResults();
      case 1:
        return _buildRecords();
      case 2:
        return _buildAthletes();
      default:
        return const SizedBox();
    }
  }

  // ── Résultats ─────────────────────────────────────────────────
  Widget _buildResults() {
    final results = _sortedResults;
    final isThrowOrJump = _throwOrJump.contains(_discipline);

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run,
              color: kOrange.withOpacity(0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'AUCUN RÉSULTAT ENREGISTRÉ',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      itemCount: results.length,
      itemBuilder: (context, index) =>
          _buildResultRow(index, results[index], isThrowOrJump),
    );
  }

  Widget _buildResultRow(
    int index,
    Map<String, dynamic> result,
    bool isThrowOrJump,
  ) {
    final isDNF = result['dnf'] == true;
    final isWR = result['is_wr'] == true; // ✅ is_wr cohérent dashboard
    final isPB = result['is_pb'] == true; // ✅ is_pb cohérent dashboard

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWR
              ? kGreen.withOpacity(0.4)
              : isPB
              ? kGold.withOpacity(0.3)
              : isDNF
              ? kRed.withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 36,
            child: isDNF
                ? const Text(
                    'DNF',
                    style: TextStyle(
                      color: kRed,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Text(
                    index == 0
                        ? '🥇'
                        : index == 1
                        ? '🥈'
                        : index == 2
                        ? '🥉'
                        : '${index + 1}',
                    style: TextStyle(
                      color: index < 3 ? kOrange : Colors.white38,
                      fontSize: index < 3 ? 18 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          // Couloir (masqué pour sauts/lancers)
          if (!isThrowOrJump)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  result['couloir']?.toString() ?? '—',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Nom + Pays
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result['name']?.toString() ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _getFlagEmoji(result['country']?.toString()),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result['country']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Performance + badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isDNF ? 'DNF' : result['performance']?.toString() ?? '—',
                style: TextStyle(
                  color: isDNF
                      ? kRed
                      : isWR
                      ? kGreen
                      : kOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!isThrowOrJump &&
                  (result['wind'] ?? '').toString().trim().isNotEmpty)
                Text(
                  'VENT: ${result['wind']}',
                  style: const TextStyle(color: Colors.white24, fontSize: 8),
                ),
              Row(
                children: [
                  if (isWR) _badge('RM', kGreen),
                  if (isPB) ...[const SizedBox(width: 4), _badge('RP', kGold)],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900),
    ),
  );

  // ── Records (référence statique) ──────────────────────────────
  Widget _buildRecords() {
    final records = [
      {
        'type': 'RECORD MONDIAL HOMMES',
        'discipline': '100m',
        'holder': 'Usain Bolt (JAM)',
        'val': '9.58',
        'year': '2009',
        'color': kGreen,
      },
      {
        'type': 'RECORD MONDIAL FEMMES',
        'discipline': '100m',
        'holder': 'Florence Griffith (USA)',
        'val': '10.49',
        'year': '1988',
        'color': kGreen,
      },
      {
        'type': "RECORD D'AFRIQUE",
        'discipline': '100m',
        'holder': 'Ferdinand Omanyala (KEN)',
        'val': '9.77',
        'year': '2021',
        'color': kGold,
      },
      {
        'type': 'RECORD NATIONAL CMR',
        'discipline': '100m',
        'holder': '—',
        'val': '—',
        'year': '—',
        'color': kOrange,
      },
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('▸ RECORDS DE RÉFÉRENCE'),
        const SizedBox(height: 12),
        ...records.map((r) => _buildRecordCard(r)),
        const SizedBox(height: 20),
        _sectionTitle('▸ CONDITIONS IAAF'),
        const SizedBox(height: 12),
        _buildRuleCard(
          Icons.air,
          'LIMITE DE VENT',
          '+2.0 m/s max pour sprint et sauts',
          kGreen,
        ),
        _buildRuleCard(
          Icons.timer,
          'CHRONOMÉTRAGE',
          'Électronique automatique (FAT) obligatoire',
          kOrange,
        ),
        _buildRuleCard(
          Icons.repeat,
          'TENTATIVES SAUTS/LANCERS',
          '3 essais qualif, 6 en finale (8 premiers)',
          kGold,
        ),
        _buildRuleCard(
          Icons.sports,
          'FAUX DÉPART',
          'Disqualification immédiate (règle IAAF)',
          kRed,
        ),
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> r) {
    final color = r['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['type'].toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r['holder'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  r['year'].toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            r['val'].toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
    IconData icon,
    String title,
    String desc,
    Color color,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kBg2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
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

  // ── Athlètes ──────────────────────────────────────────────────
  Widget _buildAthletes() {
    final results = _sortedResults;
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'AUCUN ATHLÈTE ENREGISTRÉ',
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        final isPB = r['is_pb'] == true;
        final isWR = r['is_wr'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kOrange.withOpacity(0.1),
                child: Text(
                  r['couloir']?.toString() ?? '${i + 1}',
                  style: const TextStyle(
                    color: kOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['name']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          _getFlagEmoji(r['country']?.toString()),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r['country']?.toString() ?? '—',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    r['performance']?.toString() ?? '—',
                    style: const TextStyle(
                      color: kOrange,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isPB) _badge('RP', kGold),
                  if (isWR) _badge('RM', kGreen),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _liveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: kOrange,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );
}
