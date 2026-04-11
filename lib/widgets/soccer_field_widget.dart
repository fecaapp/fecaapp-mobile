import 'package:flutter/material.dart';

class SoccerFieldWidget extends StatelessWidget {
  final List<dynamic> lineup1;
  final List<dynamic> lineup2;
  final dynamic positions; // Récupération des positions JSON du dashboard
  final String? stadium;

  const SoccerFieldWidget({
    super.key,
    required this.lineup1,
    required this.lineup2,
    this.positions,
    this.stadium,
  });

  @override
  Widget build(BuildContext context) {
    final String stadiumName = stadium ?? "STADE OFFICIEL";

    return AspectRatio(
      aspectRatio: 0.7, // Ratio optimisé pour l'affichage vertical
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF143311),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // 1. LE TERRAIN (Pelouse HD + Tracés via CustomPaint)
              const Positioned.fill(
                child: CustomPaint(painter: StadiumPainter()),
              ),

              // 2. NOM DU STADE EN FILIGRANE
              Center(
                child: Opacity(
                  opacity: 0.05,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stadium, color: Colors.white, size: 60),
                      const SizedBox(height: 10),
                      Text(
                        stadiumName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. PLACEMENT DYNAMIQUE DES JOUEURS (REAL-TIME READY)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Équipe 1 (Haut)
                      ...lineup1.asMap().entries.map(
                        (entry) => _buildPlayer(
                          entry.value,
                          entry.key,
                          true,
                          constraints,
                        ),
                      ),
                      // Équipe 2 (Bas)
                      ...lineup2.asMap().entries.map(
                        (entry) => _buildPlayer(
                          entry.value,
                          entry.key,
                          false,
                          constraints,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(
    dynamic player,
    int index,
    bool isTeam1,
    BoxConstraints constraints,
  ) {
    // Coordonnées par défaut si non définies
    double x = 50.0;
    double y = isTeam1 ? 15.0 : 85.0;

    // Extraction des coordonnées (x, y) de l'objet positions envoyé par le Dashboard
    try {
      String teamKey = isTeam1 ? "team1" : "team2";
      if (positions != null &&
          positions[teamKey] != null &&
          positions[teamKey][index] != null) {
        x = double.parse(positions[teamKey][index]['x'].toString());
        y = double.parse(positions[teamKey][index]['y'].toString());
      }
    } catch (e) {
      // Fallback automatique en cas de données manquantes
    }

    // Calcul du positionnement en pixels
    final double left = (x / 100) * constraints.maxWidth;
    final double top = (y / 100) * constraints.maxHeight;

    // Parsing du nom (Format attendu : "Numéro. Nom")
    String fullName = (player is Map ? player['label'] : player.toString());
    String number = "0";
    String name = fullName;

    if (fullName.contains('.')) {
      var split = fullName.split('.');
      number = split[0].trim();
      name = split.sublist(1).join('.').trim();
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 900),
      curve: Curves.fastOutSlowIn,
      left: left - 25, // Centrage du widget
      top: top - 25,
      child: SizedBox(
        width: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône du Joueur (Rond/Maillot)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTeam1 ? const Color(0xFF00FF85) : Colors.blueAccent,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    color: isTeam1 ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Étiquette du Nom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StadiumPainter extends CustomPainter {
  const StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    // 1. DESSIN DE LA PELOUSE (Bandes alternées)
    final grassPaint = Paint()..style = PaintingStyle.fill;
    int stripeCount = 10;
    for (int i = 0; i < stripeCount; i++) {
      grassPaint.color = i % 2 == 0
          ? const Color(0xFF143311)
          : const Color(0xFF183D15);
      canvas.drawRect(
        Rect.fromLTWH(0, i * (h / stripeCount), w, h / stripeCount),
        grassPaint,
      );
    }

    // 2. LIGNES DE TOUCHE
    canvas.drawRect(Rect.fromLTWH(5, 5, w - 10, h - 10), paint);

    // 3. LIGNE MÉDIANE ET CERCLE CENTRAL
    canvas.drawLine(Offset(5, h / 2), Offset(w - 5, h / 2), paint);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.15, paint);
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      2,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;

    // 4. SURFACES DE RÉPARATION
    _drawGoalArea(canvas, size, paint, true); // Haut
    _drawGoalArea(canvas, size, paint, false); // Bas
  }

  void _drawGoalArea(Canvas canvas, Size size, Paint paint, bool isTop) {
    double w = size.width;
    double h = size.height;
    double yEdge = isTop ? 5 : h - 5;
    double dir = isTop ? 1 : -1;

    // Grande Surface
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, yEdge, w * 0.64, h * 0.14 * dir),
      paint,
    );
    // Surface de but
    canvas.drawRect(
      Rect.fromLTWH(w * 0.35, yEdge, w * 0.3, h * 0.05 * dir),
      paint,
    );
    // Point de penalty
    canvas.drawCircle(
      Offset(w / 2, isTop ? h * 0.10 : h * 0.90),
      1.5,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
