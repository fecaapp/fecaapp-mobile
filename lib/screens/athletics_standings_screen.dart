import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// AthleticsStandingsScreen — v5.3
// ✅ Corrections :
//   1. Valeurs disciplines normalisées = identiques au dashboard HTML
//   2. Filtre league_id ajouté dans le stream standings
//   3. Filtre gender appliqué correctement
//   4. _parsePerf robuste (gère "m", ",", espaces)
//   5. Gestion erreur stream explicite
// ================================================================

class AthleticsStandingsScreen extends StatefulWidget {
  const AthleticsStandingsScreen({super.key});

  @override
  State<AthleticsStandingsScreen> createState() =>
      _AthleticsStandingsScreenState();
}

class _AthleticsStandingsScreenState extends State<AthleticsStandingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> leagues = [];
  String? selectedLeagueId;
  String selectedDiscipline = '100m';
  String selectedGender = 'Masculin';
  bool isLoadingLeagues = true;

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kGold = Color(0xFFFFD700);
  static const Color kGreen = Color(0xFF00FF85);
  static const Color kRed = Color(0xFFFF3B3B);
  static const Color kBg = Color(0xFF050505);
  static const Color kBg2 = Color(0xFF0D0D0D);
  static const Color kBg3 = Color(0xFF111111);

  // ✅ FIX CRITIQUE : valeurs identiques aux value= du <select> du dashboard HTML
  static const List<String> disciplines = [
    '100m',
    '200m',
    '400m',
    '800m',
    '1500m',
    '5000m',
    '10000m',
    'MARATHON',
    '110m HAIES',
    '400m HAIES',
    '3000m STEEPLE',
    '4×100m',
    '4×400m',
    'LONGUEUR',
    'HAUTEUR',
    'PERCHE',
    'TRIPLE SAUT',
    'POIDS',
    'DISQUE',
    'JAVELOT',
    'MARTEAU',
    'HEPTATHLON',
    'DÉCATHLON',
  ];

  // Labels affichés dans l'UI (plus lisibles)
  static const Map<String, String> disciplineLabels = {
    '100m': '100m',
    '200m': '200m',
    '400m': '400m',
    '800m': '800m',
    '1500m': '1500m',
    '5000m': '5000m',
    '10000m': '10 000m',
    'MARATHON': 'Marathon',
    '110m HAIES': '110m H.',
    '400m HAIES': '400m H.',
    '3000m STEEPLE': '3000m St.',
    '4×100m': '4×100m',
    '4×400m': '4×400m',
    'LONGUEUR': 'Longueur',
    'HAUTEUR': 'Hauteur',
    'PERCHE': 'Perche',
    'TRIPLE SAUT': 'Triple',
    'POIDS': 'Poids',
    'DISQUE': 'Disque',
    'JAVELOT': 'Javelot',
    'MARTEAU': 'Marteau',
    'HEPTATHLON': 'Heptathlon',
    'DÉCATHLON': 'Décathlon',
  };

  @override
  void initState() {
    super.initState();
    fetchLeagues();
  }

  Future<void> fetchLeagues() async {
    try {
      final data = await supabase
          .from('leagues')
          .select('id, name, gender')
          .eq('sport_type', 'athletics')
          .order('name');

      if (mounted) {
        setState(() {
          leagues = data;
          if (data.isNotEmpty) {
            selectedLeagueId = data[0]['id'].toString();
            // Pré-sélectionner le genre de la première ligue
            selectedGender = data[0]['gender']?.toString() ?? 'Masculin';
          }
          isLoadingLeagues = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur Ligues Athlétisme: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CLASSEMENT ATHLÉTISME',
          style: TextStyle(
            color: kOrange,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : leagues.isEmpty
          ? _buildEmpty('Aucune compétition disponible')
          : Column(
              children: [
                _buildLeagueSelector(),
                _buildGenderSelector(),
                _buildDisciplineSelector(),
                _buildTableHeader(),
                Expanded(child: _buildRealtimeStandings()),
              ],
            ),
    );
  }

  // ── Sélecteur ligue ───────────────────────────────────────────
  Widget _buildLeagueSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(top: 10, bottom: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: leagues.length,
        itemBuilder: (context, index) {
          final league = leagues[index];
          final isSelected = selectedLeagueId == league['id'].toString();
          final gender = league['gender']?.toString() ?? '';
          return GestureDetector(
            onTap: () => setState(() {
              selectedLeagueId = league['id'].toString();
              // ✅ Pré-sélectionner le genre de la ligue choisie
              selectedGender = gender.isNotEmpty ? gender : 'Masculin';
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? kOrange : kBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    league['name'].toString().toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white54,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                  if (gender.isNotEmpty)
                    Text(
                      gender == 'Masculin'
                          ? 'H'
                          : gender == 'Féminin'
                          ? 'F'
                          : 'MX',
                      style: TextStyle(
                        color: isSelected ? Colors.black54 : Colors.white24,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
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

  // ── Sélecteur genre ───────────────────────────────────────────
  Widget _buildGenderSelector() {
    const genders = ['Masculin', 'Féminin', 'Mixte'];
    const labels = ['HOMMES', 'FEMMES', 'MIXTE'];
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
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
                  color: isSelected ? kOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
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

  // ── Sélecteur discipline ──────────────────────────────────────
  Widget _buildDisciplineSelector() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: disciplines.length,
        itemBuilder: (context, index) {
          final disc = disciplines[index];
          final label = disciplineLabels[disc] ?? disc;
          final isSelected = selectedDiscipline == disc;
          return GestureDetector(
            onTap: () => setState(() => selectedDiscipline = disc),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? kOrange.withOpacity(0.15) : kBg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? kOrange : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? kOrange : Colors.white38,
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

  // ── En-tête tableau ───────────────────────────────────────────
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
            width: 28,
            child: Text(
              '#',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'ATHLÈTE',
              style: TextStyle(color: Colors.white30, fontSize: 9),
            ),
          ),
          _H('PAYS'),
          _H('PERF'),
          _H('VENT'),
          const SizedBox(
            width: 40,
            child: Text(
              'NOTE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kOrange,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stream classement ─────────────────────────────────────────
  Widget _buildRealtimeStandings() {
    if (selectedLeagueId == null) {
      return _buildEmpty('Sélectionnez une compétition');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      // ✅ FIX CRITIQUE : stream filtré par primaryKey uniquement,
      // filtrage métier fait en Dart pour éviter le bug du stream Supabase
      stream: supabase
          .from('athletics_standings')
          .stream(primaryKey: ['id'])
          .eq('league_id', selectedLeagueId!) // ✅ filtre par ligue
          .order('rank', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmpty('Erreur de chargement');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }

        // ✅ Filtrage discipline + gender en Dart
        // discipline : valeur normalisée ex. "100m", "LONGUEUR", "4×100m"
        // gender     : "Masculin" | "Féminin" | "Mixte"
        var data = snapshot.data!
            .where(
              (d) =>
                  d['discipline']?.toString() == selectedDiscipline &&
                  d['gender']?.toString() == selectedGender,
            )
            .toList();

        if (data.isEmpty) {
          return _buildEmpty(
            'Aucun résultat\n$selectedDiscipline · $selectedGender',
          );
        }

        // Tri par performance (le rank Supabase peut suffire mais on double-vérifie)
        data.sort(
          (a, b) => _parsePerf(
            a['performance'],
          ).compareTo(_parsePerf(b['performance'])),
        );

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (context, index) =>
              _buildAthleteRow(index + 1, data[index]),
        );
      },
    );
  }

  // ── Rangée athlète ────────────────────────────────────────────
  Widget _buildAthleteRow(int rank, Map<String, dynamic> athlete) {
    // ✅ Clés cohérentes avec dashboard : is_wr, is_pb
    final bool isWR = athlete['is_wr'] == true;
    final bool isPB = athlete['is_pb'] == true;
    final bool isDNF = athlete['dnf'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWR
              ? kGreen.withOpacity(0.3)
              : rank <= 3
              ? kOrange.withOpacity(0.15)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: isDNF
                ? const Text(
                    'DNF',
                    style: TextStyle(
                      color: kRed,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Text(
                    rank <= 3
                        ? (rank == 1
                              ? '🥇'
                              : rank == 2
                              ? '🥈'
                              : '🥉')
                        : '$rank',
                    style: TextStyle(
                      color: rank <= 3 ? kOrange : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: rank <= 3 ? 16 : 11,
                    ),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              athlete['athlete_name']?.toString().toUpperCase() ?? '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _getFlagEmoji(athlete['country']?.toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              isDNF ? 'DNF' : athlete['performance']?.toString() ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDNF ? kRed : kOrange,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              athlete['wind']?.toString().isNotEmpty == true
                  ? athlete['wind'].toString()
                  : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (isWR) _badge('RM', kGreen),
                if (isPB) ...[const SizedBox(height: 2), _badge('RP', kGold)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900),
    ),
  );

  // ✅ Parser performance robuste : "9.87", "2:01.34", "8.45m", "8,45m"
  double _parsePerf(dynamic perf) {
    String p =
        perf?.toString().trim().replaceAll(',', '.').replaceAll('m', '') ??
        '9999';
    if (p.contains(':')) {
      final parts = p.split(':');
      if (parts.length == 2) {
        return (double.tryParse(parts[0]) ?? 0) * 60 +
            (double.tryParse(parts[1]) ?? 0);
      }
    }
    return double.tryParse(p) ?? 9999;
  }

  String _getFlagEmoji(String? code) {
    const flags = {
      'CMR': '🇨🇲',
      'USA': '🇺🇸',
      'KEN': '🇰🇪',
      'ETH': '🇪🇹',
      'JAM': '🇯🇲',
      'FRA': '🇫🇷',
      'GBR': '🇬🇧',
      'NGA': '🇳🇬',
      'RSA': '🇿🇦',
      'MAR': '🇲🇦',
      'UGA': '🇺🇬',
      'TAN': '🇹🇿',
      'CIV': '🇨🇮',
      'GHA': '🇬🇭',
      'SEN': '🇸🇳',
      'BUR': '🇧🇫',
    };
    return flags[code?.toUpperCase()] ?? '🏴';
  }

  Widget _buildEmpty(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
