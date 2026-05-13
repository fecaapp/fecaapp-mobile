import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SOCCER FIELD WIDGET — FECAAPP ELITE
//  • Terrain FIFA complet avec demi-cercles
//  • Positions lues depuis les clés dashboard (t1_p0, t2_p0…)
//  • Badges BUT ⚽ / CARTON JAUNE 🟨 / CARTON ROUGE 🟥 par joueur
//  • Rendu léger (pas d'AnimatedPositioned inutile au scroll)
// ═══════════════════════════════════════════════════════════════════════════

class SoccerFieldWidget extends StatelessWidget {
  /// Lignes de composition — format "N. NOM" ou juste "NOM"
  final List<dynamic> lineup1;
  final List<dynamic> lineup2;

  /// Positions JSON du dashboard  { "t1_p0": {"x":15,"y":12}, … }
  final Map<String, dynamic>? positions;

  /// Événements du match [ {"type":"goal","team":"1","player":"1. ONANA"}, … ]
  final List<dynamic>? events;

  /// Nom du stade (filigrane)
  final String? stadium;

  /// Noms des équipes (labels terrain)
  final String? teamAName;
  final String? teamBName;

  const SoccerFieldWidget({
    super.key,
    required this.lineup1,
    required this.lineup2,
    this.positions,
    this.events,
    this.stadium,
    this.teamAName,
    this.teamBName,
  });

  // ── helpers événements ──────────────────────────────────────────────────
  bool _hasEvent(String playerFull, String type) {
    if (events == null) return false;
    return events!.any((e) {
      final t = (e['type'] ?? '').toString().toLowerCase();
      final p = (e['player'] ?? '').toString().toUpperCase();
      return t == type && p == playerFull.toUpperCase();
    });
  }

  // ── parsing "N. NOM" ────────────────────────────────────────────────────
  _PlayerInfo _parsePlayer(dynamic raw) {
    final full = (raw is Map ? (raw['label'] ?? '') : raw.toString()).trim();
    if (full.contains('.')) {
      final parts = full.split('.');
      return _PlayerInfo(
        number: parts[0].trim(),
        name: parts.sublist(1).join('.').trim(),
        full: full,
      );
    }
    return _PlayerInfo(number: '?', name: full, full: full);
  }

  // ── lecture position dashboard ──────────────────────────────────────────
  // Dashboard JS sauvegarde les clés sous la forme "t1_p0", "t2_p0"…
  _Pos _getPos(int teamIdx, int playerIdx, bool isTeam1) {
    if (positions != null) {
      final key = 't${teamIdx + 1}_p$playerIdx';
      final entry = positions![key];
      if (entry != null) {
        try {
          return _Pos(
            double.parse(entry['x'].toString()),
            double.parse(entry['y'].toString()),
          );
        } catch (_) {}
      }
    }
    // Positions par défaut : répartition horizontale équilibrée
    final double x = 8.0 + (playerIdx * 8.0);
    final double y = isTeam1 ? 14.0 : 80.0;
    return _Pos(x.clamp(5, 92), y);
  }

  @override
  Widget build(BuildContext context) {
    final stadiumName = (stadium ?? 'STADE OFFICIEL').toUpperCase();

    return AspectRatio(
      aspectRatio: 0.65,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF00FF85).withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 0),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // ── 1. TERRAIN ──────────────────────────────────────────────
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _StadiumPainter()),
                ),
              ),

              // ── 2. FILIGRANE STADE ──────────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.04,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stadium,
                            color: Colors.white,
                            size: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stadiumName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 3. LABEL ÉQUIPE A (haut) ────────────────────────────────
              if (teamAName != null)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _TeamLabel(
                      name: teamAName!,
                      color: const Color(0xFF00FF85),
                    ),
                  ),
                ),

              // ── 4. LABEL ÉQUIPE B (bas) ─────────────────────────────────
              if (teamBName != null)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _TeamLabel(
                      name: teamBName!,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),

              // ── 5. JOUEURS ──────────────────────────────────────────────
              LayoutBuilder(
                builder: (ctx, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Équipe 1
                      for (int i = 0; i < lineup1.length && i < 11; i++)
                        _buildPlayerNode(
                          player: lineup1[i],
                          index: i,
                          teamIdx: 0,
                          isTeam1: true,
                          constraints: constraints,
                        ),
                      // Équipe 2
                      for (int i = 0; i < lineup2.length && i < 11; i++)
                        _buildPlayerNode(
                          player: lineup2[i],
                          index: i,
                          teamIdx: 1,
                          isTeam1: false,
                          constraints: constraints,
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

  Widget _buildPlayerNode({
    required dynamic player,
    required int index,
    required int teamIdx,
    required bool isTeam1,
    required BoxConstraints constraints,
  }) {
    final info = _parsePlayer(player);
    final pos = _getPos(teamIdx, index, isTeam1);

    final double left = (pos.x / 100) * constraints.maxWidth;
    final double top = (pos.y / 100) * constraints.maxHeight;

    // Badges événements
    final bool hasGoal = _hasEvent(info.full, 'goal');
    final bool hasYellow = _hasEvent(info.full, 'yellow');
    final bool hasRed = _hasEvent(info.full, 'red');
    final bool hasSub = _hasEvent(info.full, 'sub');

    final Color teamColor = isTeam1
        ? const Color(0xFF00FF85)
        : Colors.blueAccent;
    final Color textColor = isTeam1 ? Colors.black : Colors.white;

    return Positioned(
      // Centrage horizontal sur la position
      left: left - 28,
      top: top - 28,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── DOSSARD ──────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: teamColor,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      info.number,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),

                // ── BADGES ──────────────────────────────────
                if (hasGoal || hasYellow || hasRed || hasSub)
                  Positioned(
                    top: -6,
                    right: -4,
                    child: _BadgeRow(
                      hasGoal: hasGoal,
                      hasYellow: hasYellow,
                      hasRed: hasRed,
                      hasSub: hasSub,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 3),

            // ── NOM ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: teamColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                info.name.length > 8
                    ? '${info.name.substring(0, 8).toUpperCase()}.'
                    : info.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: teamColor,
                  fontSize: 6.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BADGES ÉVÉNEMENTS
// ═══════════════════════════════════════════════════════════════════════════
class _BadgeRow extends StatelessWidget {
  final bool hasGoal, hasYellow, hasRed, hasSub;
  const _BadgeRow({
    required this.hasGoal,
    required this.hasYellow,
    required this.hasRed,
    required this.hasSub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasGoal) _Badge(emoji: '⚽', bg: Colors.transparent),
        if (hasYellow) _Badge(color: const Color(0xFFFFEB3B)),
        if (hasRed) _Badge(color: const Color(0xFFFF3B3B)),
        if (hasSub) _Badge(emoji: '🔄', bg: Colors.transparent),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String? emoji;
  final Color? color;
  final Color? bg;
  const _Badge({this.emoji, this.color, this.bg});

  @override
  Widget build(BuildContext context) {
    if (emoji != null) {
      return Text(emoji!, style: const TextStyle(fontSize: 9));
    }
    return Container(
      width: 7,
      height: 9,
      margin: const EdgeInsets.only(left: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
        border: Border.all(color: Colors.white, width: 0.5),
        boxShadow: [BoxShadow(color: color!.withOpacity(0.6), blurRadius: 4)],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LABEL ÉQUIPE
// ═══════════════════════════════════════════════════════════════════════════
class _TeamLabel extends StatelessWidget {
  final String name;
  final Color color;
  const _TeamLabel({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          color: color.withOpacity(0.6),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════
class _PlayerInfo {
  final String number, name, full;
  const _PlayerInfo({
    required this.number,
    required this.name,
    required this.full,
  });
}

class _Pos {
  final double x, y;
  const _Pos(this.x, this.y);
}

// ═══════════════════════════════════════════════════════════════════════════
//  STADIUM PAINTER — FIFA COMPLET
// ═══════════════════════════════════════════════════════════════════════════
class _StadiumPainter extends CustomPainter {
  const _StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── PELOUSE STRIÉE ──────────────────────────────────────────────────
    const stripes = 12;
    for (int i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * (h / stripes), w, h / stripes),
        Paint()
          ..color = i.isEven ? const Color(0xFF143311) : const Color(0xFF183D15)
          ..style = PaintingStyle.fill,
      );
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final dot = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final margin = w * 0.04; // marge intérieure

    // ── BORDURE INTÉRIEURE ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(margin, margin, w - margin * 2, h - margin * 2),
      line,
    );

    // ── LIGNE MÉDIANE ───────────────────────────────────────────────────
    canvas.drawLine(Offset(margin, h / 2), Offset(w - margin, h / 2), line);

    // ── CERCLE CENTRAL ──────────────────────────────────────────────────
    final centerRadius = w * 0.14;
    canvas.drawCircle(Offset(w / 2, h / 2), centerRadius, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, dot);

    // ── SURFACES + DEMI-CERCLES ─────────────────────────────────────────
    _drawPenaltyZone(canvas, size, line, dot, isTop: true);
    _drawPenaltyZone(canvas, size, line, dot, isTop: false);

    // ── COINS (arcs de corner) ──────────────────────────────────────────
    _drawCorners(canvas, size, line, margin);
  }

  void _drawPenaltyZone(
    Canvas canvas,
    Size size,
    Paint line,
    Paint dot, {
    required bool isTop,
  }) {
    final w = size.width;
    final h = size.height;
    final margin = w * 0.04;

    // ── Grande surface ──
    final bigBoxLeft = w * 0.18;
    final bigBoxWidth = w * 0.64;
    final bigBoxHeight = h * 0.16;
    final bigBoxTop = isTop ? margin : h - margin - bigBoxHeight;

    canvas.drawRect(
      Rect.fromLTWH(bigBoxLeft, bigBoxTop, bigBoxWidth, bigBoxHeight),
      line,
    );

    // ── Petite surface ──
    final smallBoxLeft = w * 0.34;
    final smallBoxWidth = w * 0.32;
    final smallBoxHeight = h * 0.06;
    final smallBoxTop = isTop ? margin : h - margin - smallBoxHeight;

    canvas.drawRect(
      Rect.fromLTWH(smallBoxLeft, smallBoxTop, smallBoxWidth, smallBoxHeight),
      line,
    );

    // ── Point de penalty ──
    final penY = isTop
        ? margin + bigBoxHeight + h * 0.02
        : h - margin - bigBoxHeight - h * 0.02;
    canvas.drawCircle(Offset(w / 2, penY), 2.5, dot);

    // ── DEMI-CERCLE de réparation (arc à l'extérieur de la grande surface) ──
    final arcRadius = w * 0.15;
    final arcCenterY = isTop
        ? margin +
              bigBoxHeight // bord bas de la grande surface (haut)
        : h - margin - bigBoxHeight; // bord haut de la grande surface (bas)

    // On dessine seulement la portion de l'arc qui est HORS de la grande surface
    // → startAngle / sweepAngle selon l'équipe
    final rect = Rect.fromCircle(
      center: Offset(w / 2, arcCenterY),
      radius: arcRadius,
    );

    // L'arc s'étend de ~200° à ~340° (haut) ou ~20° à ~160° (bas)
    // pour ne pas chevaucher la surface
    if (isTop) {
      // Arc vers le bas (extérieur de la grande surface du haut)
      canvas.drawArc(rect, 0.35, 2.44, false, line); // ~20° à ~160°
    } else {
      // Arc vers le haut (extérieur de la grande surface du bas)
      canvas.drawArc(rect, 3.49, 2.44, false, line); // ~200° à ~340°
    }
  }

  void _drawCorners(Canvas canvas, Size size, Paint line, double margin) {
    final w = size.width;
    final h = size.height;
    const r = 7.0;

    // Coin haut-gauche
    canvas.drawArc(
      Rect.fromCircle(center: Offset(margin, margin), radius: r),
      0,
      1.57,
      false,
      line,
    );
    // Coin haut-droit
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - margin, margin), radius: r),
      1.57,
      1.57,
      false,
      line,
    );
    // Coin bas-gauche
    canvas.drawArc(
      Rect.fromCircle(center: Offset(margin, h - margin), radius: r),
      4.71,
      1.57,
      false,
      line,
    );
    // Coin bas-droit
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - margin, h - margin), radius: r),
      3.14,
      1.57,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
