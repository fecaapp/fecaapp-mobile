import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class VoiceMessage extends StatelessWidget {
  // On change les entrées ici pour correspondre à ton ChatScreen
  final String duration;
  final bool isMe;
  final String timestamp;

  const VoiceMessage({
    super.key,
    required this.duration,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    // Plus besoin d'extraire de 'data', on utilise directement les variables
    final String formattedTime = timestamp;
    final String displayDuration = duration;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 15, right: 15),
        constraints: const BoxConstraints(maxWidth: 270),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isMe ? 22 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 22),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMe
                          ? [
                              Colors.greenAccent.withOpacity(0.18),
                              Colors.greenAccent.withOpacity(0.06),
                            ]
                          : [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.03),
                            ],
                    ),
                    border: Border.all(
                      color: isMe
                          ? Colors.greenAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPlayButton(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: SizedBox(height: 30, child: _buildWaveform()),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        displayDuration,
                        style: TextStyle(
                          color: isMe ? Colors.greenAccent : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 12,
                      color: Colors.white24,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isMe ? Colors.greenAccent : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: 28,
        color: isMe ? Colors.black : Colors.greenAccent,
      ),
    );
  }

  Widget _buildWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(16, (index) {
        double h = (index % 5 == 0) ? 12.0 : (index % 3 == 0 ? 24.0 : 8.0);
        return Container(
          width: 3,
          height: h,
          decoration: BoxDecoration(
            color: isMe ? Colors.greenAccent : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
