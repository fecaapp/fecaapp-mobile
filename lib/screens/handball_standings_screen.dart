import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HandballStandingsScreen extends StatefulWidget {
  const HandballStandingsScreen({super.key});

  @override
  State<HandballStandingsScreen> createState() =>
      _HandballStandingsScreenState();
}

class _HandballStandingsScreenState extends State<HandballStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> leagues = [];
  String? selectedLeagueId;
  bool isLoadingLeagues = true;

  // Nouvelle couleur thématique Handball : VERT FLASHY
  final Color handColor = const Color(0xFF00FF85);

  @override
  void initState() {
    super.initState();
    _fetchLeagues();
  }

  Future<void> _fetchLeagues() async {
    try {
      final data = await supabase
          .from('leagues')
          .select('id, name')
          .eq('sport_type', 'handball')
          .order('name');

      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) {
            selectedLeagueId = data[0]['id'].toString();
          }
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur Ligues Hand: $e");
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

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
          "FECAAPP HANDBALL",
          style: TextStyle(
            color: handColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          isLoadingLeagues
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: handColor),
                  ),
                )
              : Expanded(
                  child: Column(
                    children: [
                      _buildLeagueSelector(),
                      _buildHeader(),
                      Expanded(child: _buildRealtimeStandings()),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

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
            onTap: () =>
                setState(() => selectedLeagueId = league['id'].toString()),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? handColor : Colors.white.withOpacity(0.05),
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
                color: handColor,
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

    // Utilisation du stream pour une mise à jour instantanée dès la clôture
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('handball_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text("Erreur flux", style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: handColor));
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(
            child: Text(
              "AUCUNE ÉQUIPE",
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          );
        }

        // Tri propre : Points > Différence > Buts Marqués
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
              _buildTeamRow(index + 1, sortedData[index]),
        );
      },
    );
  }

  Widget _buildTeamRow(int rank, Map<String, dynamic> team) {
    int diff = (team['goals_for'] ?? 0) - (team['goals_against'] ?? 0);
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: rank <= 3 ? handColor : Colors.transparent,
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
                color: rank <= 3 ? handColor : Colors.white38,
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
                  child:
                      (team['team_logo'] != null &&
                          team['team_logo'].isNotEmpty)
                      ? Image.network(
                          team['team_logo'],
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.shield,
                                size: 20,
                                color: Colors.white10,
                              ),
                        )
                      : const Icon(
                          Icons.shield,
                          size: 20,
                          color: Colors.white10,
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
                color: handColor,
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
