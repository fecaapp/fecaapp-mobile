import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KarateStandingsScreen extends StatefulWidget {
  const KarateStandingsScreen({super.key});

  @override
  State<KarateStandingsScreen> createState() => _KarateStandingsScreenState();
}

class _KarateStandingsScreenState extends State<KarateStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedGender = 'Masculin';
  String selectedWeightClass = 'TOUTES';
  String selectedDiscipline = 'kumite';
  bool isLoadingLeagues = true;

  static const Color kRed = Color(0xFFFF0044);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  final List<String> weightClassesM = [
    'TOUTES',
    '-60 KG',
    '-67 KG',
    '-75 KG',
    '-84 KG',
    '+84 KG',
  ];
  final List<String> weightClassesF = [
    'TOUTES',
    '-50 KG',
    '-55 KG',
    '-61 KG',
    '-68 KG',
    '+68 KG',
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
          .eq('sport_type', 'karate')
          .order('name');
      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) selectedLeagueId = data[0]['id'].toString();
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Karaté leagues: $e');
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  List<String> get _weightList =>
      selectedGender == 'Féminin' ? weightClassesF : weightClassesM;

  // HEADER CELLS
  Widget _H(String l, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      l,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white30,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _D(
    String v, {
    Color color = Colors.white70,
    int flex = 1,
    bool bold = false,
  }) => Expanded(
    flex: flex,
    child: Text(
      v,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
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
          'CLASSEMENT KARATÉ',
          style: TextStyle(
            color: kRed,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kRed))
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildDisciplineGenderRow(),
                _buildWeightClassSelector(),
                _buildTableHeader(),
                Expanded(child: _buildRealtimeStandings()),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // LEAGUE SELECTOR
  // ──────────────────────────────────────────────────────────
  Widget _buildLeagueSelector() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 10, bottom: 5),
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
                color: sel ? kRed : kBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  l['name'].toString().toUpperCase(),
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
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

  // ──────────────────────────────────────────────────────────
  // DISCIPLINE + GENRE
  // ──────────────────────────────────────────────────────────
  Widget _buildDisciplineGenderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          // DISCIPLINE
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: kBg2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _segBtn(
                    'KUMITE',
                    selectedDiscipline == 'kumite',
                    () => setState(() => selectedDiscipline = 'kumite'),
                    kRed,
                  ),
                  _segBtn(
                    'KATA',
                    selectedDiscipline == 'kata',
                    () => setState(() => selectedDiscipline = 'kata'),
                    kRed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // GENRE
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: kBg2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _segBtn(
                    'HOMMES',
                    selectedGender == 'Masculin',
                    () => setState(() {
                      selectedGender = 'Masculin';
                      selectedWeightClass = 'TOUTES';
                    }),
                    kRed,
                  ),
                  _segBtn(
                    'FEMMES',
                    selectedGender == 'Féminin',
                    () => setState(() {
                      selectedGender = 'Féminin';
                      selectedWeightClass = 'TOUTES';
                    }),
                    kRed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // WEIGHT CLASS SELECTOR
  // ──────────────────────────────────────────────────────────
  Widget _buildWeightClassSelector() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _weightList.length,
        itemBuilder: (_, i) {
          final w = _weightList[i];
          final sel = selectedWeightClass == w;
          return GestureDetector(
            onTap: () => setState(() => selectedWeightClass = w),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? kRed.withOpacity(0.15) : kBg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel ? kRed : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    color: sel ? kRed : Colors.white38,
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

  // ──────────────────────────────────────────────────────────
  // TABLE HEADER
  // ──────────────────────────────────────────────────────────
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
            width: 25,
            child: Text(
              '#',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'COMBATTANT',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _H('CAT.'),
          _H('V'),
          _H('D'),
          _H('N'),
          const SizedBox(
            width: 40,
            child: Text(
              'ORE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kRed,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // REALTIME STANDINGS
  // ──────────────────────────────────────────────────────────
  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('karate_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Erreur', style: TextStyle(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kRed));
        }

        var data = snap.data!.where((d) {
          final gMatch = d['gender'] == selectedGender;
          final dMatch = d['discipline'] == selectedDiscipline;
          final wMatch =
              selectedWeightClass == 'TOUTES' ||
              d['weight_class']?.toString().toUpperCase() ==
                  selectedWeightClass;
          return gMatch && dMatch && wMatch;
        }).toList();

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'AUCUN RÉSULTAT POUR CETTE CATÉGORIE',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // Tri : Médailles d'or → argent → bronze → points
        data.sort((a, b) {
          final goldA = (a['gold'] ?? 0) as int;
          final goldB = (b['gold'] ?? 0) as int;
          if (goldB != goldA) return goldB.compareTo(goldA);
          final silvA = (a['silver'] ?? 0) as int;
          final silvB = (b['silver'] ?? 0) as int;
          if (silvB != silvA) return silvB.compareTo(silvA);
          final bronA = (a['bronze'] ?? 0) as int;
          final bronB = (b['bronze'] ?? 0) as int;
          return bronB.compareTo(bronA);
        });

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (_, i) => _buildFighterRow(i + 1, data[i]),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // FIGHTER ROW
  // ──────────────────────────────────────────────────────────
  Widget _buildFighterRow(int rank, Map<String, dynamic> f) {
    final gold = f['gold'] ?? 0;
    final silver = f['silver'] ?? 0;
    final bronze = f['bronze'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank == 1
              ? kGold.withOpacity(0.3)
              : rank <= 3
              ? kRed.withOpacity(0.12)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
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
                      color: rank <= 8 ? kRed : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // Photo
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (f['fighter_photo'] != null &&
                          f['fighter_photo'].toString().isNotEmpty)
                      ? NetworkImage(f['fighter_photo'])
                      : null,
                  child:
                      (f['fighter_photo'] == null ||
                          f['fighter_photo'].toString().isEmpty)
                      ? const Icon(
                          Icons.sports_martial_arts,
                          size: 15,
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
                        f['fighter_name']?.toString().toUpperCase() ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (f['club'] != null)
                        Text(
                          f['club'].toString(),
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
          // CAT
          _D(f['weight_class']?.toString() ?? '—', color: Colors.white54),
          // V
          _D('${f['won'] ?? 0}', color: Colors.green),
          // D
          _D('${f['lost'] ?? 0}', color: Colors.white38),
          // N
          _D('${f['drawn'] ?? 0}'),
          // ORE (médailles)
          SizedBox(
            width: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (gold > 0)
                  Text('🥇$gold', style: const TextStyle(fontSize: 9)),
                if (silver > 0)
                  Text('🥈$silver', style: const TextStyle(fontSize: 9)),
                if (bronze > 0)
                  Text('🥉$bronze', style: const TextStyle(fontSize: 9)),
                if (gold + silver + bronze == 0)
                  Text(
                    '${f['points'] ?? 0}',
                    style: const TextStyle(
                      color: kRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
