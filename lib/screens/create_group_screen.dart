import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'dart:io';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String selectedType = "Match";
  bool _isLoading = false;
  File? _imageFile;

  final List<Map<String, dynamic>> groupTypes = [
    {
      "label": "Match",
      "icon": Icons.sports_soccer,
      "color": const Color(0xFF00FF85),
    },
    {"label": "Club", "icon": Icons.shield, "color": Colors.blueAccent},
    {
      "label": "Ultras",
      "icon": Icons.fireplace_rounded,
      "color": Colors.orangeAccent,
    },
    {
      "label": "Analyse",
      "icon": Icons.analytics_rounded,
      "color": Colors.purpleAccent,
    },
  ];

  // LOGIQUE DE CRÉATION DE TRIBU
  Future<void> _handleCreateGroup() async {
    final currentUser = supabase.auth.currentUser;

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Donne un nom à ta tribu, Lion ! 🦁", isError: true);
      return;
    }

    if (currentUser == null) {
      _showSnackBar("Session expirée. Reconnecte-toi.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      // 1. Upload de l'image (si sélectionnée)
      if (_imageFile != null) {
        final fileName = 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('avatars').upload(fileName, _imageFile!);
        imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // 2. Insertion du groupe
      // On récupère l'ID avec .select().single()
      final groupData = await supabase
          .from('groups')
          .insert({
            'name': _nameController.text.trim(),
            'description': _descController.text.trim(),
            'type': selectedType,
            'image_url': imageUrl,
            'creator_id': currentUser.id,
          })
          .select()
          .single();

      final String groupId = groupData['id'];

      // 3. Ajout du créateur comme ADMIN (Étape critique)
      // On force le rôle ADMIN pour que le créateur ne soit pas en PENDING
      await supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': currentUser.id,
        'role': 'ADMIN',
      });

      if (mounted) {
        _showSnackBar("Tribu fondée avec succès ! 🔥");
        // Délai de confort pour la synchro Supabase
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      debugPrint("Erreur création tribu: $e");
      String errorMsg = "Rugissement interrompu... Réessaie.";

      if (e.toString().contains("42501")) {
        errorMsg = "Permission refusée. Vérifie tes RLS Supabase.";
      } else if (e.toString().contains("PGRST204")) {
        errorMsg = "Mise à jour de la base en cours. Patiente 5 secondes.";
      }

      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00FF85),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildBackgroundEffect(),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildAvatarPicker(),
                const SizedBox(height: 40),
                _buildSectionTitle("NOM DE LA TRIBU"),
                _buildCustomField(
                  _nameController,
                  "Ex: Lions de Douala...",
                  Icons.edit_note,
                ),
                const SizedBox(height: 25),
                _buildSectionTitle("DESCRIPTION (OPTIONNEL)"),
                _buildCustomField(
                  _descController,
                  "L'objectif du groupe...",
                  Icons.description,
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                _buildSectionTitle("CATÉGORIE DE RUGISSEMENT"),
                _buildTypeGrid(),
                const SizedBox(height: 40),
                _buildCreateButton(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "NOUVELLE TRIBU",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: () {
          /* Ton code ImagePicker ici */
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF121212),
                border: Border.all(
                  color: const Color(0xFF00FF85).withOpacity(0.3),
                  width: 2,
                ),
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? const Icon(
                      Icons.camera_enhance_rounded,
                      size: 30,
                      color: Color(0xFF00FF85),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF00FF85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF00FF85).withOpacity(0.5),
            size: 20,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: groupTypes.length,
      itemBuilder: (context, index) {
        final type = groupTypes[index];
        final isSelected = selectedType == type['label'];
        return InkWell(
          onTap: () => setState(() => selectedType = type['label']),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? type['color'].withOpacity(0.15)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected
                    ? type['color']
                    : Colors.white.withOpacity(0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type['icon'],
                  color: isSelected ? type['color'] : Colors.white24,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  type['label'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateButton() {
    return InkWell(
      onTap: _isLoading ? null : _handleCreateGroup,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey, Colors.black45]
                : [const Color(0xFF00FF85), const Color(0xFF00C853)],
          ),
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "FONDER LA TRIBU",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildBackgroundEffect() {
    return Positioned(
      top: -100,
      right: -50,
      child: Container(
        height: 300,
        width: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00FF85).withOpacity(0.05),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(),
        ),
      ),
    );
  }
}
