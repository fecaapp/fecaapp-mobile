import 'package:flutter/material.dart';

class LegendSanctuaryScreen extends StatelessWidget {
  final Map<String, dynamic> legendData;

  const LegendSanctuaryScreen({super.key, required this.legendData});

  @override
  Widget build(BuildContext context) {
    // Mapping des données avec les clés provenant de Supabase
    final String name = legendData['name'] ?? "NOM DE LA LÉGENDE";
    final String title = legendData['title'] ?? "ICÔNE NATIONALE";
    final String imgUrl = legendData['img_url'] ?? ""; // Correction pour le SQL
    final String bio = legendData['biography'] ?? "";
    final List palmares = legendData['palmares'] ?? [];
    final String citation =
        legendData['citation'] ?? "L'impossible n'est pas camerounais.";

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // L'ENTRÉE MONUMENTALE AVEC EFFET PARALLAX
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.65,
            backgroundColor: Colors.black,
            pinned: true,
            stretch: true,
            leading: _buildBackButton(context),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : Container(color: Colors.grey[900]),

                  // DÉGRADÉ PATRIOTIQUE SUBTIL
                  _buildPatrioticOverlay(),

                  // NOM ET TITRE SUR L'IMAGE
                  Positioned(
                    bottom: 40,
                    left: 25,
                    right: 25,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontSize: 12,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 45,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LE TABLEAU D'ARMES (STATS) - VERSION BOUCLIER
                    _buildShieldStats(legendData),

                    const SizedBox(height: 45),

                    // LA CITATION CÉLÈBRE
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.format_quote,
                            color: Colors.amber,
                            size: 40,
                          ),
                          Text(
                            "\"$citation\"",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Serif',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(width: 50, height: 2, color: Colors.amber),
                        ],
                      ),
                    ),

                    const SizedBox(height: 45),

                    // LE RÉCIT SACRÉ
                    const Text(
                      "L'HISTOIRE D'UN LION",
                      style: TextStyle(
                        color: Color(0xFF00FF85),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 2,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      bio,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 16,
                        height: 1.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 45),

                    // L'HÉRITAGE ÉTERNEL (PALMARÈS)
                    _buildEternalHeritage(palmares),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CircleAvatar(
        backgroundColor: Colors.black.withOpacity(0.5),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildPatrioticOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.4),
            Colors.black,
          ],
        ),
      ),
    );
  }

  Widget _buildShieldStats(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("BUTS", d['goals']?.toString() ?? "0"),
          _statItem("MATCHS", d['matches']?.toString() ?? "0"),
          _statItem(
            "CAN",
            d['can_titles']?.toString() ?? "0",
          ), // Correction SQL
          _statItem(
            "BALLON D'OR",
            d['awards_count']?.toString() ?? "0",
          ), // Correction SQL
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEternalHeritage(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "L'HÉRITAGE ÉTERNEL",
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 25),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: Colors.amber, size: 30),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
