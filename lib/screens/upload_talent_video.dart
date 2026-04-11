import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class UploadTalentScreen extends StatefulWidget {
  final String userId;
  const UploadTalentScreen({super.key, required this.userId});

  @override
  State<UploadTalentScreen> createState() => _UploadTalentScreenState();
}

class _UploadTalentScreenState extends State<UploadTalentScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  File? _videoFile;
  VideoPlayerController? _previewController;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  bool _isUploading = false;
  String _selectedCategory = "Milieu";
  String _selectedSpecialite = "Meneur de jeu";
  String _selectedFoot = "Droitier";

  final Map<String, List<String>> _postesData = {
    "Gardien": ["Titulaire", "Remplaçant", "Spécialiste Penalty"],
    "Défenseur": ["Central", "Latéral Droit", "Latéral Gauche", "Libéro"],
    "Milieu": [
      "Meneur de jeu",
      "Offensif",
      "Défensif (Sentinelle)",
      "Relayeur",
    ],
    "Avant-Centre": [
      "Buteur (9)",
      "Ailier Droit",
      "Ailier Gauche",
      "Second Attaquant",
    ],
  };

  Future<void> _pickVideo() async {
    final XFile? selected = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (selected != null) {
      _videoFile = File(selected.path);
      _previewController?.dispose();
      _previewController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) => setState(() {}));
    }
  }

  // --- LOGIQUE DE PROPULSION (SYNCHRO USER.DART) ---
  Future<void> _propulserProfil() async {
    if (_videoFile == null ||
        _ageController.text.isEmpty ||
        _heightController.text.isEmpty) {
      _showSnackBar(
        "Remplis tous les champs et ajoute ta vidéo !",
        Colors.orange,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Vidéo vers bucket 'talents_videos'
      final fileExt = _videoFile!.path.split('.').last;
      final fileName =
          "talent_${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      final filePath = "${widget.userId}/$fileName";

      await supabase.storage
          .from('talents_videos')
          .upload(
            filePath,
            _videoFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String videoUrl = supabase.storage
          .from('talents_videos')
          .getPublicUrl(filePath);

      // 2. Mise à jour de la table 'talents' (Respecte les colonnes SQL créées précédemment)
      await supabase.from('talents').upsert({
        'user_id': widget.userId,
        'category': _selectedCategory,
        'specialty': _selectedSpecialite,
        'city': _cityController.text.trim(),
        'age': int.parse(_ageController.text),
        'height': int.parse(_heightController.text),
        'foot': _selectedFoot,
        'video_url': videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _showSnackBar("🚀 Ton profil est en orbite !", Colors.greenAccent);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Erreur : ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "STUDIO DE RECRUTEMENT",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Colors.greenAccent,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStudioHero(),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("INFOS PHYSIQUES"),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _customTextField(
                          "Âge",
                          Icons.cake,
                          _ageController,
                          isNumber: true,
                          maxLength: 2,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _customTextField(
                          "Taille (cm)",
                          Icons.height,
                          _heightController,
                          isNumber: true,
                          maxLength: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown(
                    label: "Pied fort",
                    value: _selectedFoot,
                    items: ["Droitier", "Gaucher", "Ambidextre"],
                    onChanged: (val) => setState(() => _selectedFoot = val!),
                  ),
                  const SizedBox(height: 30),
                  _buildSectionLabel("CLASSIFICATION TECHNIQUE"),
                  const SizedBox(height: 15),
                  _buildDropdown(
                    label: "Catégorie",
                    value: _selectedCategory,
                    items: _postesData.keys.toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val!;
                        _selectedSpecialite = _postesData[val]![0];
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildDropdown(
                    label: "Spécialité",
                    value: _selectedSpecialite,
                    items: _postesData[_selectedCategory]!,
                    onChanged: (val) =>
                        setState(() => _selectedSpecialite = val!),
                  ),
                  const SizedBox(height: 25),
                  _customTextField(
                    "Ville / Club actuel",
                    Icons.location_on_outlined,
                    _cityController,
                  ),
                  const SizedBox(height: 40),
                  _buildPropulsionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioHero() {
    return Container(
      height: 280,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child:
                (_previewController != null &&
                    _previewController!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: _previewController!.value.aspectRatio,
                    child: VideoPlayer(_previewController!),
                  )
                : Image.network(
                    "https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80",
                    fit: BoxFit.cover,
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                  Colors.black,
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: _pickVideo,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white10,
                    child: Icon(
                      _videoFile == null
                          ? Icons.video_call
                          : Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF111111),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _customTextField(
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isNumber = false,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: "",
          prefixIcon: Icon(icon, color: Colors.greenAccent, size: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      color: Colors.greenAccent,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    ),
  );

  Widget _buildPropulsionButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.greenAccent,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: (_videoFile == null || _isUploading) ? null : _propulserProfil,
      child: _isUploading
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text(
              "PROPULSER MON PROFIL",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
