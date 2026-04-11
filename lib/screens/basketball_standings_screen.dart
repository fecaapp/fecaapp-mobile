import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importation de ton service (assure-toi que le chemin est correct)

class BasketballStandingsScreen extends StatefulWidget {
  const BasketballStandingsScreen({super.key});

  @override
  State<BasketballStandingsScreen> createState() =>
      _BasketballStandingsScreenState();
}

class _BasketballStandingsScreenState extends State<BasketballStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  // final MatchService _matchService = MatchService(); // Instance du service

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  bool isLoadingLeagues = true;

  @override
  void initState() {
    super.initState();
    fetchLeagues();
  }

  Future<void> fetchLeagues() async {
    try {
      // Récupération des ligues typées Basketball
      final data = await supabase
          .from('leagues')
          .select('id, name')
          .eq('sport_type', 'basketball')
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
      debugPrint("❌ Erreur Ligues Basket: $e");
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  // --- COMPOSANTS DE CELLULES ---
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
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CLASSEMENT BASKET",
          style: TextStyle(
            color: Color(0xFF00FF85),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF85)),
            )
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildHeader(),
                Expanded(child: _buildRealtimeStandings()),
              ],
            ),
    );
  }

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
          bool isSelected = selectedLeagueId == league['id'].toString();
          return GestureDetector(
            onTap: () =>
                setState(() => selectedLeagueId = league['id'].toString()),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00FF85)
                    : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white10,
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
          _H("P"),
          _H("PP"),
          _H("PC"),
          const SizedBox(
            width: 35,
            child: Text(
              "PTS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) return const SizedBox();

    // Utilisation directe du stream via la table basketball_standings
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('basketball_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Erreur de chargement",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF85)),
          );
        }

        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(
            child: Text(
              "AUCUNE DONNÉE POUR CETTE LIGUE",
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // --- TRI AUTOMATIQUE SELON NORMES FIBA/NBA ---
        final sortedData = List<Map<String, dynamic>>.from(data);
        sortedData.sort((a, b) {
          // 1. Points (2/1)
          int ptsA = a['points'] ?? 0;
          int ptsB = b['points'] ?? 0;
          if (ptsB != ptsA) return ptsB.compareTo(ptsA);

          // 2. Différence de points (Points Pour - Points Contre)
          int diffA = (a['points_for'] ?? 0) - (a['points_against'] ?? 0);
          int diffB = (b['points_for'] ?? 0) - (b['points_against'] ?? 0);
          if (diffB != diffA) return diffB.compareTo(diffA);

          // 3. Points marqués (Attaque)
          return (b['points_for'] ?? 0).compareTo(a['points_for'] ?? 0);
        });

        return ListView.builder(
          itemCount: sortedData.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (context, index) =>
              _buildTeamRow(index + 1, sortedData[index]),
        );
      },
    );
  }

  Widget _buildTeamRow(int rank, Map<String, dynamic> team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 25,
            child: Text(
              "$rank",
              style: TextStyle(
                color: rank <= 4 ? const Color(0xFF00FF85) : Colors.white24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
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
                          Icons.sports_basketball,
                          size: 12,
                          color: Colors.white24,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    team['team_name'].toString().toUpperCase(),
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
          _D("${team['played'] ?? 0}"),
          _D("${team['won'] ?? 0}"),
          _D("${team['lost'] ?? 0}"),
          _D("${team['points_for'] ?? 0}"),
          _D("${team['points_against'] ?? 0}"),
          SizedBox(
            width: 35,
            child: Text(
              "${team['points'] ?? 0}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
