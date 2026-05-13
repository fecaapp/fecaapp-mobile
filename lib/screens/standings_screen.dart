import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'basketball_standings_screen.dart';
import 'handball_standings_screen.dart';
import 'athletics_standings_screen.dart';
import 'tennis_standings_screen.dart';
import 'volleyball_standings_screen.dart';
import 'karate_standings_screen.dart';
import 'boxe_standings_screen.dart';
import 'mma_standings_screen.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String? selectedLeagueName;
  bool isLoadingLeagues = true;

  // --- GESTION DU SPORT ---
  String selectedSport = "football";

  @override
  void initState() {
    super.initState();
    fetchLeagues();
  }

  // Récupération initiale des compétitions (filtrées par sport sélectionné)
  Future<void> fetchLeagues() async {
    try {
      final data = await supabase
          .from('leagues')
          .select('id, name')
          .eq('sport_type', selectedSport) // Filtrage par sport
          .order('name');

      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) {
            selectedLeagueId = data[0]['id'].toString();
            selectedLeagueName = data[0]['name'].toString();
          } else {
            selectedLeagueId = null;
            selectedLeagueName = null;
          }
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur Ligues Supabase: $e");
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  // Couleur thématique dynamique
  Color get _activeColor {
    switch (selectedSport) {
      case 'basketball':
        return const Color(0xFFFFA500);
      case 'handball':
        return const Color(0xFFFF3131);
      case 'athletics':
        return const Color(0xFFFF6B00);
      case 'tennis':
        return const Color(0xFFC8FF00);
      case 'volleyball':
        return const Color(0xFF9B59FF);
      case 'karate':
        return const Color(0xFFFF0044);
      case 'boxing':
        return const Color(0xFFFFB800);
      case 'mma':
        return const Color(0xFF00FF85);
      default:
        return const Color(0xFF00FF85);
    }
  }

  // --- COMPOSANTS UI DE DONNÉES ---
  Widget _H(String label) => Expanded(
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

  Widget _D(String val, {Color color = Colors.white70}) => Expanded(
    child: Text(
      val,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "FECAAPP CLASSEMENT",
          style: TextStyle(
            color: _activeColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSportToggle(),
          isLoadingLeagues
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: _activeColor),
                  ),
                )
              : Expanded(child: _buildConditionalBody()),
        ],
      ),
    );
  }

  Widget _buildConditionalBody() {
    switch (selectedSport) {
      case 'basketball':
        return const BasketballStandingsScreen();
      case 'handball':
        return const HandballStandingsScreen();
      case 'athletics':
        return const AthleticsStandingsScreen();
      case 'tennis':
        return const TennisStandingsScreen();
      case 'volleyball':
        return const VolleyballStandingsScreen();
      case 'karate':
        return const KarateStandingsScreen();
      case 'boxing':
        return const BoxeStandingsScreen();
      case 'mma':
        return const MmaStandingsScreen();
      default:
        return Column(
          children: [
            _buildLeagueSelector(),
            _buildHeader(),
            Expanded(child: _buildRealtimeStandings()),
          ],
        );
    }
  }

  // --- COMMUTATEUR DE SPORT ---
  Widget _buildSportToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 20),
            _sportButton(
              "FOOTBALL",
              Icons.sports_soccer,
              "football",
              const Color(0xFF00FF85),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "BASKETBALL",
              Icons.sports_basketball,
              "basketball",
              const Color(0xFFFFA500),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "HANDBALL",
              Icons.sports_handball,
              "handball",
              const Color(0xFFFF3131),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "ATHLÉTISME",
              Icons.directions_run,
              "athletics",
              const Color(0xFFFF6B00),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "TENNIS",
              Icons.sports_tennis,
              "tennis",
              const Color(0xFFC8FF00),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "VOLLEYBALL",
              Icons.sports_volleyball,
              "volleyball",
              const Color(0xFF9B59FF),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "KARATÉ",
              Icons.sports_martial_arts,
              "karate",
              const Color(0xFFFF0044),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "BOXE",
              Icons.sports_mma,
              "boxing",
              const Color(0xFFFFB800),
            ),
            const SizedBox(width: 25),
            _sportButton(
              "MMA",
              Icons.sports_mma,
              "mma",
              const Color(0xFF00FF85),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _sportButton(
    String label,
    IconData icon,
    String sportKey,
    Color themeColor,
  ) {
    bool isActive = selectedSport == sportKey;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() {
            selectedSport = sportKey;
            isLoadingLeagues = true;
          });
          fetchLeagues();
        }
      },
      child: Opacity(
        opacity: isActive ? 1.0 : 0.3,
        child: Column(
          children: [
            Icon(icon, color: isActive ? themeColor : Colors.white, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? themeColor : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SÉLECTEUR DE LIGUES (Horizontal)
  Widget _buildLeagueSelector() {
    if (leagues.isEmpty) return const SizedBox();
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: leagues.length,
        itemBuilder: (context, index) {
          final league = leagues[index];
          bool isSelected = selectedLeagueId == league['id'].toString();
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedLeagueId = league['id'].toString();
                selectedLeagueName = league['name'].toString();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? _activeColor
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white12,
                ),
              ),
              child: Center(
                child: Text(
                  league['name'].toString().toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 25,
            child: Text(
              "#",
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              "CLUB",
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _H("J"),
          _H("G"),
          _H("N"),
          _H("P"),
          _H("DIFF"),
          SizedBox(
            width: 35,
            child: Text(
              "PTS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _activeColor,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STREAM EN TEMPS RÉEL (FLUX SUPABASE) ---
  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!)
          .order('points', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Erreur flux: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _activeColor));
        }

        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(
            child: Text(
              "AUCUNE ÉQUIPE ENREGISTRÉE",
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final sortedData = List<Map<String, dynamic>>.from(data);
        sortedData.sort((a, b) {
          int ptsA = a['points'] ?? 0;
          int ptsB = b['points'] ?? 0;
          if (ptsB != ptsA) return ptsB.compareTo(ptsA);

          int diffA = (a['goals_for'] ?? 0) - (a['goals_against'] ?? 0);
          int diffB = (b['goals_for'] ?? 0) - (b['goals_against'] ?? 0);
          if (diffB != diffA) return diffB.compareTo(diffA);

          return (b['goals_for'] ?? 0).compareTo(a['goals_for'] ?? 0);
        });

        return ListView.builder(
          itemCount: sortedData.length,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          itemBuilder: (context, index) =>
              _buildTeamRow(index + 1, sortedData[index], sortedData.length),
        );
      },
    );
  }

  Widget _buildTeamRow(int rank, Map<String, dynamic> team, int totalTeams) {
    int diff = (team['goals_for'] ?? 0) - (team['goals_against'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: rank <= 3
                ? _activeColor
                : (rank > totalTeams - 2 ? Colors.red : Colors.transparent),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 25,
            child: Text(
              "$rank",
              style: TextStyle(
                color: rank <= 3 ? _activeColor : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    team['team_logo'] ?? "",
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.shield,
                      size: 20,
                      color: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    team['team_name'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _D("${team['played'] ?? 0}"),
          _D("${team['won'] ?? 0}"),
          _D("${team['drawn'] ?? 0}"),
          _D("${team['lost'] ?? 0}"),
          _D(
            "${diff > 0 ? '+$diff' : diff}",
            color: diff >= 0 ? Colors.white70 : Colors.redAccent,
          ),
          SizedBox(
            width: 35,
            child: Text(
              "${team['points'] ?? 0}",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _activeColor,
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
