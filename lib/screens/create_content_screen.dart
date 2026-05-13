import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';
import '../services/social_service.dart';

class CreateContentScreen extends StatefulWidget {
  final String type; // 'POST' ou 'STATUS'
  final User user;

  const CreateContentScreen({
    super.key,
    required this.type,
    required this.user,
  });

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final SocialService _socialService = SocialService();
  final SupabaseClient = supabase.Supabase.instance.client;

  List<File> _mediaFiles = [];
  bool _isVideo = false;
  bool _isTextOnly = false;
  bool _isLoading = false;
  int _selectedTheme = 0;

  late AnimationController _publishAnim;
  late Animation<double> _publishScale;

  // Thèmes de fond pour les posts texte
  final List<Map<String, dynamic>> _themes = [
    {
      'gradient': [const Color(0xFF0A0A0A), const Color(0xFF111111)],
      'name': 'Sombre',
    },
    {
      'gradient': [const Color(0xFF0D1F0D), const Color(0xFF0A1A0A)],
      'name': 'Forêt',
    },
    {
      'gradient': [const Color(0xFF0D0D1F), const Color(0xFF0A0A1A)],
      'name': 'Nuit',
    },
    {
      'gradient': [const Color(0xFF1A0D0D), const Color(0xFF150A0A)],
      'name': 'Braise',
    },
    {
      'gradient': [const Color(0xFF1A1500), const Color(0xFF121000)],
      'name': 'Or',
    },
    {
      'gradient': [const Color(0xFF0D1A1A), const Color(0xFF0A1515)],
      'name': 'Mer',
    },
    {
      'gradient': [const Color(0xFF1A0D1A), const Color(0xFF150A15)],
      'name': 'Violet',
    },
  ];

  @override
  void initState() {
    super.initState();
    _publishAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _publishScale = Tween(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _publishAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _textController.dispose();
    _publishAnim.dispose();
    super.dispose();
  }

  // ── MEDIA ─────────────────────────────────────────────────

  Future<void> _pickMedia({bool video = false}) async {
    final picker = ImagePicker();
    try {
      if (video) {
        final file = await picker.pickVideo(source: ImageSource.gallery);
        if (file != null)
          setState(() {
            _mediaFiles = [File(file.path)];
            _isVideo = true;
            _isTextOnly = false;
          });
      } else {
        final files = await picker.pickMultiImage(imageQuality: 85);
        if (files.isNotEmpty)
          setState(() {
            _mediaFiles = files.map((f) => File(f.path)).toList();
            _isVideo = false;
            _isTextOnly = false;
          });
      }
    } catch (e) {
      debugPrint("Erreur pick: $e");
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      if (_mediaFiles.isEmpty) _isVideo = false;
    });
  }

  // ── PUBLICATION ───────────────────────────────────────────

  Future<void> _publish() async {
    final content = _textController.text.trim();
    final hasMedia = _mediaFiles.isNotEmpty;

    // Validation : texte pur OU media requis
    if (content.isEmpty && !hasMedia) {
      _showSnack("Écris quelque chose ou ajoute une photo 🦁", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      bool success = false;

      if (widget.type == 'STATUS') {
        // Publication statut
        success = await _socialService.createStatus(
          userId: widget.user.id,
          content: content,
          imageFile: hasMedia ? _mediaFiles.first : null,
        );
      } else if (_isTextOnly || (!hasMedia)) {
        // Post TEXTE PUR — pas de fichier
        success = await _socialService.createPost(
          userId: widget.user.id,
          content: content,
          type: 'TEXT',
          // Pas de file ni files → texte pur
        );
      } else if (_isVideo) {
        // Post VIDÉO
        success = await _socialService.createPost(
          userId: widget.user.id,
          content: content,
          type: 'VIDEO',
          file: _mediaFiles.first,
        );
      } else if (_mediaFiles.length == 1) {
        // Post IMAGE unique
        success = await _socialService.createPost(
          userId: widget.user.id,
          content: content,
          type: 'IMAGE',
          file: _mediaFiles.first,
        );
      } else {
        // Post MULTI-PHOTOS
        success = await _socialService.createPost(
          userId: widget.user.id,
          content: content,
          type: 'IMAGE',
          files: _mediaFiles,
        );
      }

      if (success && mounted) {
        HapticFeedback.mediumImpact();
        _showSnack("Rugissement publié ! 🦁🔥");
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack("Erreur lors de la publication", isError: true);
      }
    } catch (e) {
      debugPrint("Erreur publication: $e");
      _showSnack("Erreur: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            color: isError ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF3CFF7E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (!_isTextOnly && _mediaFiles.isEmpty)
                        _buildTypeSwitcher(),
                      _buildContentArea(),
                      if (_isTextOnly && _mediaFiles.isEmpty)
                        _buildThemeSelector(),
                      if (_mediaFiles.isNotEmpty) _buildMediaPreview(),
                      if (!_isVideo && !_isTextOnly) _buildAddMorePhotos(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Barre du bas
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF3CFF7E),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "PUBLICATION...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2,
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

  // ── APP BAR ───────────────────────────────────────────────

  Widget _buildAppBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.type == 'STATUS'
                    ? "STATUT FLASH"
                    : "NOUVEAU RUGISSEMENT",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            // Bouton publier dans l'appbar aussi
            GestureDetector(
              onTap: _isLoading ? null : _publish,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3CFF7E), Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3CFF7E).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  "PUBLIER",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TYPE SWITCHER ─────────────────────────────────────────

  Widget _buildTypeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _typeChip(
            Icons.text_fields_rounded,
            "Texte",
            !_isVideo && _mediaFiles.isEmpty,
            () => setState(() {
              _isTextOnly = true;
              _isVideo = false;
              _mediaFiles = [];
            }),
          ),
          const SizedBox(width: 10),
          _typeChip(
            Icons.image_rounded,
            "Photo",
            !_isVideo && _mediaFiles.isNotEmpty,
            () => _pickMedia(),
          ),
          const SizedBox(width: 10),
          _typeChip(
            Icons.videocam_rounded,
            "Vidéo",
            _isVideo,
            () => _pickMedia(video: true),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF3CFF7E).withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? const Color(0xFF3CFF7E).withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFF3CFF7E) : Colors.white38,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF3CFF7E) : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ZONE DE TEXTE ─────────────────────────────────────────

  Widget _buildContentArea() {
    final colors = _themes[_selectedTheme]['gradient'] as List<Color>;

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header profil
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.green,
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: (widget.user.img_url?.isNotEmpty ?? false)
                        ? NetworkImage(widget.user.img_url!)
                        : null,
                    child: (widget.user.img_url?.isEmpty ?? true)
                        ? Text(
                            widget.user.fullName.isNotEmpty
                                ? widget.user.fullName[0].toUpperCase()
                                : 'L',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      widget.type == 'STATUS' ? "Statut · 24h" : "Publication",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Champ texte
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _textController,
              maxLines: null,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: widget.type == 'STATUS'
                    ? "Partage un moment de ta vie..."
                    : "Que rugis-tu aujourd'hui, Lion ? 🦁",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── THÈMES ────────────────────────────────────────────────

  Widget _buildThemeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF3CFF7E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "THÈME DE FOND",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _themes.length,
              itemBuilder: (_, i) {
                final colors = _themes[i]['gradient'] as List<Color>;
                final isSelected = i == _selectedTheme;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTheme = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3CFF7E)
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: Color(0xFF3CFF7E),
                              size: 20,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── APERÇU MÉDIAS ─────────────────────────────────────────

  Widget _buildMediaPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF3CFF7E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isVideo ? "VIDÉO" : "${_mediaFiles.length} PHOTO(S)",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaFiles.length,
              itemBuilder: (_, i) => Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_mediaFiles[i], fit: BoxFit.cover),
                    if (_isVideo)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _removeMedia(i),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMorePhotos() {
    if (_mediaFiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: _pickMedia,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF3CFF7E).withOpacity(0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_photo_alternate_rounded,
                color: Color(0xFF3CFF7E),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                "Ajouter des photos",
                style: TextStyle(
                  color: Color(0xFF3CFF7E),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BARRE DU BAS ─────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 16,
        right: 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Boutons media
          _bottomIconBtn(
            Icons.image_rounded,
            const Color(0xFF3CFF7E),
            () => _pickMedia(),
          ),
          const SizedBox(width: 8),
          _bottomIconBtn(
            Icons.videocam_rounded,
            Colors.blueAccent,
            () => _pickMedia(video: true),
          ),
          const SizedBox(width: 8),
          _bottomIconBtn(
            Icons.text_fields_rounded,
            Colors.purpleAccent,
            () => setState(() {
              _isTextOnly = true;
              _mediaFiles = [];
            }),
          ),
          const Spacer(),

          // Bouton publier principal
          ScaleTransition(
            scale: _publishScale,
            child: GestureDetector(
              onTapDown: (_) => _publishAnim.forward(),
              onTapUp: (_) {
                _publishAnim.reverse();
                _publish();
              },
              onTapCancel: () => _publishAnim.reverse(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3CFF7E), Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3CFF7E).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "PUBLIER",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
