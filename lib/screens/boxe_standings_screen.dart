import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constantes de layout pour garantir l'alignement parfait
class BoxeLayout {
  static const double rankWidth = 30.0;
  static const double pointsWidth = 50.0;
  static const int nameFlex = 3;
  static const int statFlex = 1;
}

class BoxeStandingsScreen extends StatefulWidget {
  const BoxeStandingsScreen({super.key});

  @override
  State<BoxeStandingsScreen> createState() => _BoxeStandingsScreenState();
}

class _BoxeStandingsScreenState extends State<BoxeStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedGender = 'Masculin';
  String selectedWeightClass = 'TOUTES';
  bool isLoadingLeagues = true;

  // Couleurs
  static const Color kGold = Color(0xFFFFB800);
  static const Color kRed = Color(0xFFFF2D2D);
  static const Color kGreen = Color(0xFF00FF85);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  final List<String> weightClasses = [
    'TOUTES',
    '-49 KG',
    '-52 KG',
    '-56 KG',
    '-60 KG',
    '-64 KG',
    '-69 KG',
    '-75 KG',
    '-81 KG',
    '-86 KG',
    '-91 KG',
    '+91 KG',
  ];

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
          .eq('sport_type', 'boxing')
          .order('name');
      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) selectedLeagueId = data[0]['id'].toString();
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Boxe leagues: $e');
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  // Logique de traitement des données (séparée du build)
  List<Map<String, dynamic>> _getProcessedStandings(
    List<Map<String, dynamic>> data,
  ) {
    var filtered = data.where((d) {
      final gMatch = d['gender'] == selectedGender;
      final wMatch =
          selectedWeightClass == 'TOUTES' ||
          d['weight_class']?.toString().toUpperCase() == selectedWeightClass;
      return gMatch && wMatch;
    }).toList();

    filtered.sort((a, b) {
      final wA = (a['won'] ?? 0) as int;
      final wB = (b['won'] ?? 0) as int;
      if (wB != wA) return wB.compareTo(wA);

      final kA = (a['ko'] ?? 0) as int;
      final kB = (b['ko'] ?? 0) as int;
      if (kB != kA) return kB.compareTo(kA);

      return ((a['lost'] ?? 0) as int).compareTo((b['lost'] ?? 0) as int);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CLASSEMENT BOXE',
          style: TextStyle(
            color: kGold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildGenderSelector(),
                _buildWeightSelector(),
                _buildTableHeader(),
                Expanded(child: _buildRealtimeStandings()),
              ],
            ),
    );
  }

  // --- WIDGETS DE SÉLECTION ---

  Widget _buildLeagueSelector() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: leagues.length,
        itemBuilder: (_, i) {
          final l = leagues[i];
          final sel = selectedLeagueId == l['id'].toString();
          return GestureDetector(
            onTap: () => setState(() => selectedLeagueId = l['id'].toString()),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: sel ? kGold : kBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  l['name'].toString().toUpperCase(),
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white54,
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

  Widget _buildGenderSelector() {
    const genders = ['Masculin', 'Féminin'];
    const labels = ['HOMMES', 'FEMMES'];
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(2, (i) {
          final sel = selectedGender == genders[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedGender = genders[i]),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? kGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white38,
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

  Widget _buildWeightSelector() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: weightClasses.length,
        itemBuilder: (_, i) {
          final w = weightClasses[i];
          final sel = selectedWeightClass == w;
          return GestureDetector(
            onTap: () => setState(() => selectedWeightClass = w),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? kGold.withOpacity(0.15) : kBg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel ? kGold : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    color: sel ? kGold : Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS D'AFFICHAGE ---

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: BoxeLayout.rankWidth,
            child: Text(
              '#',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          const Expanded(
            flex: BoxeLayout.nameFlex,
            child: Text(
              'BOXEUR',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _headerStat('V'),
          _headerStat('D'),
          _headerStat('N'),
          _headerStat('KO'),
          const SizedBox(
            width: BoxeLayout.pointsWidth,
            child: Text(
              'PTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kGold,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label) => Expanded(
    flex: BoxeLayout.statFlex,
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

  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('boxing_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Erreur', style: TextStyle(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGold));
        }

        final data = _getProcessedStandings(snap.data!);

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'AUCUN BOXEUR TROUVÉ',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (_, i) => _buildBoxerRow(i + 1, data[i]),
        );
      },
    );
  }

  Widget _buildBoxerRow(int rank, Map<String, dynamic> boxer) {
    final ko = (boxer['ko'] ?? 0) as int;
    final title = boxer['title_holder'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: title
              ? kGold.withOpacity(0.4)
              : (rank <= 3 ? kGold.withOpacity(0.1) : Colors.transparent),
          width: title ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: BoxeLayout.rankWidth,
            child: Text(
              rank <= 3
                  ? (rank == 1
                        ? '🥇'
                        : rank == 2
                        ? '🥈'
                        : '🥉')
                  : '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 8 ? kGold : Colors.white24,
                fontWeight: FontWeight.bold,
                fontSize: rank <= 3 ? 14 : 11,
              ),
            ),
          ),
          Expanded(
            flex: BoxeLayout.nameFlex,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (boxer['boxer_photo'] != null &&
                          boxer['boxer_photo'].toString().isNotEmpty)
                      ? NetworkImage(boxer['boxer_photo'])
                      : null,
                  child:
                      (boxer['boxer_photo'] == null ||
                          boxer['boxer_photo'].toString().isEmpty)
                      ? const Icon(
                          Icons.sports_mma,
                          size: 16,
                          color: Colors.white24,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              boxer['boxer_name']?.toString().toUpperCase() ??
                                  '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (title)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: const Text(
                                '🏆',
                                style: TextStyle(fontSize: 8),
                              ),
                            ),
                        ],
                      ),
                      if (boxer['nationality'] != null)
                        Text(
                          boxer['nationality'].toString(),
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
          _statCell('${boxer['won'] ?? 0}', kGreen),
          _statCell('${boxer['lost'] ?? 0}', Colors.white38),
          _statCell('${boxer['drawn'] ?? 0}', Colors.white70),
          _statCell('$ko', ko > 0 ? kRed : Colors.white38, bold: ko > 0),
          SizedBox(
            width: BoxeLayout.pointsWidth,
            child: Text(
              '${boxer['points'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kGold,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String val, Color color, {bool bold = false}) => Expanded(
    flex: BoxeLayout.statFlex,
    child: Text(
      val,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      ),
    ),
  );
}
