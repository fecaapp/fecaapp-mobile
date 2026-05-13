import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ═══════════════════════════════════════════════════════════════
// CREATE GROUP SCREEN — PREMIUM
// ═══════════════════════════════════════════════════════════════

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedType = "Match";
  bool _isLoading = false;
  File? _imageFile;
  bool _isPrivate = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _groupTypes = [
    {
      'label': 'Match',
      'icon': Icons.sports_soccer_rounded,
      'color': const Color(0xFF3CFF7E),
      'desc': 'Discussions live de matchs',
    },
    {
      'label': 'Club',
      'icon': Icons.shield_rounded,
      'color': Colors.blueAccent,
      'desc': 'Supporters d\'un club',
    },
    {
      'label': 'Ultras',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.orangeAccent,
      'desc': 'Groupe de supporters passionnés',
    },
    {
      'label': 'Analyse',
      'icon': Icons.analytics_rounded,
      'color': Colors.purpleAccent,
      'desc': 'Débats tactiques et analyses',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── SÉLECTION IMAGE ──────────────────────────────────────────

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  // ── CRÉATION ─────────────────────────────────────────────────

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack("Donne un nom à ta tribu, Lion ! 🦁", isError: true);
      return;
    }
    if (name.length < 3) {
      _showSnack("Le nom doit faire au moins 3 caractères", isError: true);
      return;
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      _showSnack("Session expirée. Reconnecte-toi.", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      String? imageUrl;

      // Upload avatar groupe
      if (_imageFile != null) {
        final fileName = 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('avatars').upload(fileName, _imageFile!);
        imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // Insertion groupe
      final groupData = await supabase
          .from('groups')
          .insert({
            'name': name,
            'description': _descController.text.trim(),
            'type': _selectedType,
            'image_url': imageUrl,
            'creator_id': currentUser.id,
            'is_private': _isPrivate,
            'members_count': 1,
          })
          .select()
          .single();

      final String groupId = groupData['id'];

      // Créateur en ADMIN
      await supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': currentUser.id,
        'role': 'ADMIN',
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        _showSnack("Tribu fondée avec succès ! 🔥");
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Erreur création tribu: $e");
      String msg = "Rugissement interrompu... Réessaie.";
      if (e.toString().contains('42501')) {
        msg = "Permission refusée. Vérifie les RLS Supabase.";
      }
      if (mounted) _showSnack(msg, isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Effet de fond
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _typeColor(_selectedType).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Contenu
          FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildAvatarSection(),
                        const SizedBox(height: 32),
                        _buildFieldSection(),
                        const SizedBox(height: 28),
                        _buildTypeSection(),
                        const SizedBox(height: 28),
                        _buildPrivacyToggle(),
                        const SizedBox(height: 40),
                        _buildCreateButton(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overlay loading
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
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
                      "CRÉATION EN COURS...",
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "NOUVELLE TRIBU",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: Colors.white.withOpacity(0.06), height: 1),
      ),
    );
  }

  // ── AVATAR ───────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final Color accent = _typeColor(_selectedType);
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo animé
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
            // Avatar
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF121212),
                border: Border.all(color: accent.withOpacity(0.4), width: 2),
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          color: accent,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PHOTO",
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            // Badge "modifier"
            if (_imageFile != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF050505),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── CHAMPS ───────────────────────────────────────────────────

  Widget _buildFieldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("NOM DE LA TRIBU"),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _nameController,
          hint: "Ex: Lions de Douala, Ultras Yaoundé...",
          icon: Icons.shield_rounded,
          maxLength: 40,
        ),
        const SizedBox(height: 20),
        _sectionLabel("DESCRIPTION"),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _descController,
          hint: "Décris l'objectif de ta tribu...",
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              icon,
              color: _typeColor(_selectedType).withOpacity(0.5),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.18),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          counterStyle: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  // ── TYPE ─────────────────────────────────────────────────────

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("CATÉGORIE"),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: _groupTypes.length,
          itemBuilder: (context, i) {
            final t = _groupTypes[i];
            final bool isSelected = _selectedType == t['label'];
            final Color color = t['color'] as Color;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = t['label'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.12)
                      : const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.06),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          t['icon'] as IconData,
                          color: isSelected ? color : Colors.white24,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              t['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              t['desc'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── PRIVÉ/PUBLIC ─────────────────────────────────────────────

  Widget _buildPrivacyToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (_isPrivate ? Colors.amber : Colors.white).withOpacity(
                0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _isPrivate ? Colors.amber : Colors.white38,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? "Tribu Privée" : "Tribu Publique",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _isPrivate
                      ? "Sur invitation uniquement"
                      : "Tout le monde peut rejoindre",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivate,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _isPrivate = v);
            },
            activeThumbColor: Colors.amber,
            activeTrackColor: Colors.amber.withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  // ── BOUTON CRÉER ─────────────────────────────────────────────

  Widget _buildCreateButton() {
    final Color accent = _typeColor(_selectedType);
    return GestureDetector(
      onTap: _isLoading ? null : _handleCreate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)]
                : [accent, accent.withOpacity(0.7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "FONDER LA TRIBU",
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
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: _typeColor(_selectedType),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Match':
        return const Color(0xFF3CFF7E);
      case 'Club':
        return Colors.blueAccent;
      case 'Ultras':
        return Colors.orangeAccent;
      case 'Analyse':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF3CFF7E);
    }
  }
}
