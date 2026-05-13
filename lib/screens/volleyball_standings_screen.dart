import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VolleyballStandingsScreen extends StatefulWidget {
  const VolleyballStandingsScreen({super.key});

  @override
  State<VolleyballStandingsScreen> createState() =>
      _VolleyballStandingsScreenState();
}

class _VolleyballStandingsScreenState extends State<VolleyballStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedGender = 'Masculin';
  bool isLoadingLeagues = true;

  static const Color kPurple = Color(0xFF9B59FF);
  static const Color kCyan = Color(0xFF00D1FF);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kGreen = Color(0xFF00FF85);

  @override
  void initState() {
    super.initState();
    fetchLeagues();
  }

  Future<void> fetchLeagues() async {
    try {
      final data = await supabase
          .from('leagues')
          .select('id, name, logo_url')
          .eq('sport_type', 'volleyball')
          .order('name');

      if (mounted && data.isNotEmpty) {
        setState(() {
          leagues = data;
          selectedLeagueId = data[0]['id'].toString();
          isLoadingLeagues = false;
        });
      } else {
        setState(() => isLoadingLeagues = false);
      }
    } catch (e) {
      debugPrint('❌ Erreur Ligues Volley: $e');
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  Widget _H(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white30,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _D(
    String val, {
    Color color = Colors.white70,
    int flex = 1,
    bool isBold = false,
  }) => Expanded(
    flex: flex,
    child: Text(
      val,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CLASSEMENT VOLLEYBALL',
          style: TextStyle(
            color: kPurple,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildGenderSelector(),
                _buildHeader(),
                Expanded(child: _buildRealtimeStandings()),
              ],
            ),
    );
  }

  // ============================================================
  // LEAGUE SELECTOR
  // ============================================================
  Widget _buildLeagueSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: leagues.length,
        itemBuilder: (context, index) {
          final league = leagues[index];
          final isSelected = selectedLeagueId == league['id'].toString();
          return GestureDetector(
            onTap: () =>
                setState(() => selectedLeagueId = league['id'].toString()),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? kPurple : kBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  if (league['logo_url'] != null && isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(league['logo_url']),
                      ),
                    ),
                  Center(
                    child: Text(
                      league['name'].toString().toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
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

  // ============================================================
  // GENDER SELECTOR
  // ============================================================
  Widget _buildGenderSelector() {
    final genders = ['Masculin', 'Féminin', 'Mixte'];
    final labels = ['MASCULIN', 'FÉMININ', 'BEACH MIXTE'];
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(genders.length, (i) {
          final isSelected = selectedGender == genders[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedGender = genders[i]),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? kPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // Colonnes FIVB officielles : MJ / V / D / SETS POUR / SETS CONTRE / PTS
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 25,
            child: Text(
              '#',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'CLUB',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _H('MJ'),
          _H('V'),
          _H('D'),
          _H('S+'),
          _H('S-'),
          const SizedBox(
            width: 35,
            child: Text(
              'PTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPurple,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REALTIME STANDINGS
  // ============================================================
  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('volleyball_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kPurple));
        }

        var data = snapshot.data!
            .where((d) => d['gender'] == selectedGender)
            .toList();

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'AUCUNE DONNÉE POUR CETTE LIGUE',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // === TRI OFFICIEL FIVB ===
        // 1. Points (3pts victoire, 2pts victoire golden set, 1pt défaite golden set, 0pt défaite 3-0/3-1)
        // 2. Ratio sets (sets gagnés / sets perdus)
        // 3. Ratio points (points marqués / points encaissés)
        data.sort((a, b) {
          // 1. Points
          final pA = a['points'] ?? 0;
          final pB = b['points'] ?? 0;
          if (pB != pA) return (pB as int).compareTo(pA);

          // 2. Ratio sets
          final setsRatioA = _setsRatio(a);
          final setsRatioB = _setsRatio(b);
          if ((setsRatioB - setsRatioA).abs() > 0.001) {
            return setsRatioB.compareTo(setsRatioA);
          }

          // 3. Ratio points
          final ptsRatioA = _pointsRatio(a);
          final ptsRatioB = _pointsRatio(b);
          return ptsRatioB.compareTo(ptsRatioA);
        });

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (context, index) =>
              _buildTeamRow(index + 1, data[index]),
        );
      },
    );
  }

  double _setsRatio(Map<String, dynamic> team) {
    final won = (team['sets_won'] ?? 0) as num;
    final lost = (team['sets_lost'] ?? 0) as num;
    return lost == 0 ? (won > 0 ? 999.0 : 1.0) : won / lost;
  }

  double _pointsRatio(Map<String, dynamic> team) {
    final scored = (team['points_scored'] ?? 0) as num;
    final conceded = (team['points_conceded'] ?? 0) as num;
    return conceded == 0 ? (scored > 0 ? 999.0 : 1.0) : scored / conceded;
  }

  // ============================================================
  // TEAM ROW
  // ============================================================
  Widget _buildTeamRow(int rank, Map<String, dynamic> team) {
    // Zones qualificatives (ex: top 4 = Champions, top 6 = Coupe)
    Color? zoneColor;
    if (rank <= 1) {
      zoneColor = kGold;
    } else if (rank <= 4)
      zoneColor = kPurple;
    else if (rank <= 6)
      zoneColor = kCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: zoneColor ?? Colors.transparent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // RANG
          SizedBox(
            width: 25,
            child: rank <= 3
                ? Text(
                    rank == 1
                        ? '🥇'
                        : rank == 2
                        ? '🥈'
                        : '🥉',
                    style: const TextStyle(fontSize: 16),
                  )
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: rank <= 6 ? kPurple : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
          // CLUB
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (team['team_logo'] != null &&
                          team['team_logo'].toString().isNotEmpty)
                      ? NetworkImage(team['team_logo'])
                      : null,
                  child:
                      (team['team_logo'] == null ||
                          team['team_logo'].toString().isEmpty)
                      ? const Icon(
                          Icons.sports_volleyball,
                          size: 13,
                          color: Colors.white24,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    team['team_name']?.toString().toUpperCase() ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // MJ
          _D('${team['played'] ?? 0}'),
          // V
          _D('${team['won'] ?? 0}', color: kGreen),
          // D
          _D('${team['lost'] ?? 0}', color: Colors.white38),
          // SETS POUR
          _D('${team['sets_won'] ?? 0}', color: Colors.white70),
          // SETS CONTRE
          _D('${team['sets_lost'] ?? 0}', color: Colors.white38),
          // POINTS
          SizedBox(
            width: 35,
            child: Text(
              '${team['points'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kPurple,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
