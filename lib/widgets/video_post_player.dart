import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPostPlayer extends StatefulWidget {
  final String videoUrl;
  const VideoPostPlayer({super.key, required this.videoUrl});

  @override
  State<VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<VideoPostPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isMuted = false; // SON ACTIVÉ PAR DÉFAUT
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller.setLooping(true);
          _controller.setVolume(1.0); // VOLUME À 100% PAR DÉFAUT
          _controller.play();
        });
        _startHideTimer();
      }
    } catch (e) {
      debugPrint("🦁 Erreur Vidéo: $e");
    }

    // Listener pour mettre à jour l'affichage de la barre de progression
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.greenAccent,
          strokeWidth: 2,
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. LE LECTEUR VIDÉO (Prend tout l'espace)
        GestureDetector(
          onTap: _toggleControls,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        ),

        // 2. INTERFACE DE CONTRÔLE
        IgnorePointer(
          ignoring: !_showControls,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black38, // Voile sombre pour la lisibilité
              child: Stack(
                children: [
                  // BOUTONS CENTRAUX (Play/Pause/Seek)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: Icons.replay_10_rounded,
                          onPressed: () => _controller.seekTo(
                            _controller.value.position -
                                const Duration(seconds: 10),
                          ),
                        ),
                        _buildControlButton(
                          icon: _controller.value.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 80,
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                        ),
                        _buildControlButton(
                          icon: Icons.forward_10_rounded,
                          onPressed: () => _controller.seekTo(
                            _controller.value.position +
                                const Duration(seconds: 10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BARRE DE TEMPS (BAS GAUCHE)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),

                  // BOUTON MUTE/UNMUTE (BAS DROITE)
                  Positioned(
                    bottom: 15,
                    right: 15,
                    child: _buildControlButton(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 35,
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _controller.setVolume(_isMuted ? 0.0 : 1.0);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper pour créer des boutons consistants
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 45,
  }) {
    return IconButton(
      iconSize: size,
      icon: Icon(icon, color: Colors.white),
      onPressed: () {
        onPressed();
        _startHideTimer(); // Relance le chrono de disparition
      },
    );
  }
}
