import 'package:flutter/material.dart';
import 'legend_sanctuary_screen.dart';

class HallOfFameGridScreen extends StatelessWidget {
  // Cette liste sera remplie par ton appel Supabase
  final List<dynamic> legends;

  const HallOfFameGridScreen({super.key, required this.legends});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "LE TEMPLE DES LIONS",
          style: TextStyle(
            color: Color(0xFF00FF85),
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 14,
            fontFamily: 'Orbitron',
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.amber,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: legends.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    2, // 2 par ligne pour plus de détails et de "poids" visuel
                childAspectRatio: 0.75,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: legends.length,
              itemBuilder: (context, index) {
                return _buildGridPlayerCard(context, legends[index]);
              },
            ),
    );
  }

  Widget _buildGridPlayerCard(
    BuildContext context,
    Map<String, dynamic> legend,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LegendSanctuaryScreen(legendData: legend),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // IMAGE DE LA LÉGENDE
              Image.network(
                legend['img_url'] ??
                    "https://via.placeholder.com/300x400", // Modifié pour Supabase
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.person, color: Colors.white10),
                ),
              ),

              // DÉGRADÉ DE PROFONDEUR
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.95),
                    ],
                  ),
                ),
              ),

              // INFOS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (legend['title'] ?? "LÉGENDE").toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      legend['name']?.toString().toUpperCase() ?? "NOM",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye,
                          color: Color(0xFF00FF85),
                          size: 10,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          "VOIR L'HÉRITAGE",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text(
            "LES LIONS SE PRÉPARENT...",
            style: TextStyle(
              color: Colors.white24,
              fontFamily: 'Orbitron',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
