import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'match_detail_screen.dart';
import 'basketball_match_detail_screen.dart';
import 'handball_match_detail_screen.dart'; // Nouvelle importation ajoutée

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

  // Définition de la couleur thématique selon le sport
  Color get _sportColor {
    switch (widget.sportType) {
      case 'basketball':
        return const Color(0xFFFFA500);
      case 'handball':
        return const Color(0xFFFF3131);
      default:
        return const Color(0xFF00FF85);
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _fetchMatches();
      _initSupabaseRealtime();
      _startSyncAnimation();
    });
  }

  void _startSyncAnimation() {
    _syncProgressTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
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
      final DateTime start = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final DateTime end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      final data = await supabase
          .from('matches')
          .select('*')
          .eq('league_id', widget.leagueId)
          .eq('sport_type', widget.sportType)
          .gte('start_time', start.toIso8601String())
          .lte('start_time', end.toIso8601String());

      if (mounted) {
        setState(() {
          filteredMatches = data as List<dynamic>;
          _sortMatches();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur Fetch Supabase: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _sortMatches() {
    filteredMatches.sort((a, b) {
      bool liveA = a['is_timer_active'] == true && a['is_locked'] != true;
      bool liveB = b['is_timer_active'] == true && b['is_locked'] != true;
      if (liveA && !liveB) return -1;
      if (!liveA && liveB) return 1;

      DateTime tA = DateTime.tryParse(a['start_time'] ?? "") ?? DateTime.now();
      DateTime tB = DateTime.tryParse(b['start_time'] ?? "") ?? DateTime.now();
      return tA.compareTo(tB);
    });
  }

  void _initSupabaseRealtime() {
    _matchesChannel = supabase
        .channel('public:matches:league=${widget.leagueId}')
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
            if (payload.newRecord.isNotEmpty) {
              final newMatch = payload.newRecord;
              if (newMatch['sport_type'] == widget.sportType && mounted) {
                setState(() {
                  final index = filteredMatches.indexWhere(
                    (m) => m['id'] == newMatch['id'],
                  );
                  if (index != -1) {
                    filteredMatches[index] = newMatch;
                  } else {
                    filteredMatches.add(newMatch);
                  }
                  _sortMatches();
                });
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _syncProgressTimer?.cancel();
    if (_matchesChannel != null) supabase.removeChannel(_matchesChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
                color: _sportColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            Text(
              "${widget.gender.toUpperCase()} • ${DateFormat('dd MMMM', 'fr_FR').format(selectedDate).toUpperCase()}",
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
            icon: Icon(Icons.calendar_month, color: _sportColor, size: 20),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _sportColor))
                : RefreshIndicator(
                    onRefresh: _fetchMatches,
                    color: _sportColor,
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

  Widget _buildDateSelector() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index - 3));
          bool isSelected = DateUtils.isSameDay(date, selectedDate);
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
                color: isSelected ? _sportColor : const Color(0xFF0D0D0D),
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
      itemBuilder: (context, index) => _buildMatchCard(filteredMatches[index]),
    );
  }

  Widget _buildMatchCard(Map match) {
    bool isLive = match['is_timer_active'] == true;
    bool isLocked = match['is_locked'] == true;
    String status = (match['status'] ?? "").toString().toUpperCase();
    bool isMT = status.contains("MI-TEMPS") || status.contains("MT");

    List p1 = match['pen1'] ?? [];
    List p2 = match['pen2'] ?? [];
    bool hasTAB = p1.isNotEmpty || p2.isNotEmpty;

    String startTime = "--:--";
    if (match['start_time'] != null) {
      try {
        startTime = DateFormat(
          'HH:mm',
        ).format(DateTime.parse(match['start_time']).toLocal());
      } catch (e) {
        startTime = "--:--";
      }
    }

    return GestureDetector(
      onTap: () {
        // --- ROUTAGE ADAPTÉ SELON LE SPORT TYPE ---
        if (widget.sportType == 'basketball') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BasketballMatchDetailScreen(matchId: match['id'].toString()),
            ),
          );
        } else if (widget.sportType == 'handball') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HandballMatchDetailScreen(matchId: match['id'].toString()),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MatchDetailScreen(matchId: match['id'].toString()),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLive && !isLocked
                ? _sportColor.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            width: isLive && !isLocked ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      color: Colors.white24,
                      size: 10,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      startTime,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (isLive && !isLocked)
                  (isMT
                      ? const _MTBadge()
                      : _BlinkingLiveBadge(color: _sportColor)),
                if (isLocked) const _FinishedBadge(),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _teamSlot(match['team1_name'], match['team1_logo']),
                ),
                SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      Text(
                        "${match['score1']} - ${match['score2']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hasTAB) _buildTABSummary(p1, p2),
                      const SizedBox(height: 8),
                      _buildMatchStatusUI(match, isLive, isLocked),
                    ],
                  ),
                ),
                Expanded(
                  child: _teamSlot(match['team2_name'], match['team2_logo']),
                ),
              ],
            ),
            if (isLive && !isMT && !isLocked) ...[
              const SizedBox(height: 15),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: Colors.white10,
                  color: _sportColor,
                  minHeight: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTABSummary(List p1, List p2) {
    int s1 = p1.where((e) => e == true).length;
    int s2 = p2.where((e) => e == true).length;
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _sportColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        "TAB: $s1 - $s2",
        style: TextStyle(
          color: _sportColor,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildMatchStatusUI(Map m, bool isLive, bool isLocked) {
    if (isLocked || !isLive) return const SizedBox.shrink();
    String extra = (m['extra_time'] ?? "0").toString();

    bool isBasket = widget.sportType == 'basketball';
    bool isHand = widget.sportType == 'handball';
    String timeDisplay = (isBasket || isHand)
        ? "${m['time']}"
        : "${m['time']}'";

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          timeDisplay,
          style: TextStyle(
            color: _sportColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (!isBasket && !isHand && extra != "0" && extra != "")
          Text(
            " +$extra",
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _teamSlot(String? name, String? logo) {
    return Column(
      children: [
        Container(
          height: 48,
          width: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFF1A1A1A),
            backgroundImage: (logo != null && logo.isNotEmpty)
                ? NetworkImage(logo)
                : null,
            child: (logo == null || logo.isEmpty)
                ? const Icon(Icons.shield, color: Colors.white10, size: 20)
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name?.toUpperCase() ?? "",
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() => const Center(
    child: Text(
      "AUCUN MATCH CE JOUR",
      style: TextStyle(
        color: Colors.white10,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _sportColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "LIVE",
        style: TextStyle(
          color: Colors.black,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _MTBadge extends StatelessWidget {
  const _MTBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.orangeAccent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      "MI-TEMPS",
      style: TextStyle(
        color: Colors.black,
        fontSize: 8,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      "TERMINÉ",
      style: TextStyle(
        color: Colors.white60,
        fontSize: 8,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
