import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MediaMessage extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const MediaMessage({super.key, required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final String? mediaUrl = data['media_url'];
    final bool isVideo = (data['type'] ?? '') == 'VIDEO';
    final String duration = data['duration'] ?? '';
    final DateTime createdAt = data['created_at'] != null
        ? DateTime.parse(data['created_at']).toLocal()
        : DateTime.now();
    final String time = DateFormat('HH:mm').format(createdAt);
    final bool isRead = data['is_read'] ?? false;
    final String? reaction = data['my_reaction'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: reaction != null ? 22 : 10,
          left: isMe ? 50 : 14,
          right: isMe ? 14 : 50,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Conteneur média
                GestureDetector(
                  onTap: () => _showFullScreen(context, mediaUrl, isVideo),
                  child: Container(
                    width: 230,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFF3CFF7E).withOpacity(0.3)
                            : Colors.white.withOpacity(0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image / thumbnail
                        _buildMediaPreview(mediaUrl),

                        // Gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bouton central play / zoom
                        Center(
                          child: _buildCenterAction(context, mediaUrl, isVideo),
                        ),

                        // Badge vidéo + durée
                        if (isVideo && duration.isNotEmpty)
                          _buildVideoBadge(duration),

                        // Badge type
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _buildTypeBadge(isVideo),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 9,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 12,
                          color: isRead
                              ? const Color(0xFF3CFF7E)
                              : Colors.white24,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Réaction
            if (reaction != null)
              Positioned(
                bottom: -12,
                right: isMe ? 8 : null,
                left: isMe ? null : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(reaction, style: const TextStyle(fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            color: Colors.white24,
            size: 40,
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF1A1A1A),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                        : null,
                    color: const Color(0xFF3CFF7E),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Chargement...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.white24,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAction(BuildContext context, String? url, bool isVideo) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe
                ? const Color(0xFF3CFF7E).withOpacity(0.2)
                : Colors.white.withOpacity(0.12),
            border: Border.all(
              color: isMe
                  ? const Color(0xFF3CFF7E).withOpacity(0.5)
                  : Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Icon(
            isVideo ? Icons.play_arrow_rounded : Icons.fullscreen_rounded,
            color: isMe ? const Color(0xFF3CFF7E) : Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBadge(String duration) {
    return Positioned(
      bottom: 10,
      right: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(bool isVideo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                color: isMe ? const Color(0xFF3CFF7E) : Colors.white70,
                size: 11,
              ),
              const SizedBox(width: 4),
              Text(
                isVideo ? "VIDÉO" : "PHOTO",
                style: TextStyle(
                  color: isMe ? const Color(0xFF3CFF7E) : Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String? url, bool isVideo) {
    if (url == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => _FullScreenMedia(url: url, isVideo: isVideo),
      ),
    );
  }
}

// ── FULLSCREEN VIEWER ────────────────────────────────────────

class _FullScreenMedia extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _FullScreenMedia({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media
          Center(
            child: isVideo
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Lecteur vidéo",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  )
                : InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 60,
                      ),
                    ),
                  ),
          ),

          // Bouton fermer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
