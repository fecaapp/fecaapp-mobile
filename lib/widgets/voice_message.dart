import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceMessage extends StatefulWidget {
  final String duration;
  final bool isMe;
  final String timestamp;
  final bool isRead;

  const VoiceMessage({
    super.key,
    required this.duration,
    required this.isMe,
    required this.timestamp,
    this.isRead = false,
  });

  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<VoiceMessage>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _progress = 0.0;
  late AnimationController _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) _simulateProgress();
    });
  }

  void _simulateProgress() async {
    // Simulation lecture — à remplacer par un vrai player
    while (_isPlaying && _progress < 1.0 && mounted) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted && _isPlaying) {
        setState(() => _progress += 0.01);
        if (_progress >= 1.0) {
          setState(() {
            _isPlaying = false;
            _progress = 0.0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isMe ? const Color(0xFF3CFF7E) : Colors.white70;
    final Color bg = widget.isMe
        ? const Color(0xFF3CFF7E).withOpacity(0.18)
        : Colors.white.withOpacity(0.07);

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left: widget.isMe ? 60 : 14,
          right: widget.isMe ? 14 : 60,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 20),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isMe
                      ? [
                          const Color(0xFF3CFF7E).withOpacity(0.22),
                          const Color(0xFF3CFF7E).withOpacity(0.07),
                        ]
                      : [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.03),
                        ],
                ),
                border: Border.all(
                  color: widget.isMe
                      ? const Color(0xFF3CFF7E).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Bouton play/pause
                      GestureDetector(
                        onTap: _togglePlay,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _isPlaying
                                ? accent
                                : accent.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.4)),
                            boxShadow: _isPlaying
                                ? [
                                    BoxShadow(
                                      color: accent.withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: _isPlaying ? Colors.black : accent,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Waveform animée
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _waveAnim,
                              builder: (_, __) => SizedBox(
                                height: 32,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(24, (i) {
                                    final played = i / 24 < _progress;
                                    double h;
                                    if (_isPlaying) {
                                      h =
                                          4 +
                                          (sin(
                                                        i * 0.6 +
                                                            _waveAnim.value *
                                                                pi *
                                                                2,
                                                      ) *
                                                      0.5 +
                                                  0.5) *
                                              22;
                                    } else {
                                      final heights = [
                                        4.0,
                                        10.0,
                                        18.0,
                                        6.0,
                                        22.0,
                                        8.0,
                                        14.0,
                                        5.0,
                                        20.0,
                                        7.0,
                                        12.0,
                                        16.0,
                                        4.0,
                                        9.0,
                                        24.0,
                                        6.0,
                                        11.0,
                                        19.0,
                                        5.0,
                                        13.0,
                                        7.0,
                                        17.0,
                                        4.0,
                                        10.0,
                                      ];
                                      h = heights[i % heights.length];
                                    }
                                    return Container(
                                      width: 2.5,
                                      height: h,
                                      decoration: BoxDecoration(
                                        color: played
                                            ? accent
                                            : accent.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Barre de progression
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress,
                                backgroundColor: accent.withOpacity(0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                                minHeight: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Durée
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.duration,
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "VOCAL",
                              style: TextStyle(
                                color: accent.withOpacity(0.6),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Footer
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.timestamp,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 9,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          widget.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: widget.isRead
                              ? const Color(0xFF3CFF7E)
                              : Colors.white24,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
