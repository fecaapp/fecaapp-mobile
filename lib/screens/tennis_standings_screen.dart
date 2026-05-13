import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TennisStandingsScreen extends StatefulWidget {
  const TennisStandingsScreen({super.key});

  @override
  State<TennisStandingsScreen> createState() => _TennisStandingsScreenState();
}

class _TennisStandingsScreenState extends State<TennisStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedCategory = 'Masculin';
  bool isLoadingLeagues = true;

  static const Color kLime = Color(0xFFC8FF00);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    fetchLeagues();
  }

  Future<void> fetchLeagues() async {
    try {
      final data = await supabase
          .from('leagues')
          .select('id, name')
          .eq('sport_type', 'tennis')
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
      debugPrint('❌ Erreur Ligues Tennis: $e');
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
          'CLASSEMENT TENNIS',
          style: TextStyle(
            color: kLime,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kLime))
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildCategorySelector(),
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
                color: isSelected ? kLime : kBg2,
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

  // ============================================================
  // CATEGORY SELECTOR (ATP / WTA / DOUBLE)
  // ============================================================
  Widget _buildCategorySelector() {
    final categories = ['Masculin', 'Féminin', 'Double', 'Mixte'];
    final labels = ['ATP', 'WTA', 'DOUBLE', 'MIXTE'];
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(categories.length, (i) {
          final isSelected = selectedCategory == categories[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = categories[i]),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
                    fontSize: 10,
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
              'JOUEUR',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _H('V'),
          _H('D'),
          _H('TITRES'),
          _H('% SETS'),
          const SizedBox(
            width: 45,
            child: Text(
              'PTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kLime,
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
          .from('tennis_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kLime));
        }

        var data = snapshot.data!
            .where((d) => d['gender'] == selectedCategory)
            .toList();

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'AUCUNE DONNÉE POUR CE TOURNOI',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // Tri : points décroissants, puis % sets, puis victoires
        data.sort((a, b) {
          final ptsA = a['points'] ?? 0;
          final ptsB = b['points'] ?? 0;
          if (ptsB != ptsA) return (ptsB as int).compareTo(ptsA);

          final setsA = _setsRatio(a);
          final setsB = _setsRatio(b);
          if ((setsB - setsA).abs() > 0.001) return setsB.compareTo(setsA);

          return ((b['won'] ?? 0) as int).compareTo((a['won'] ?? 0) as int);
        });

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (context, index) =>
              _buildPlayerRow(index + 1, data[index]),
        );
      },
    );
  }

  double _setsRatio(Map<String, dynamic> player) {
    final setsWon = (player['sets_won'] ?? 0) as num;
    final setsLost = (player['sets_lost'] ?? 0) as num;
    final total = setsWon + setsLost;
    return total == 0 ? 0.0 : setsWon / total;
  }

  // ============================================================
  // PLAYER ROW
  // ============================================================
  Widget _buildPlayerRow(int rank, Map<String, dynamic> player) {
    final setsRatio = _setsRatio(player);
    final titles = player['titles'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank == 1
              ? kGold.withOpacity(0.3)
              : rank <= 4
              ? kLime.withOpacity(0.12)
              : Colors.transparent,
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
                      color: rank <= 8 ? kLime : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
          // JOUEUR
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (player['player_photo'] != null &&
                          player['player_photo'].toString().isNotEmpty)
                      ? NetworkImage(player['player_photo'])
                      : null,
                  child:
                      (player['player_photo'] == null ||
                          player['player_photo'].toString().isEmpty)
                      ? const Icon(
                          Icons.sports_tennis,
                          size: 14,
                          color: Colors.white24,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['player_name']?.toString().toUpperCase() ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (player['nationality'] != null)
                        Text(
                          player['nationality'].toString(),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // V
          _D('${player['won'] ?? 0}', color: kLime),
          // D
          _D('${player['lost'] ?? 0}', color: Colors.white38),
          // TITRES
          _D(
            '$titles',
            color: titles > 0 ? kGold : Colors.white38,
            isBold: titles > 0,
          ),
          // % SETS
          _D('${(setsRatio * 100).toStringAsFixed(0)}%', color: Colors.white54),
          // POINTS
          SizedBox(
            width: 45,
            child: Text(
              '${player['points'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kLime,
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
