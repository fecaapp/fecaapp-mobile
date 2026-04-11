import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';
import '../models/user.dart' as model;
import '../services/social_service.dart';

// ==========================================
// FICHIER : CREATE_CONTENT_SCREEN.DART 🦁
// ==========================================

class CreateContentScreen extends StatefulWidget {
  final String type; // 'POST' ou 'STATUS'
  final model.User user;

  const CreateContentScreen({
    super.key,
    required this.type,
    required this.user,
  });

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final SocialService _socialService = SocialService();

  File? _mediaFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isVideo = false;
  bool _isTextOnly = false;

  // Gradients stylés pour les statuts texte
  final List<List<Color>> _statusGradients = [
    [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)],
    [const Color(0xFF11998e), const Color(0xFF38ef7d)],
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    [const Color(0xFFf12711), const Color(0xFFf5af19)],
    [const Color(0xFF000000), const Color(0xFF434343)],
  ];
  int _selectedBgIndex = 0;

  @override
  void initState() {
    super.initState();
    // Si c'est un STATUS, on demande si l'utilisateur veut du texte ou du média
    if (widget.type == 'POST') {
      Future.delayed(Duration.zero, () => _autoPickMedia());
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // --- SÉLECTION MÉDIA (IMAGES & VIDÉOS) ---
  Future<void> _autoPickMedia() async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickMedia(imageQuality: 80);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final bool isVideoFile =
            pickedFile.path.toLowerCase().endsWith('.mp4') ||
            pickedFile.path.toLowerCase().endsWith('.mov') ||
            pickedFile.path.toLowerCase().endsWith('.avi');

        setState(() {
          _mediaFile = file;
          _isVideo = isVideoFile;
          _isTextOnly = false;
        });

        if (isVideoFile) {
          _videoController = VideoPlayerController.file(file);
          await _videoController!.initialize();
          setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      } else {
        // Si l'utilisateur annule et que c'est un POST, on ferme
        if (widget.type == 'POST' && mounted) Navigator.pop(context);
        // Si c'est un STATUS, on passe en mode texte par défaut
        if (widget.type == 'STATUS') setState(() => _isTextOnly = true);
      }
    } catch (e) {
      debugPrint("Erreur Picker: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  // --- LOGIQUE DE PUBLICATION ---
  Future<void> _handlePublish() async {
    FocusScope.of(context).unfocus();

    // Validation stricte
    final String finalContent = _isTextOnly
        ? _textController.text.trim()
        : _captionController.text.trim();

    if (_isTextOnly && finalContent.isEmpty) return;
    if (!_isTextOnly && _mediaFile == null) return;

    setState(() => _isUploading = true);
    HapticFeedback.heavyImpact();

    try {
      bool success = false;

      if (widget.type == 'POST') {
        success = await _socialService.createPost(
          userId: widget.user.id,
          content: finalContent,
          type: _isVideo ? 'VIDEO' : 'IMAGE',
          file: _mediaFile,
        );
      } else {
        // Publication d'un Statut (Story)
        success = await _socialService.createStatus(
          userId: widget.user.id,
          content: finalContent,
          imageFile: _mediaFile, // Sera null si _isTextOnly
        );
      }

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Le Lion a rugi avec succès ! 🦁"),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec du rugissement : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: _isTextOnly,
      body: Stack(
        children: [
          _buildMainContent(),
          _buildTopBar(),
          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isTextOnly) return _buildTextEditor();

    // Si on attend le média pour un POST
    if (_mediaFile == null && widget.type == 'POST') {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    // Si c'est un statut et qu'on n'a pas encore choisi
    if (_mediaFile == null && widget.type == 'STATUS' && !_isTextOnly) {
      return _buildStatusPickerMode();
    }

    return _buildStudioEditor();
  }

  // --- CHOIX INITIAL POUR STATUS ---
  Widget _buildStatusPickerMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modeButton(
            icon: Icons.text_fields_rounded,
            label: "TEXTE",
            onTap: () => setState(() => _isTextOnly = true),
          ),
          const SizedBox(height: 30),
          _modeButton(
            icon: Icons.photo_camera_rounded,
            label: "MÉDIA",
            onTap: _autoPickMedia,
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.greenAccent, size: 40),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ÉDITEUR STUDIO (PREVIEW PHOTO/VIDEO) ---
  Widget _buildStudioEditor() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 110),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isVideo
                ? (_videoController != null &&
                          _videoController!.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                          ),
                        ))
                : Image.file(_mediaFile!, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Écrivez votre légende...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                filled: true,
                fillColor: const Color(0xFF121212),
                contentPadding: const EdgeInsets.all(20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 100),
        ],
      ),
    );
  }

  // --- ÉDITEUR TEXTE ---
  Widget _buildTextEditor() {
    return GestureDetector(
      onTap: () {
        setState(
          () => _selectedBgIndex =
              (_selectedBgIndex + 1) % _statusGradients.length,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _statusGradients[_selectedBgIndex],
          ),
        ),
        child: Center(
          child: TextField(
            controller: _textController,
            textAlign: TextAlign.center,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: "Tapez votre pensée...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  // --- BARRE SUPÉRIEURE ---
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 15,
              left: 10,
              right: 15,
            ),
            color: Colors.black.withOpacity(0.4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.type == 'POST' ? "CRÉER UN POST" : "STATUT FLASH",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isUploading ? null : _handlePublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    "PUBLIER",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.greenAccent,
              strokeWidth: 5,
            ),
            SizedBox(height: 25),
            Text(
              "TRAITEMENT DU RUGISSEMENT...",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
