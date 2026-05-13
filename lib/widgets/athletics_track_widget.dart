import 'package:flutter/material.dart';

class AthleticsTrackWidget extends StatelessWidget {
  final List<dynamic> results; // Liste des athlètes

  const AthleticsTrackWidget({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    // On ne garde que les 8 premiers couloirs pour la démo visuelle
    final displayResults = results.take(8).toList();

    return Container(
      margin: const EdgeInsets.all(20),
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          // Piste (Couloirs)
          CustomPaint(painter: _TrackPainter(), size: Size.infinite),

          // Athlètes dans les couloirs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayResults.length,
              itemBuilder: (context, i) {
                final r = displayResults[i];
                return _laneRow(r, i + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _laneRow(Map<String, dynamic> r, int lane) {
    return Container(
      height: 25,
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          // Numéro de couloir
          SizedBox(
            width: 20,
            child: Text(
              '$lane',
              style: const TextStyle(color: Colors.white24, fontSize: 8),
            ),
          ),
          // Nom
          Expanded(
            child: Text(
              r['name'].toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Indicateur
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lane == 1 ? const Color(0xFFFF6B00) : Colors.white10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dessiner 8 lignes de couloir
    for (int i = 0; i < 9; i++) {
      double y = 20 + (i * 25);
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
