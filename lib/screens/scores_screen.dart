import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'specific_match_list.dart';

class LocalLeagueScreen extends StatefulWidget {
  const LocalLeagueScreen({super.key});

  @override
  State<LocalLeagueScreen> createState() => _LocalLeagueScreenState();
}

class _LocalLeagueScreenState extends State<LocalLeagueScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> leagues = [];
  bool isLoading = true;
  bool hasError = false;

  // Gestion du sport sélectionné (par défaut football)
  String selectedSport = "football";

  @override
  void initState() {
    super.initState();
    _fetchLeagues();
  }

  // --- RÉCUPÉRATION FILTRÉE PAR SPORT ---
  Future<void> _fetchLeagues() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
      leagues = []; // On vide la liste pour l'animation de chargement
    });

    try {
      final data = await supabase
          .from('leagues')
          .select('*')
          .eq('sport_type', selectedSport) // Filtre dynamique
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          leagues = data as List<dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Supabase Leagues: $e");
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text(
          "FECAAPP ELITE",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2,
            color: Color(0xFF00FF85),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF85).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF00FF85), size: 20),
              onPressed: _fetchLeagues,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSportSelector(), // Nouveau sélecteur ajouté
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // --- SÉLECTEUR DE SPORT (INCLUSION HANDBALL) ---
  Widget _buildSportSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      height: 45,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _sportTab(
              "FOOTBALL",
              Icons.sports_soccer,
              "football",
              const Color(0xFF00FF85),
            ),
            const SizedBox(width: 10),
            _sportTab(
              "BASKETBALL",
              Icons.sports_basketball,
              "basketball",
              const Color(0xFFFFA500),
            ),
            const SizedBox(width: 10),
            _sportTab(
              "HANDBALL",
              Icons.sports_handball,
              "handball",
              const Color(0xFFFF3131),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sportTab(
    String label,
    IconData icon,
    String sportKey,
    Color activeColor,
  ) {
    bool isActive = selectedSport == sportKey;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() => selectedSport = sportKey);
          _fetchLeagues();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && leagues.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00FF85),
          strokeWidth: 2,
        ),
      );
    }

    if (hasError && leagues.isEmpty) return _buildErrorState();

    if (leagues.isEmpty && !isLoading) {
      return Center(
        child: Text(
          "AUCUN CHAMPIONNAT ${selectedSport.toUpperCase()} ACTIF",
          style: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeagues,
      color: const Color(0xFF00FF85),
      backgroundColor: Colors.black,
      child: ListView.builder(
        itemCount: leagues.length,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        itemBuilder: (context, i) {
          final league = leagues[i];
          final String lId = league['id'].toString();
          final String lName = league['name'] ?? "Championnat";
          final String lGender = league['gender'] ?? "Masculin";
          final String? lLogo = league['logo'] ?? league['logo_url'];
          final bool isFem = lGender.toLowerCase().contains('fém');

          return _buildLeagueCard(lId, lName, lGender, isFem, lLogo);
        },
      ),
    );
  }

  Widget _buildLeagueCard(
    String id,
    String name,
    String gender,
    bool isFem,
    String? logo,
  ) {
    // La couleur de la carte s'adapte maintenant aussi au sport sélectionné
    Color mainColor = isFem
        ? const Color(0xFFFF007A)
        : (selectedSport == "handball"
              ? const Color(0xFFFF3131)
              : const Color(0xFF00FF85));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpecificMatchListScreen(
                leagueName: name,
                leagueId: id,
                gender: gender,
                sportType: selectedSport, // Passage du sport sélectionné
              ),
            ),
          ),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              border: Border.all(color: mainColor.withOpacity(0.15), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [mainColor.withOpacity(0.08), Colors.transparent],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    isFem ? Icons.female : Icons.male,
                    size: 80,
                    color: mainColor.withOpacity(0.03),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: mainColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: (logo != null && logo.isNotEmpty)
                              ? Image.network(
                                  logo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.emoji_events_outlined,
                                    color: mainColor,
                                    size: 30,
                                  ),
                                )
                              : Icon(
                                  Icons.emoji_events_outlined,
                                  color: mainColor,
                                  size: 30,
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildBadge(
                                  isFem ? "DAMES" : "MESSIEURS",
                                  mainColor,
                                ),
                                const SizedBox(width: 8),
                                _buildBadge("ELITE", Colors.white38),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: mainColor.withOpacity(0.5),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white10, size: 70),
          const SizedBox(height: 20),
          const Text(
            "SYNCHRONISATION INTERROMPUE",
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF85),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: _fetchLeagues,
            child: const Text(
              "RECONNEXION",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
