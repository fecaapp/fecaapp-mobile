import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MediaMessage extends StatelessWidget {
  final Map<String, dynamic> data; // Objet complet venant de la DB
  final bool isMe;

  const MediaMessage({super.key, required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Extraction des données Prisma
    final String? mediaUrl = data['mediaUrl'];
    final bool isVideo = data['type'] == 'VIDEO';
    final String duration = data['duration'] ?? "0:00";
    final String timestamp = data['createdAt'] != null
        ? TimeOfDay.fromDateTime(
            DateTime.parse(data['createdAt']),
          ).format(context)
        : "00:00";
    final String status = data['status'] ?? 'SENT';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15, left: 15, right: 15),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Conteneur Média
            Container(
              height: 200,
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMe ? 24 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 24),
                ),
                border: Border.all(
                  color: isMe
                      ? Colors.greenAccent.withOpacity(0.3)
                      : Colors.white10,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image ou Thumbnail Video
                  _buildMediaPreview(mediaUrl),

                  // Overlay dégradé pour la lisibilité
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bouton Play / Fullscreen Central
                  Center(child: _buildCenterAction(isVideo)),

                  // Badge Durée Vidéo
                  if (isVideo) _buildVideoBadge(duration),
                ],
              ),
            ),

            // Footer : Heure + Triple Check
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8, left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 9,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    _buildStatusIcon(status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String? url) {
    return Image.network(
      url ??
          "https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=500",
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.white.withOpacity(0.05),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.greenAccent,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.white.withOpacity(0.05),
        child: const Icon(Icons.broken_image, color: Colors.white24, size: 40),
      ),
    );
  }

  Widget _buildCenterAction(bool isVideo) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(
            isVideo ? Icons.play_arrow_rounded : Icons.fullscreen_rounded,
            color: isMe ? Colors.greenAccent : Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBadge(String duration) {
    return Positioned(
      top: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.black45,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'DELIVERED':
        icon = Icons.done_all_rounded;
        color = Colors.white38;
        break;
      case 'READ':
        icon = Icons.done_all_rounded;
        color = Colors.greenAccent;
        break;
      default:
        icon = Icons.done_rounded;
        color = Colors.white24;
    }
    return Icon(icon, size: 12, color: color);
  }
}
