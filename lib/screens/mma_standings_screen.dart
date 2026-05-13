import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MmaStandingsScreen extends StatefulWidget {
  const MmaStandingsScreen({super.key});

  @override
  State<MmaStandingsScreen> createState() => _MmaStandingsScreenState();
}

class _MmaStandingsScreenState extends State<MmaStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedGender = 'Masculin';
  String selectedWeightClass = 'TOUTES';
  bool isLoadingLeagues = true;

  static const Color kGreen = Color(0xFF00FF85);
  static const Color kRed = Color(0xFFFF2D2D);
  static const Color kBlue = Color(0xFF00D1FF);
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  final List<String> weightClassesM = [
    'TOUTES',
    '-52 KG',
    '-57 KG',
    '-61 KG',
    '-66 KG',
    '-70 KG',
    '-77 KG',
    '-84 KG',
    '-93 KG',
    '-120 KG',
    '+120 KG',
  ];
  final List<String> weightClassesF = [
    'TOUTES',
    '-48 KG',
    '-52 KG',
    '-56 KG',
    '-61 KG',
    '-66 KG',
    '-70 KG',
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
          .eq('sport_type', 'mma')
          .order('name');
      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) selectedLeagueId = data[0]['id'].toString();
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint('❌ MMA leagues: $e');
      if (mounted) setState(() => isLoadingLeagues = false);
    }
  }

  List<String> get _weightList =>
      selectedGender == 'Féminin' ? weightClassesF : weightClassesM;

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
          'CLASSEMENT MMA',
          style: TextStyle(
            color: kGreen,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kGreen))
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

  // ──────────────────────────────────────────────────────────
  // LEAGUE SELECTOR
  // ──────────────────────────────────────────────────────────
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
                color: sel ? kGreen : kBg2,
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

  // ──────────────────────────────────────────────────────────
  // GENDER SELECTOR
  // ──────────────────────────────────────────────────────────
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
              onTap: () => setState(() {
                selectedGender = genders[i];
                selectedWeightClass = 'TOUTES';
              }),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? kGreen : Colors.transparent,
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

  // ──────────────────────────────────────────────────────────
  // WEIGHT CLASS SELECTOR
  // ──────────────────────────────────────────────────────────
  Widget _buildWeightSelector() {
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
                color: sel ? kGreen.withOpacity(0.15) : kBg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel ? kGreen : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    color: sel ? kGreen : Colors.white38,
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
  // Colonnes : V / D / KO / TKO / SUB / PTS
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
          _H('V'),
          _H('D'),
          _H('KO'),
          _H('SUB'),
          const SizedBox(
            width: 40,
            child: Text(
              'PTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kGreen,
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
          .from('mma_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!),
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('Erreur', style: TextStyle(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreen));
        }

        var data = snap.data!.where((d) {
          final gMatch = d['gender'] == selectedGender;
          final wMatch =
              selectedWeightClass == 'TOUTES' ||
              d['weight_class']?.toString().toUpperCase() ==
                  selectedWeightClass;
          return gMatch && wMatch;
        }).toList();

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'AUCUN COMBATTANT POUR CETTE CATÉGORIE',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // Tri : points DESC, victoires DESC, KO+TKO DESC, défaites ASC
        data.sort((a, b) {
          final pA = (a['points'] ?? 0) as int;
          final pB = (b['points'] ?? 0) as int;
          if (pB != pA) return pB.compareTo(pA);
          final wA = (a['won'] ?? 0) as int;
          final wB = (b['won'] ?? 0) as int;
          if (wB != wA) return wB.compareTo(wA);
          final kA = ((a['ko'] ?? 0) as int) + ((a['tko'] ?? 0) as int);
          final kB = ((b['ko'] ?? 0) as int) + ((b['tko'] ?? 0) as int);
          if (kB != kA) return kB.compareTo(kA);
          return ((a['lost'] ?? 0) as int).compareTo((b['lost'] ?? 0) as int);
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
    final ko = (f['ko'] ?? 0) as int;
    final tko = (f['tko'] ?? 0) as int;
    final sub = (f['submission'] ?? 0) as int;
    final isChamp = f['is_champion'] == true;
    final isContender = f['is_contender'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChamp
              ? kGold.withOpacity(0.5)
              : rank == 1
              ? kGreen.withOpacity(0.3)
              : rank <= 5
              ? kGreen.withOpacity(0.1)
              : Colors.transparent,
          width: isChamp ? 1.5 : 1,
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
                      color: rank <= 10 ? kGreen : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),

          // COMBATTANT
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white10,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child:
                        (f['fighter_photo'] != null &&
                            f['fighter_photo'].toString().isNotEmpty)
                        ? Image.network(
                            f['fighter_photo'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.sports_mma,
                              size: 18,
                              color: Colors.white24,
                            ),
                          )
                        : const Icon(
                            Icons.sports_mma,
                            size: 18,
                            color: Colors.white24,
                          ),
                  ),
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
                              f['fighter_name']?.toString().toUpperCase() ??
                                  '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isChamp)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('🏆', style: TextStyle(fontSize: 10)),
                            ),
                          if (isContender && !isChamp)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: kGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: kGreen.withOpacity(0.4),
                                ),
                              ),
                              child: const Text(
                                '#1',
                                style: TextStyle(
                                  color: kGreen,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          if (f['nationality'] != null)
                            Text(
                              f['nationality'].toString(),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8,
                              ),
                            ),
                          if (f['stance'] != null) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.white12,
                                fontSize: 8,
                              ),
                            ),
                            Text(
                              f['stance'].toString().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // V
          _D('${f['won'] ?? 0}', color: kGreen),
          // D
          _D('${f['lost'] ?? 0}', color: Colors.white38),
          // KO (KO+TKO)
          _D(
            '${ko + tko}',
            color: (ko + tko) > 0 ? kRed : Colors.white38,
            bold: (ko + tko) > 0,
          ),
          // SUB
          _D('$sub', color: sub > 0 ? kOrange : Colors.white38, bold: sub > 0),
          // PTS
          SizedBox(
            width: 40,
            child: Text(
              '${f['points'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kGreen,
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
