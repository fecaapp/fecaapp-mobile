import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'match_detail_screen.dart';
import 'basketball_match_detail_screen.dart';
import 'handball_match_detail_screen.dart';
import 'athletics_match_detail_screen.dart';
import 'tennis_match_detail_screen.dart';
import 'volleyball_match_detail_screen.dart';
import 'karate_match_detail_screen.dart';
import 'boxe_match_detail_screen.dart';
import 'mma_match_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SPORT CONFIG — source unique de vérité pour tout l'écran
// ═══════════════════════════════════════════════════════════════
class _SportConfig {
  final Color color;
  final IconData icon;
  final String timerUnit;
  final bool hasExtraTime;
  final bool hasPenalties;
  final bool hasHalftime;
  final bool hasSets;
  final bool hasRounds;
  final bool hasLanes;
  final String scoreLabel;
  final List<String> periodLabels;

  const _SportConfig({
    required this.color,
    required this.icon,
    required this.timerUnit,
    this.hasExtraTime = false,
    this.hasPenalties = false,
    this.hasHalftime = true,
    this.hasSets = false,
    this.hasRounds = false,
    this.hasLanes = false,
    this.scoreLabel = '',
    this.periodLabels = const [],
  });

  static const Map<String, _SportConfig> all = {
    'football': _SportConfig(
      color: Color(0xFF00FF85),
      icon: Icons.sports_soccer,
      timerUnit: "'",
      hasExtraTime: true,
      hasPenalties: true,
      hasHalftime: true,
      scoreLabel: 'BUTS',
      periodLabels: ['1ère MI-TEMPS', '2ème MI-TEMPS', 'PROLONG.'],
    ),
    'basketball': _SportConfig(
      color: Color(0xFFFFA500),
      icon: Icons.sports_basketball,
      timerUnit: '',
      hasHalftime: false,
      scoreLabel: 'PTS',
      periodLabels: ['Q1', 'Q2', 'Q3', 'Q4', 'PROLONG.'],
    ),
    'handball': _SportConfig(
      color: Color(0xFFFF3131),
      icon: Icons.sports_handball,
      timerUnit: "'",
      hasHalftime: true,
      scoreLabel: 'BUTS',
      periodLabels: ['1ère MI-TEMPS', '2ème MI-TEMPS'],
    ),
    'athletics': _SportConfig(
      color: Color(0xFFFF6B00),
      icon: Icons.directions_run,
      timerUnit: '',
      hasHalftime: false,
      hasLanes: true,
      scoreLabel: 'POINTS',
    ),
    'tennis': _SportConfig(
      color: Color(0xFFC8FF00),
      icon: Icons.sports_tennis,
      timerUnit: '',
      hasHalftime: false,
      hasSets: true,
      scoreLabel: 'SETS',
      periodLabels: ['SET 1', 'SET 2', 'SET 3', 'SET 4', 'SET 5'],
    ),
    'volleyball': _SportConfig(
      color: Color(0xFF9B59FF),
      icon: Icons.sports_volleyball,
      timerUnit: '',
      hasHalftime: false,
      hasSets: true,
      scoreLabel: 'SETS',
      periodLabels: ['SET 1', 'SET 2', 'SET 3', 'SET 4', 'SET 5'],
    ),
    'karate': _SportConfig(
      color: Color(0xFFFF0044),
      icon: Icons.sports_martial_arts,
      timerUnit: '',
      hasHalftime: false,
      hasRounds: true,
      scoreLabel: 'POINTS',
      periodLabels: ['COMBAT'],
    ),
    'boxing': _SportConfig(
      color: Color(0xFFFFB800),
      icon: Icons.sports_mma,
      timerUnit: '',
      hasHalftime: false,
      hasRounds: true,
      scoreLabel: 'ROUNDS',
      periodLabels: [
        'R1',
        'R2',
        'R3',
        'R4',
        'R5',
        'R6',
        'R7',
        'R8',
        'R9',
        'R10',
        'R11',
        'R12',
      ],
    ),
    'mma': _SportConfig(
      color: Color(0xFF00CFFF),
      icon: Icons.sports_mma,
      timerUnit: '',
      hasHalftime: false,
      hasRounds: true,
      scoreLabel: 'ROUNDS',
      periodLabels: ['R1', 'R2', 'R3', 'R4', 'R5'],
    ),
  };

  static _SportConfig of(String sport) => all[sport] ?? all['football']!;
}

// ═══════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════
class SpecificMatchListScreen extends StatefulWidget {
  final String leagueName;
  final String leagueId;
  final String gender;
  final String sportType;

  const SpecificMatchListScreen({
    super.key,
    required this.leagueName,
    required this.leagueId,
    required this.gender,
    required this.sportType,
  });

  @override
  State<SpecificMatchListScreen> createState() =>
      _SpecificMatchListScreenState();
}

class _SpecificMatchListScreenState extends State<SpecificMatchListScreen>
    with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> filteredMatches = [];
  RealtimeChannel? _matchesChannel;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  Timer? _syncProgressTimer;
  double _progressValue = 0.0;

  late final _SportConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = _SportConfig.of(widget.sportType);
    initializeDateFormatting('fr_FR', null).then((_) {
      _fetchMatches();
      _initSupabaseRealtime();
      _startSyncAnimation();
    });
  }

  void _startSyncAnimation() {
    _syncProgressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          _progressValue += 0.01;
          if (_progressValue >= 1.0) _progressValue = 0.0;
        });
      }
    });
  }

  Future<void> _fetchMatches() async {
    try {
      final start = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      // Récupérer TOUS les matchs de la ligue (avec ou sans match_time)
      final allData = await supabase
          .from('matches')
          .select('*')
          .eq('league_id', widget.leagueId)
          .eq('sport_type', widget.sportType);

      if (mounted) {
        final all = allData as List<dynamic>;

        // Filtrer côté client :
        // - matchs avec match_time correspondant à la date sélectionnée
        // - OU matchs LIVE / sans match_time → toujours visibles
        final filtered = all.where((m) {
          final String? mt = m['match_time'];
          if (mt == null || mt.isEmpty) {
            // Pas de date → afficher si LIVE ou pas encore clôturé
            return m['is_locked'] != true || m['is_timer_active'] == true;
          }
          final DateTime? matchDate = DateTime.tryParse(mt);
          if (matchDate == null) return false;
          final DateTime local = matchDate.toLocal();
          return local.isAfter(start.subtract(const Duration(seconds: 1))) &&
              local.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();

        setState(() {
          filteredMatches = filtered;
          _sortMatches();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur Fetch: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _sortMatches() {
    filteredMatches.sort((a, b) {
      int priority(Map m) {
        if (m['is_timer_active'] == true && m['is_locked'] != true) return 0;
        if (m['is_locked'] != true) return 1;
        return 2;
      }

      final pa = priority(a as Map), pb = priority(b as Map);
      if (pa != pb) return pa.compareTo(pb);
      final tA = DateTime.tryParse(a['match_time'] ?? '') ?? DateTime.now();
      final tB = DateTime.tryParse(b['match_time'] ?? '') ?? DateTime.now();
      return tA.compareTo(tB);
    });
  }

  void _initSupabaseRealtime() {
    _matchesChannel = supabase
        .channel('specific:${widget.leagueId}:${widget.sportType}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'league_id',
            value: widget.leagueId,
          ),
          callback: (payload) {
            if (!mounted) return;
            if (payload.eventType == PostgresChangeEvent.delete) {
              setState(
                () => filteredMatches.removeWhere(
                  (m) => m['id'] == payload.oldRecord['id'],
                ),
              );
              return;
            }
            final record = payload.newRecord;
            if (record.isEmpty || record['sport_type'] != widget.sportType) {
              return;
            }
            setState(() {
              final idx = filteredMatches.indexWhere(
                (m) => m['id'] == record['id'],
              );
              if (idx != -1) {
                filteredMatches[idx] = record;
              } else {
                final d = DateTime.tryParse(record['match_time'] ?? '');
                if (d != null && DateUtils.isSameDay(d, selectedDate)) {
                  filteredMatches.add(record);
                }
              }
              _sortMatches();
            });
          },
        )
        .subscribe();
  }

  // ── Navigation sport-aware ─────────────────────────────────────
  void _navigateToMatchDetail(Map match) {
    final String matchId = match['id'].toString();
    Widget screen;
    switch (widget.sportType) {
      case 'basketball':
        screen = BasketballMatchDetailScreen(matchId: matchId);
        break;
      case 'handball':
        screen = HandballMatchDetailScreen(matchId: matchId);
        break;
      case 'athletics':
        screen = AthleticsCompetitionDetailScreen(matchId: matchId);
        break;
      case 'tennis':
        screen = TennisMatchDetailScreen(matchId: matchId);
        break;
      case 'volleyball':
        screen = VolleyballMatchDetailScreen(matchId: matchId);
        break;
      case 'karate':
        screen = KarateMatchDetailScreen(matchId: matchId);
        break;
      case 'boxing':
        screen = BoxeMatchDetailScreen(matchId: matchId);
        break;
      case 'mma':
        screen = MmaMatchDetailScreen(matchId: matchId);
        break;
      default:
        screen = MatchDetailScreen(matchId: matchId);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _syncProgressTimer?.cancel();
    if (_matchesChannel != null) supabase.removeChannel(_matchesChannel!);
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildSportBanner(),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _cfg.color))
                : RefreshIndicator(
                    onRefresh: _fetchMatches,
                    color: _cfg.color,
                    backgroundColor: const Color(0xFF0D0D0D),
                    child: filteredMatches.isEmpty
                        ? _buildEmptyState()
                        : _buildMatchList(),
                  ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.leagueName.toUpperCase(),
            style: TextStyle(
              color: _cfg.color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          Text(
            '${widget.gender.toUpperCase()} • ${DateFormat('dd MMMM', 'fr_FR').format(selectedDate).toUpperCase()}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.calendar_month, color: _cfg.color, size: 20),
          onPressed: () => _selectDate(context),
        ),
      ],
    );
  }

  // ── Bannière sport ────────────────────────────────────────────
  Widget _buildSportBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cfg.color.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: _cfg.color.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _cfg.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_cfg.icon, color: _cfg.color, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            widget.sportType.toUpperCase(),
            style: TextStyle(
              color: _cfg.color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (_cfg.scoreLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _cfg.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _cfg.color.withOpacity(0.2)),
              ),
              child: Text(
                _cfg.scoreLabel,
                style: TextStyle(
                  color: _cfg.color,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Sélecteur de dates ─────────────────────────────────────────
  Widget _buildDateSelector() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index - 3));
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDate = date;
                isLoading = true;
              });
              _fetchMatches();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: isSelected ? _cfg.color : const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr_FR').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchList() {
    return ListView.builder(
      itemCount: filteredMatches.length,
      padding: const EdgeInsets.all(15),
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) =>
          _buildMatchCard(filteredMatches[index] as Map),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CARTE MATCH — dispatch par sport
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMatchCard(Map match) {
    final bool isLive =
        match['is_timer_active'] == true && match['is_locked'] != true;
    final bool isLocked = match['is_locked'] == true;
    final String status = (match['status'] ?? '').toString().toUpperCase();
    final bool isMT = status.contains('MI-TEMPS') || status.contains('MT');

    String startTime = '--:--';
    if (match['match_time'] != null) {
      try {
        startTime = DateFormat(
          'HH:mm',
        ).format(DateTime.parse(match['match_time']).toLocal());
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _navigateToMatchDetail(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFF080808) : const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLive
                ? _cfg.color.withOpacity(0.35)
                : isLocked
                ? Colors.white.withOpacity(0.03)
                : Colors.white.withOpacity(0.06),
            width: isLive ? 1.3 : 0.8,
          ),
          boxShadow: isLive
              ? [
                  BoxShadow(
                    color: _cfg.color.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            _buildCardHeader(match, isLive, isLocked, isMT, startTime),

            // ── Corps adapté selon sport ──────────────────
            if (_cfg.hasRounds)
              _buildRoundCard(match, isLive, isLocked)
            else if (_cfg.hasSets)
              _buildSetCard(match, isLive, isLocked)
            else if (_cfg.hasLanes)
              _buildAthleticsCard(match, isLive, isLocked)
            else
              _buildStandardCard(match, isLive, isLocked, isMT),

            if (isLive && !isMT) _LiveProgressBar(color: _cfg.color),
          ],
        ),
      ),
    );
  }

  // ── Header commun ──────────────────────────────────────────────
  Widget _buildCardHeader(
    Map match,
    bool isLive,
    bool isLocked,
    bool isMT,
    String startTime,
  ) {
    final String journee = match['match_day'] != null
        ? 'J${match['match_day']}'
        : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.access_time_filled, color: Colors.white24, size: 10),
          const SizedBox(width: 4),
          Text(
            startTime,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (journee.isNotEmpty) ...[
            const SizedBox(width: 8),
            _pill(journee, _cfg.color.withOpacity(0.6)),
          ],
          const Spacer(),
          _buildStatusBadge(isLive: isLive, isMT: isMT, isLocked: isLocked),
        ],
      ),
    );
  }

  // ── STANDARD : football / basketball / handball ────────────────
  Widget _buildStandardCard(Map match, bool isLive, bool isLocked, bool isMT) {
    final List p1 = match['pen1'] ?? [];
    final List p2 = match['pen2'] ?? [];
    final bool hasTAB = p1.isNotEmpty || p2.isNotEmpty;
    final int tabS1 = p1.where((e) => e == true).length;
    final int tabS2 = p2.where((e) => e == true).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _teamSlot(
              match['team_a_name'],
              match['team_a_logo'],
              dimmed: isLocked,
            ),
          ),
          Column(
            children: [
              Text(
                '${match['score1'] ?? 0} - ${match['score2'] ?? 0}',
                style: TextStyle(
                  color: isLocked ? Colors.white38 : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              if (hasTAB) ...[
                const SizedBox(height: 4),
                _pill('TAB $tabS1 - $tabS2', _cfg.color),
              ],
              if (isLive && !isMT) ...[
                const SizedBox(height: 6),
                _liveTimer(match),
              ],
            ],
          ),
          Expanded(
            child: _teamSlot(
              match['team_b_name'],
              match['team_b_logo'],
              dimmed: isLocked,
            ),
          ),
        ],
      ),
    );
  }

  // ── ROUNDS : boxing / mma / karate ────────────────────────────
  Widget _buildRoundCard(Map match, bool isLive, bool isLocked) {
    final int currentRound =
        int.tryParse(
          (match['current_round'] ?? match['time'] ?? '1').toString(),
        ) ??
        1;
    final String result = (match['result'] ?? '').toString().toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _fighterSlot(
                  match['team_a_name'],
                  match['team_a_logo'],
                  dimmed: isLocked,
                ),
              ),
              Column(
                children: [
                  if (isLocked && result.isNotEmpty)
                    _buildFightResult(result, match)
                  else
                    Text(
                      '${match['score1'] ?? 0} - ${match['score2'] ?? 0}',
                      style: TextStyle(
                        color: isLocked ? Colors.white38 : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _cfg.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _cfg.color.withOpacity(0.3)),
                    ),
                    child: Text(
                      isLocked
                          ? (result.isNotEmpty ? result : 'TERMINÉ')
                          : 'R$currentRound',
                      style: TextStyle(
                        color: _cfg.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isLive) ...[const SizedBox(height: 6), _liveTimer(match)],
                ],
              ),
              Expanded(
                child: _fighterSlot(
                  match['team_b_name'],
                  match['team_b_logo'],
                  dimmed: isLocked,
                ),
              ),
            ],
          ),
          if (!isLocked && _cfg.periodLabels.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRoundDots(currentRound, _cfg.periodLabels.length),
          ],
        ],
      ),
    );
  }

  Widget _buildFightResult(String result, Map match) {
    Color c = _cfg.color;
    if (result.contains('KO') || result.contains('TKO')) {
      c = const Color(0xFFFF3131);
    }
    if (result.contains('SUB') || result.contains('SOUM')) {
      c = const Color(0xFFFF6B00);
    }
    return Column(
      children: [
        Text(
          '${match['score1'] ?? 0} - ${match['score2'] ?? 0}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            result,
            style: TextStyle(
              color: c,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundDots(int current, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? _cfg.color
                : done
                ? _cfg.color.withOpacity(0.4)
                : Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── SETS : tennis / volleyball ────────────────────────────────
  Widget _buildSetCard(Map match, bool isLive, bool isLocked) {
    final List<Map<String, int>> sets = _parseSets(match);
    final int setsA = sets.where((s) => (s['a'] ?? 0) > (s['b'] ?? 0)).length;
    final int setsB = sets.where((s) => (s['b'] ?? 0) > (s['a'] ?? 0)).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _teamSlot(
                  match['team_a_name'],
                  match['team_a_logo'],
                  dimmed: isLocked,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$setsA - $setsB',
                    style: TextStyle(
                      color: isLocked ? Colors.white38 : Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _pill('SETS', _cfg.color.withOpacity(0.7)),
                  if (isLive) ...[const SizedBox(height: 6), _liveTimer(match)],
                ],
              ),
              Expanded(
                child: _teamSlot(
                  match['team_b_name'],
                  match['team_b_logo'],
                  dimmed: isLocked,
                ),
              ),
            ],
          ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSetsDetail(sets),
          ],
        ],
      ),
    );
  }

  Widget _buildSetsDetail(List<Map<String, int>> sets) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: sets.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        final aWon = (s['a'] ?? 0) > (s['b'] ?? 0);
        final bWon = (s['b'] ?? 0) > (s['a'] ?? 0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _cfg.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cfg.color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                'S${i + 1}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${s['a']}',
                style: TextStyle(
                  color: aWon ? _cfg.color : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                height: 0.5,
                width: 16,
                color: Colors.white12,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
              Text(
                '${s['b']}',
                style: TextStyle(
                  color: bWon ? _cfg.color : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, int>> _parseSets(Map match) {
    final List<Map<String, int>> result = [];
    for (int i = 1; i <= 5; i++) {
      final a = match['set${i}_a'];
      final b = match['set${i}_b'];
      if (a != null || b != null) {
        result.add({'a': (a ?? 0) as int, 'b': (b ?? 0) as int});
      }
    }
    if (result.isEmpty && match['sets'] != null) {
      try {
        final raw = match['sets'] as List;
        for (final s in raw) {
          result.add({
            'a': (s['a'] ?? s[0] ?? 0) as int,
            'b': (s['b'] ?? s[1] ?? 0) as int,
          });
        }
      } catch (_) {}
    }
    return result;
  }

  // ── ATHLETICS ─────────────────────────────────────────────────
  Widget _buildAthleticsCard(Map match, bool isLive, bool isLocked) {
    final String discipline = (match['discipline'] ?? match['event'] ?? '')
        .toString()
        .toUpperCase();
    final String performance = (match['performance'] ?? match['result'] ?? '')
        .toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          if (discipline.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _cfg.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cfg.color.withOpacity(0.25)),
              ),
              child: Text(
                discipline,
                style: TextStyle(
                  color: _cfg.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: _teamSlot(
                  match['team_a_name'],
                  match['team_a_logo'],
                  dimmed: isLocked,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${match['score1'] ?? 0} - ${match['score2'] ?? 0}',
                    style: TextStyle(
                      color: isLocked ? Colors.white38 : Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (performance.isNotEmpty)
                    Text(
                      performance,
                      style: TextStyle(
                        color: _cfg.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (isLive) ...[const SizedBox(height: 6), _liveTimer(match)],
                ],
              ),
              Expanded(
                child: _teamSlot(
                  match['team_b_name'],
                  match['team_b_logo'],
                  dimmed: isLocked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widgets communs ────────────────────────────────────────────
  Widget _liveTimer(Map match) {
    final String t = (match['time'] ?? '00:00').toString();
    final String extra = (match['extra_time'] ?? '0').toString();
    final bool hasExtra = _cfg.hasExtraTime && extra != '0' && extra.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _cfg.timerUnit == "'" ? "$t'" : t,
          style: TextStyle(
            color: _cfg.color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (hasExtra)
          Text(
            ' +$extra',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge({
    required bool isLive,
    required bool isMT,
    required bool isLocked,
  }) {
    if (isLive && isMT) return _statusChip('MI-TEMPS', Colors.orangeAccent);
    if (isLive) return _BlinkingLiveBadge(color: _cfg.color);
    if (isLocked) return _statusChip('TERMINÉ', Colors.white38);
    return _statusChip('À VENIR', Colors.white24, border: true);
  }

  Widget _statusChip(String label, Color color, {bool border = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: border ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _teamSlot(String? name, String? logo, {bool dimmed = false}) {
    return Column(
      children: [
        Opacity(
          opacity: dimmed ? 0.55 : 1.0,
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _cfg.color.withOpacity(0.1)),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1A1A1A),
              backgroundImage: (logo != null && logo.isNotEmpty)
                  ? NetworkImage(logo)
                  : null,
              child: (logo == null || logo.isEmpty)
                  ? Icon(_cfg.icon, color: Colors.white10, size: 20)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (name ?? 'ÉQUIPE').toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dimmed ? Colors.white30 : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // Slot combattant — visuel plus agressif pour arts martiaux
  Widget _fighterSlot(String? name, String? logo, {bool dimmed = false}) {
    return Column(
      children: [
        Opacity(
          opacity: dimmed ? 0.55 : 1.0,
          child: Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _cfg.color.withOpacity(0.25),
                width: 1.5,
              ),
              color: const Color(0xFF1A1A1A),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: (logo != null && logo.isNotEmpty)
                  ? Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        _cfg.icon,
                        color: _cfg.color.withOpacity(0.4),
                        size: 22,
                      ),
                    )
                  : Icon(
                      _cfg.icon,
                      color: _cfg.color.withOpacity(0.4),
                      size: 22,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (name ?? 'COMBATTANT').toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dimmed ? Colors.white30 : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cfg.color.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _cfg.icon,
              color: _cfg.color.withOpacity(0.25),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AUCUN MATCH CE JOUR',
            style: TextStyle(
              color: _cfg.color.withOpacity(0.3),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.sportType.toUpperCase(),
            style: const TextStyle(
              color: Colors.white12,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _cfg.color,
            onPrimary: Colors.black,
            surface: const Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        isLoading = true;
      });
      _fetchMatches();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════
class _BlinkingLiveBadge extends StatefulWidget {
  final Color color;
  const _BlinkingLiveBadge({required this.color});
  @override
  State<_BlinkingLiveBadge> createState() => _BlinkingLiveBadgeState();
}

class _BlinkingLiveBadgeState extends State<_BlinkingLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LiveProgressBar extends StatefulWidget {
  final Color color;
  const _LiveProgressBar({required this.color});
  @override
  State<_LiveProgressBar> createState() => _LiveProgressBarState();
}

class _LiveProgressBarState extends State<_LiveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => LinearProgressIndicator(
      value: _anim.value,
      backgroundColor: Colors.white.withOpacity(0.04),
      color: widget.color,
      minHeight: 2,
    ),
  );
}
