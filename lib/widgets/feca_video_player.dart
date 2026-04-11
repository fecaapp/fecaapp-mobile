import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class FecaVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const FecaVideoPlayer({
    super.key,
    required this.videoUrl,
    this.title = "SAGA DES ROIS - EXCLUSIF",
  });

  @override
  State<FecaVideoPlayer> createState() => _FecaVideoPlayerState();
}

class _FecaVideoPlayerState extends State<FecaVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isInitialized = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
      });
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _isInitialized
              ? VideoPlayer(_controller)
              : const CircularProgressIndicator(),

          // Zone de détection pour afficher/cacher les contrôles
          GestureDetector(
            onTap: () {
              setState(() => _showControls = !_showControls);
              if (_showControls) _startHideTimer();
            },
            child: Container(color: Colors.transparent),
          ),

          if (_showControls) _buildControlsOverlay(),
        ],
      ),
    );
  }

  // CETTE MÉTHODE MANQUAIT DANS TON CODE (D'où l'erreur rouge)
  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            iconSize: 50,
            icon: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_circle
                  : Icons.play_circle,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
              _startHideTimer();
            },
          ),
          VideoProgressIndicator(_controller, allowScrubbing: true),
        ],
      ),
    );
  }
}
