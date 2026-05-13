import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'specific_match_list.dart';

class LocalLeagueScreen extends StatefulWidget {
  const LocalLeagueScreen({super.key});

  @override
  State<LocalLeagueScreen> createState() => _LocalLeagueScreenState();
}

class _LocalLeagueScreenState extends State<LocalLeagueScreen>
    with AutomaticKeepAliveClientMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  String selectedSport = "football";

  List<Map<String, dynamic>> _leagues = [];
  bool _isLoading = true;

  static const Map<String, Color> _sportColors = {
    'football': Color(0xFF00FF85),
    'basketball': Color(0xFFFFA500),
    'handball': Color(0xFFFF3131),
    'athletics': Color(0xFFFF6B00),
    'tennis': Color(0xFFC8FF00),
    'volleyball': Color(0xFF9B59FF),
    'karate': Color(0xFFFF0044),
    'boxing': Color(0xFFFFB800),
    'mma': Color(0xFF00CFFF),
  };

  Color get _currentSportColor =>
      _sportColors[selectedSport] ?? const Color(0xFF00FF85);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchLeagues();
  }

  // ── Fetch classique SELECT — contourne les issues RLS avec stream ──
  Future<void> _fetchLeagues() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('leagues')
          .select('*')
          .eq('sport_type', selectedSport)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _leagues = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur fetch leagues: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
      ),
      body: Column(
        children: [
          _buildSportSelector(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSportSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      height: 45,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            _sportTab("FOOTBALL", Icons.sports_soccer, "football"),
            _sportTab("BASKETBALL", Icons.sports_basketball, "basketball"),
            _sportTab("HANDBALL", Icons.sports_handball, "handball"),
            _sportTab("ATHLÉTISME", Icons.directions_run, "athletics"),
            _sportTab("TENNIS", Icons.sports_tennis, "tennis"),
            _sportTab("VOLLEYBALL", Icons.sports_volleyball, "volleyball"),
            _sportTab("KARATÉ", Icons.sports_martial_arts, "karate"),
            _sportTab("BOXE", Icons.sports_mma, "boxing"),
            _sportTab("MMA", Icons.sports_mma, "mma"),
          ],
        ),
      ),
    );
  }

  Widget _sportTab(String label, IconData icon, String sportKey) {
    final bool isActive = selectedSport == sportKey;
    final Color activeColor = _sportColors[sportKey] ?? const Color(0xFF00FF85);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          if (selectedSport == sportKey) return;
          setState(() => selectedSport = sportKey);
          _fetchLeagues(); // ← fetch à chaque changement de sport
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _currentSportColor),
      );
    }

    if (_leagues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: _currentSportColor.withOpacity(0.3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              "AUCUN CHAMPIONNAT\n${selectedSport.toUpperCase()} ACTIF",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _currentSportColor,
      backgroundColor: const Color(0xFF111111),
      onRefresh: _fetchLeagues,
      child: ListView.builder(
        itemCount: _leagues.length,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          final league = _leagues[i];
          final String gender = (league['gender'] ?? 'Masculin').toString();
          final bool isFem = gender.toLowerCase().contains('fém');
          final String? logo = league['logo'] ?? league['logo_url'];
          return _buildLeagueCard(
            league['id'].toString(),
            league['name'] ?? 'Championnat',
            gender,
            isFem,
            logo,
          );
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
    final Color mainColor = isFem
        ? const Color(0xFFFF007A)
        : _currentSportColor;

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
                sportType: selectedSport,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildLeagueLogo(logo, mainColor),
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
                    Icons.chevron_right,
                    color: mainColor.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueLogo(String? logo, Color mainColor) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mainColor.withOpacity(0.3), width: 1),
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
            : Icon(Icons.emoji_events_outlined, color: mainColor, size: 30),
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
}
