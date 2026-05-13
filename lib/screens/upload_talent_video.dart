import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

// ═══════════════════════════════════════════════════════════════
// CONSTANTES — POSTES PAR SPORT
// ═══════════════════════════════════════════════════════════════

const Map<String, List<String>> _kPostes = {
  'football': [
    'Gardien',
    'Défenseur Central',
    'Latéral Droit',
    'Latéral Gauche',
    'Milieu Défensif',
    'Milieu Relayeur',
    'Meneur de jeu',
    'Ailier Droit',
    'Ailier Gauche',
    'Avant-Centre',
  ],
  'basketball': ['Meneur', 'Arrière', 'Ailier', 'Ailier Fort', 'Pivot'],
  'handball': [
    'Gardien',
    'Pivot',
    'Ailier Droit',
    'Ailier Gauche',
    'Demi-Centre',
    'Arrière Droit',
    'Arrière Gauche',
  ],
  'volleyball': [
    'Passeur',
    'Libéro',
    'Central',
    'Pointu',
    'Réceptionneur-Attaquant',
  ],
  'athletics': [
    'Sprint',
    'Demi-fond',
    'Fond',
    'Haies',
    'Saut en hauteur',
    'Saut en longueur',
    'Triple saut',
    'Lancer',
  ],
  'tennis': ['Droitier Serve-Volley', 'Droitier Fond de court', 'Gaucher'],
  'boxing': [
    'Poids Mouche',
    'Poids Plume',
    'Poids Léger',
    'Poids Welter',
    'Poids Moyen',
    'Poids Lourd',
  ],
  'mma': [
    'Poids Paille',
    'Poids Mouche',
    'Poids Plume',
    'Poids Léger',
    'Poids Welter',
    'Poids Moyen',
    'Poids Lourd',
  ],
  'karate': ['Kata', 'Kumité'],
};

const Map<String, List<String>> _kNiveaux = {
  'default': [
    'Amateur',
    'Semi-Professionnel',
    'Professionnel',
    'International',
  ],
};

const Map<String, Color> _kSportColors = {
  'football': Color(0xFF3CFF7E),
  'basketball': Color(0xFFFFA500),
  'handball': Color(0xFFFF3131),
  'athletics': Color(0xFFFF6B00),
  'tennis': Color(0xFFC8FF00),
  'volleyball': Color(0xFF9B59FF),
  'boxing': Color(0xFFFFB800),
  'mma': Color(0xFF00CFFF),
  'karate': Color(0xFFFF0044),
};

const Map<String, IconData> _kSportIcons = {
  'football': Icons.sports_soccer_rounded,
  'basketball': Icons.sports_basketball_rounded,
  'handball': Icons.sports_handball_rounded,
  'athletics': Icons.directions_run_rounded,
  'tennis': Icons.sports_tennis_rounded,
  'volleyball': Icons.sports_volleyball_rounded,
  'boxing': Icons.sports_mma_rounded,
  'mma': Icons.sports_kabaddi_rounded,
  'karate': Icons.sports_martial_arts_rounded,
};

const Map<String, String> _kSportLabels = {
  'football': 'Football',
  'basketball': 'Basketball',
  'handball': 'Handball',
  'athletics': 'Athlétisme',
  'tennis': 'Tennis',
  'volleyball': 'Volleyball',
  'boxing': 'Boxe',
  'mma': 'MMA',
  'karate': 'Karaté',
};

String _sportLabel(String key) => _kSportLabels[key] ?? key;
Color _sportColor(String key) => _kSportColors[key] ?? const Color(0xFF3CFF7E);
IconData _sportIcon(String key) => _kSportIcons[key] ?? Icons.sports_rounded;

// ═══════════════════════════════════════════════════════════════
// UPLOAD TALENT SCREEN
// ═══════════════════════════════════════════════════════════════

class UploadTalentScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>
  profileData; // profil pré-rempli depuis users table

  const UploadTalentScreen({
    super.key,
    required this.userId,
    this.profileData = const {},
  });

  @override
  State<UploadTalentScreen> createState() => _UploadTalentScreenState();
}

class _UploadTalentScreenState extends State<UploadTalentScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  File? _videoFile;
  VideoPlayerController? _previewCtrl;

  // Contrôleurs texte
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _clubCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();

  // Valeurs sélectionnées
  String _sport = 'football';
  String _category = '';
  String _niveau = 'Amateur';
  String _foot = 'Droitier';
  bool _isUploading = false;
  int _currentStep = 0; // 0 = vidéo, 1 = infos, 2 = validation

  late AnimationController _stepAnimCtrl;
  late Animation<double> _stepAnim;

  @override
  void initState() {
    super.initState();
    _stepAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _stepAnim = CurvedAnimation(
      parent: _stepAnimCtrl,
      curve: Curves.easeOutCubic,
    );
    _stepAnimCtrl.forward();

    // Pré-remplissage depuis le profil
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final d = widget.profileData;

    // Sport depuis le profil de l'athlète
    final profileSport = d['sport']?.toString() ?? '';
    if (_kPostes.containsKey(profileSport)) {
      _sport = profileSport;
    }

    // Infos physiques
    _cityCtrl.text = d['city']?.toString() ?? '';
    _ageCtrl.text = d['birth_year'] != null
        ? '${DateTime.now().year - (int.tryParse(d['birth_year'].toString()) ?? DateTime.now().year)}'
        : '';
    _heightCtrl.text = d['height_cm']?.toString() ?? '';
    _clubCtrl.text = d['current_club']?.toString() ?? '';
    _bioCtrl.text = d['bio']?.toString() ?? '';
    _niveau = _mapLevel(d['level']?.toString() ?? '');

    // Poste par défaut
    _category = _kPostes[_sport]?.first ?? '';
  }

  String _mapLevel(String raw) {
    const map = {
      'amateur': 'Amateur',
      'semi_pro': 'Semi-Professionnel',
      'professionnel': 'Professionnel',
      'international': 'International',
    };
    return map[raw.toLowerCase()] ?? 'Amateur';
  }

  Color get _color => _sportColor(_sport);
  IconData get _icon => _sportIcon(_sport);

  @override
  void dispose() {
    _previewCtrl?.dispose();
    _cityCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _clubCtrl.dispose();
    _bioCtrl.dispose();
    _stepAnimCtrl.dispose();
    super.dispose();
  }

  // ── Sélection vidéo ─────────────────────────────────────────
  Future<void> _pickVideo() async {
    HapticFeedback.mediumImpact();
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    _videoFile = File(picked.path);
    _previewCtrl?.dispose();
    _previewCtrl = VideoPlayerController.file(_videoFile!)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _previewCtrl!.setLooping(true);
          _previewCtrl!.play();
        }
      });
    setState(() {});
  }

  // ── Navigation étapes ───────────────────────────────────────
  void _nextStep() {
    if (_currentStep == 0 && _videoFile == null) {
      _snack("Sélectionne d'abord ta vidéo", ok: false);
      return;
    }
    if (_currentStep == 1) {
      if (_ageCtrl.text.isEmpty ||
          _heightCtrl.text.isEmpty ||
          _cityCtrl.text.isEmpty) {
        _snack("Remplis tous les champs obligatoires *", ok: false);
        return;
      }
    }
    setState(() => _currentStep++);
    _stepAnimCtrl.reset();
    _stepAnimCtrl.forward();
  }

  void _prevStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentStep--);
    _stepAnimCtrl.reset();
    _stepAnimCtrl.forward();
  }

  // ── Upload ──────────────────────────────────────────────────
  Future<void> _upload() async {
    if (_videoFile == null) return;
    setState(() => _isUploading = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Upload vidéo
      final ext = _videoFile!.path.split('.').last;
      final fileName = "talent_${DateTime.now().millisecondsSinceEpoch}.$ext";
      final filePath = "${widget.userId}/$fileName";

      await supabase.storage
          .from('talents_videos')
          .upload(
            filePath,
            _videoFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final videoUrl = supabase.storage
          .from('talents_videos')
          .getPublicUrl(filePath);

      // 2. Upsert dans talents
      await supabase.from('talents').upsert({
        'user_id': widget.userId,
        'sport_type': _sport,
        'category': _category,
        'specialty': _category, // compatibilité ancien code
        'level': _niveau,
        'foot': _foot,
        'age': int.tryParse(_ageCtrl.text) ?? 0,
        'height': int.tryParse(_heightCtrl.text) ?? 0,
        'weight': int.tryParse(_weightCtrl.text),
        'city': _cityCtrl.text.trim(),
        'current_club': _clubCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'video_url': videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _snack("🚀 Ton talent est en orbite !");
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.black,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? Colors.greenAccent : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Column(
        children: [
          _buildHeader(),
          _buildStepBar(),
          Expanded(
            child: FadeTransition(
              opacity: _stepAnim,
              child: _buildCurrentStep(),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevStep,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "STUDIO DE TALENT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _stepTitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Badge sport
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _color.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: _color, size: 13),
                const SizedBox(width: 5),
                Text(
                  _sportLabel(_sport).toUpperCase(),
                  style: TextStyle(
                    color: _color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 0:
        return "Étape 1 — Ta vidéo talent";
      case 1:
        return "Étape 2 — Ton profil sportif";
      case 2:
        return "Étape 3 — Confirmation";
      default:
        return "";
    }
  }

  // ── Barre de progression ────────────────────────────────────
  Widget _buildStepBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final done = i <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: done ? _color : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: _color.withOpacity(0.35),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepVideo();
      case 1:
        return _buildStepInfos();
      case 2:
        return _buildStepConfirm();
      default:
        return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 1 — VIDÉO
  // ═══════════════════════════════════════════════════════════

  Widget _buildStepVideo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone vidéo
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _videoFile != null
                      ? _color.withOpacity(0.5)
                      : Colors.white10,
                  width: _videoFile != null ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  _videoFile != null &&
                      (_previewCtrl?.value.isInitialized ?? false)
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _previewCtrl!.value.size.width,
                            height: _previewCtrl!.value.size.height,
                            child: VideoPlayer(_previewCtrl!),
                          ),
                        ),
                        // Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _color.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_rounded,
                                      color: Colors.black,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "VIDÉO SÉLECTIONNÉE",
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _pickVideo,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.video_call_rounded,
                            color: _color,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Appuyer pour sélectionner",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Vidéo MP4 · Max 3 minutes",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Conseils
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _color.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: _color,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "CONSEILS POUR UNE BONNE VIDÉO",
                      style: TextStyle(
                        color: _color,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._videoTips().map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _color.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _videoTips() {
    const tips = {
      'football': [
        "Montre tes gestes techniques en situation réelle",
        "Inclus des dribbles, passes et tirs si tu es attaquant",
        "Bonne luminosité et fond de terrain visible",
        "Maximum 3 min — les recruteurs regardent les 30 premières secondes",
      ],
      'basketball': [
        "Montre ton handle, tes passes et ton shoot",
        "Inclus des situations de jeu réelles",
        "Highlight de 2-3 min maximum",
      ],
      'athletics': [
        "Course chronométrée avec temps visible si possible",
        "Angle de caméra latéral pour la foulée",
        "Inclus ton échauffement et ta performance",
      ],
    };
    return tips[_sport] ??
        [
          "Montre tes meilleures actions en situation",
          "Bonne qualité d'image et son si commentaires",
          "2-3 minutes maximum, actions clés en premier",
        ];
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 2 — INFOS SPORTIVES
  // ═══════════════════════════════════════════════════════════

  Widget _buildStepInfos() {
    final postes = _kPostes[_sport] ?? ['Autre'];
    if (!postes.contains(_category)) _category = postes.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section sport (si l'athlète veut changer) ──
          _sectionHeader(Icons.sports_rounded, "SPORT PRATIQUÉ"),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _kSportLabels.entries.map((e) {
                final isActive = _sport == e.key;
                return GestureDetector(
                  onTap: () => setState(() {
                    _sport = e.key;
                    _category = _kPostes[_sport]?.first ?? '';
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _sportColor(e.key).withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? _sportColor(e.key).withOpacity(0.5)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sportIcon(e.key),
                          size: 13,
                          color: isActive ? _sportColor(e.key) : Colors.white38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          e.value,
                          style: TextStyle(
                            color: isActive
                                ? _sportColor(e.key)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),

          // ── Poste ──
          _sectionHeader(Icons.place_rounded, "POSTE / SPÉCIALITÉ"),
          const SizedBox(height: 10),
          _dropdown(
            value: postes.contains(_category) ? _category : postes.first,
            items: postes,
            onChanged: (v) => setState(() => _category = v!),
            icon: Icons.place_rounded,
          ),
          const SizedBox(height: 18),

          // ── Niveau ──
          _sectionHeader(Icons.bar_chart_rounded, "NIVEAU ACTUEL"),
          const SizedBox(height: 10),
          _dropdown(
            value: _niveau,
            items: const [
              'Amateur',
              'Semi-Professionnel',
              'Professionnel',
              'International',
            ],
            onChanged: (v) => setState(() => _niveau = v!),
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 18),

          // ── Pied/Main préféré(e) ──
          if ([
            'football',
            'basketball',
            'handball',
            'tennis',
          ].contains(_sport)) ...[
            _sectionHeader(
              _sport == 'tennis'
                  ? Icons.back_hand_outlined
                  : Icons.sports_soccer_rounded,
              _sport == 'tennis' ? "MAIN DOMINANTE" : "PIED PRÉFÉRÉ",
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Droitier', 'Gaucher', 'Ambidextre'].map((f) {
                final isActive = _foot == f;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _foot = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _color.withOpacity(0.15)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? _color.withOpacity(0.5)
                              : Colors.white10,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: isActive ? _color : Colors.white38,
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // ── Infos physiques ──
          _sectionHeader(
            Icons.person_outline_rounded,
            "INFORMATIONS PHYSIQUES",
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  _ageCtrl,
                  "Âge *",
                  Icons.cake_outlined,
                  isNumeric: true,
                  maxLen: 2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _heightCtrl,
                  "Taille (cm) *",
                  Icons.height_rounded,
                  isNumeric: true,
                  maxLen: 3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _weightCtrl,
                  "Poids (kg)",
                  Icons.monitor_weight_outlined,
                  isNumeric: true,
                  maxLen: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Localisation et club ──
          _field(_cityCtrl, "Ville / Région *", Icons.location_on_outlined),
          const SizedBox(height: 12),
          _field(_clubCtrl, "Club / Structure actuelle", Icons.shield_outlined),
          const SizedBox(height: 18),

          // ── Bio ──
          _sectionHeader(Icons.info_outline_rounded, "PRÉSENTATION COURTE"),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _bioCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Décris ton style de jeu, ton parcours...",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "* Champs obligatoires",
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 3 — CONFIRMATION
  // ═══════════════════════════════════════════════════════════

  Widget _buildStepConfirm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Aperçu vidéo
          if (_previewCtrl?.value.isInitialized ?? false)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color.withOpacity(0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _previewCtrl!.value.size.width,
                      height: _previewCtrl!.value.size.height,
                      child: VideoPlayer(_previewCtrl!),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon, color: Colors.black, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            _sportLabel(_sport).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Récap profil
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.07),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(color: _color.withOpacity(0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_icon, color: _color, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        "RÉCAPITULATIF DU PROFIL",
                        style: TextStyle(
                          color: _color,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Infos
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _recapRow(
                        Icons.sports_rounded,
                        "Sport",
                        _sportLabel(_sport),
                      ),
                      _recapRow(Icons.place_rounded, "Poste", _category),
                      _recapRow(Icons.bar_chart_rounded, "Niveau", _niveau),
                      if (_ageCtrl.text.isNotEmpty)
                        _recapRow(
                          Icons.cake_outlined,
                          "Âge",
                          "${_ageCtrl.text} ans",
                        ),
                      if (_heightCtrl.text.isNotEmpty)
                        _recapRow(
                          Icons.height_rounded,
                          "Taille",
                          "${_heightCtrl.text} cm",
                        ),
                      if (_weightCtrl.text.isNotEmpty)
                        _recapRow(
                          Icons.monitor_weight_outlined,
                          "Poids",
                          "${_weightCtrl.text} kg",
                        ),
                      if (_cityCtrl.text.isNotEmpty)
                        _recapRow(
                          Icons.location_on_outlined,
                          "Localisation",
                          _cityCtrl.text,
                        ),
                      if (_clubCtrl.text.isNotEmpty)
                        _recapRow(
                          Icons.shield_outlined,
                          "Club",
                          _clubCtrl.text,
                        ),
                      if ([
                        'football',
                        'basketball',
                        'handball',
                        'tennis',
                      ].contains(_sport))
                        _recapRow(
                          Icons.sports_soccer_rounded,
                          "Pied/Main",
                          _foot,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Note RGPD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Ta vidéo sera visible par les recruteurs et supporters de la plateforme. Tu peux la supprimer à tout moment depuis ton profil.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recapRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  // ── Boutons bas de page ─────────────────────────────────────
  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: _currentStep < 2
          ? GestureDetector(
              onTap: _nextStep,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _currentStep == 0 ? "SUIVANT →" : "VÉRIFIER →",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            )
          : GestureDetector(
              onTap: _isUploading ? null : _upload,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  color: _isUploading ? Colors.white10 : _color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isUploading
                      ? []
                      : [
                          BoxShadow(
                            color: _color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isUploading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: _color,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "ENVOI EN COURS...",
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          "🚀 PROPULSER MON TALENT",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  // ── Widgets helpers ─────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: _color, size: 14),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white38,
          size: 20,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumeric = false,
    int? maxLen,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      maxLength: maxLen,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.22),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: Colors.white38, size: 17),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}
