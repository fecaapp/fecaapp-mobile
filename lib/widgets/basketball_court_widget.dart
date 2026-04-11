import 'package:flutter/material.dart';

class BasketballCourtWidget extends StatelessWidget {
  final List<String> lineup1; // 5 joueurs équipe 1 (Haut)
  final List<String> lineup2; // 5 joueurs équipe 2 (Bas)
  final String stadium;

  const BasketballCourtWidget({
    super.key,
    required this.lineup1,
    required this.lineup2,
    this.stadium = "ARENA",
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- NOM DU STADE / ARENA ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            stadium.toUpperCase(),
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),

        // --- TERRAIN DE BASKET ---
        AspectRatio(
          aspectRatio: 0.7, // Format vertical optimisé mobile
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: Stack(
              children: [
                // --- DESSIN DU TERRAIN (LIGNES BLANCHES) ---
                Positioned.fill(child: CustomPaint(painter: _CourtPainter())),

                // --- POSITIONNEMENT DES JOUEURS ---
                _buildPlayersOverlay(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPlayersOverlay() {
    // Coordonnées (x, y) relatives pour un 5 majeur standard
    final positions = [
      [0.5, 0.15], // Meneur (PG) - Central
      [0.2, 0.30], // Arrière (SG) - Côté gauche
      [0.8, 0.30], // Ailier (SF) - Côté droit
      [0.3, 0.42], // Ailier Fort (PF) - Près raquette gauche
      [0.7, 0.42], // Pivot (C) - Près raquette droite
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Équipe 1 (Haut - Couleur Verte FecaApp)
            for (int i = 0; i < lineup1.length && i < 5; i++)
              _playerIcon(
                lineup1[i],
                positions[i][0] * constraints.maxWidth,
                positions[i][1] * constraints.maxHeight,
                const Color(0xFF00FF85),
              ),

            // Équipe 2 (Bas - Couleur Blanche/Gris clair)
            for (int i = 0; i < lineup2.length && i < 5; i++)
              _playerIcon(
                lineup2[i],
                positions[i][0] * constraints.maxWidth,
                (1 - positions[i][1]) *
                    constraints.maxHeight, // Inversion axe Y
                Colors.white,
              ),
          ],
        );
      },
    );
  }

  Widget _playerIcon(String name, double x, double y, Color color) {
    return Positioned(
      left: x - 25,
      top: y - 25,
      child: SizedBox(
        width: 50,
        child: Column(
          children: [
            // Avatar du joueur
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.2), blurRadius: 4),
                ],
              ),
              child: const Icon(Icons.person, size: 12, color: Colors.white),
            ),
            const SizedBox(height: 4),
            // Nom du joueur (Dernier mot uniquement pour la lisibilité)
            Text(
              name.split(' ').last.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Ligne médiane
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Cercle central
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, paint);

    // --- ZONE ÉQUIPE HAUT ---
    // Raquette (Zone restrictive)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height * 0.2),
      paint,
    );
    // Ligne à 3 points (Arc supérieur)
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.1,
        -size.height * 0.1,
        size.width * 0.8,
        size.height * 0.35,
      ),
      0,
      3.14,
      false,
      paint,
    );

    // --- ZONE ÉQUIPE BAS ---
    // Raquette (Zone restrictive)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.8,
        size.width * 0.4,
        size.height * 0.2,
      ),
      paint,
    );
    // Ligne à 3 points (Arc inférieur)
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.75,
        size.width * 0.8,
        size.height * 0.35,
      ),
      3.14,
      3.14,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
