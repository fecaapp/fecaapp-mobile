import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'upload_talent_video.dart';
import 'talent_video_player.dart';
import '../models/user.dart';
import '../services/social_service.dart';

final supabase = sb.Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
// CONSTANTES SPORTS
// ═══════════════════════════════════════════════════════════════

class _Sport {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Sport({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_Sport> _kSports = [
  _Sport(
    key: 'all',
    label: 'Tous',
    icon: Icons.apps_rounded,
    color: Color(0xFF3CFF7E),
  ),
  _Sport(
    key: 'football',
    label: 'Football',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF3CFF7E),
  ),
  _Sport(
    key: 'basketball',
    label: 'Basketball',
    icon: Icons.sports_basketball_rounded,
    color: Color(0xFFFFA500),
  ),
  _Sport(
    key: 'handball',
    label: 'Handball',
    icon: Icons.sports_handball_rounded,
    color: Color(0xFFFF3131),
  ),
  _Sport(
    key: 'athletics',
    label: 'Athlétisme',
    icon: Icons.directions_run_rounded,
    color: Color(0xFFFF6B00),
  ),
  _Sport(
    key: 'tennis',
    label: 'Tennis',
    icon: Icons.sports_tennis_rounded,
    color: Color(0xFFC8FF00),
  ),
  _Sport(
    key: 'volleyball',
    label: 'Volleyball',
    icon: Icons.sports_volleyball_rounded,
    color: Color(0xFF9B59FF),
  ),
  _Sport(
    key: 'boxing',
    label: 'Boxe',
    icon: Icons.sports_mma_rounded,
    color: Color(0xFFFFB800),
  ),
  _Sport(
    key: 'mma',
    label: 'MMA',
    icon: Icons.sports_kabaddi_rounded,
    color: Color(0xFF00CFFF),
  ),
  _Sport(
    key: 'karate',
    label: 'Karaté',
    icon: Icons.sports_martial_arts_rounded,
    color: Color(0xFFFF0044),
  ),
];

_Sport _sportByKey(String key) =>
    _kSports.firstWhere((s) => s.key == key, orElse: () => _kSports[0]);

// ═══════════════════════════════════════════════════════════════
// TALENTS SCREEN
// ═══════════════════════════════════════════════════════════════

class TalentsScreen extends StatefulWidget {
  final User user;
  const TalentsScreen({super.key, required this.user});

  @override
  State<TalentsScreen> createState() => _TalentsScreenState();
}

class _TalentsScreenState extends State<TalentsScreen>
    with SingleTickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  final PageController _pageController = PageController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedSport = 'all';
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _selectedFoot = 'Tous';
  int? _selectedAge;
  double _selectedHeight = 140.0;
  final TextEditingController _ageCtrl = TextEditingController();

  // Profil de l'athlète connecté (pour pré-remplissage upload)
  Map<String, dynamic> _myProfile = {};

  late AnimationController _fabAnimCtrl;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnim = CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.elasticOut);
    _fabAnimCtrl.forward();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchCtrl.dispose();
    _ageCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  // ── Charge le profil pour pré-remplissage ──────────────────
  Future<void> _loadMyProfile() async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', widget.user.id)
          .single();
      if (mounted) setState(() => _myProfile = data);
    } catch (e) {
      debugPrint("🦁 loadMyProfile: $e");
    }
  }

  bool get _canPublish => [
    'joueur',
    'athlete',
    'jeune talent',
  ].contains(widget.user.role.toLowerCase().trim());

  Color get _currentColor => _sportByKey(_selectedSport).color;

  // ── Filtre sheet ────────────────────────────────────────────
  void _showFilterSheet() {
    const postes = {
      'football': ['Tous', 'Gardien', 'Défenseur', 'Milieu', 'Attaquant'],
      'basketball': ['Tous', 'Meneur', 'Arrière', 'Ailier', 'Pivot'],
      'handball': [
        'Tous',
        'Gardien',
        'Pivot',
        'Ailier',
        'Demi-Centre',
        'Arrière',
      ],
      'volleyball': ['Tous', 'Passeur', 'Libéro', 'Central', 'Pointu'],
    };
    final catList = postes[_selectedSport] ?? ['Tous'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: _currentColor, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      "FILTRES DE DÉTECTION",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Poste (si sport concerné) ──
                if (catList.length > 1) ...[
                  _filterLabel("POSTE"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: catList
                        .map(
                          (cat) => _chip(
                            label: cat,
                            selected: _selectedCategory == cat,
                            color: _currentColor,
                            onTap: () =>
                                setModal(() => _selectedCategory = cat),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Pied préféré (football / basketball) ──
                if ([
                  'football',
                  'basketball',
                  'handball',
                ].contains(_selectedSport)) ...[
                  _filterLabel("PIED / MAIN PRÉFÉRÉ(E)"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Tous', 'Droitier', 'Gaucher', 'Ambidextre']
                        .map(
                          (f) => _chip(
                            label: f,
                            selected: _selectedFoot == f,
                            color: _currentColor,
                            onTap: () => setModal(() => _selectedFoot = f),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Âge ──
                _filterLabel("ÂGE EXACT"),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Ex : 19",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.cake_outlined,
                        color: Colors.white38,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (v) =>
                        setModal(() => _selectedAge = int.tryParse(v)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Taille ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _filterLabel("TAILLE MINIMUM"),
                    Text(
                      "${_selectedHeight.toInt()} cm",
                      style: TextStyle(
                        color: _currentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _selectedHeight,
                  min: 140,
                  max: 210,
                  divisions: 70,
                  activeColor: _currentColor,
                  inactiveColor: Colors.white10,
                  onChanged: (v) => setModal(() => _selectedHeight = v),
                ),
                const SizedBox(height: 24),

                // ── Boutons ──
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModal(() {
                            _selectedCategory = 'Tous';
                            _selectedFoot = 'Tous';
                            _selectedAge = null;
                            _selectedHeight = 140;
                            _ageCtrl.clear();
                          });
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Center(
                            child: Text(
                              "RÉINITIALISER",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              "DÉTECTER",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterLabel(String t) => Text(
    t,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? color.withOpacity(0.18)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color.withOpacity(0.6) : Colors.white10,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : Colors.white54,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );

  // ── Upload ──────────────────────────────────────────────────
  void _goUpload() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UploadTalentScreen(userId: widget.user.id, profileData: _myProfile),
      ),
    );
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          const SizedBox(height: kToolbarHeight + 44),
          _buildSportSelector(),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              key: ValueKey(
                "$_selectedSport$_selectedCategory$_selectedFoot"
                "$_selectedAge$_selectedHeight$_searchQuery",
              ),
              future: _fetchTalents(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _currentColor,
                      strokeWidth: 2,
                    ),
                  );
                }
                final talents = snap.data ?? [];
                if (talents.isEmpty) return _buildEmpty();
                return PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: talents.length,
                  itemBuilder: (_, i) => TalentVideoPlayer(
                    talent: talents[i],
                    sportColor: _sportByKey(
                      talents[i]['sport_type']?.toString() ?? _selectedSport,
                    ).color,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canPublish ? _buildFAB() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Rechercher un talent...",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _currentColor,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(Icons.tune_rounded, color: _currentColor, size: 20),
            ),
            onPressed: _showFilterSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildSportSelector() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kSports.length,
        itemBuilder: (_, i) {
          final sport = _kSports[i];
          final isActive = _selectedSport == sport.key;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedSport = sport.key;
                _selectedCategory = 'Tous';
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? sport.color.withOpacity(0.18)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? sport.color.withOpacity(0.6)
                      : Colors.white10,
                  width: isActive ? 1.2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sport.icon,
                    size: 15,
                    color: isActive ? sport.color : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sport.label,
                    style: TextStyle(
                      color: isActive ? sport.color : Colors.white38,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sports_rounded,
          size: 52,
          color: _currentColor.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        Text(
          "Aucun talent trouvé",
          style: TextStyle(
            color: _currentColor.withOpacity(0.5),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Ajuste les filtres ou change de sport",
          style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildFAB() => ScaleTransition(
    scale: _fabAnim,
    child: GestureDetector(
      onTap: _goUpload,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _currentColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _currentColor.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Text(
              "PUBLIER MON TALENT",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════
  // FETCH TALENTS
  // ══════════════════════════════════════════════════════════

  Future<List<dynamic>> _fetchTalents() async {
    try {
      // ✅ Jointure likes + comments pour comptage côté client
      var query = supabase.from('talents').select('''
            *,
            users:user_id(full_name, img_url, is_certified, sport, level, position, city),
            likes(user_id),
            comments(id)
          ''');

      // Filtre sport
      if (_selectedSport != 'all') {
        query = query.eq('sport_type', _selectedSport);
      }

      // Filtres additionnels
      if (_selectedCategory != 'Tous' && _selectedCategory.isNotEmpty) {
        query = query.eq('category', _selectedCategory);
      }
      if (_selectedFoot != 'Tous' && _selectedFoot.isNotEmpty) {
        query = query.eq('foot', _selectedFoot);
      }
      if (_selectedAge != null) {
        query = query.eq('age', _selectedAge!);
      }
      if (_selectedHeight > 140) {
        query = query.gte('height', _selectedHeight.toInt());
      }

      final data = await query.order('created_at', ascending: false);

      List<dynamic> mapped = (data as List).map((talent) {
        final List likes = talent['likes'] ?? [];
        final List comments = talent['comments'] ?? [];

        // ✅ Comptage depuis jointures — jamais désynchronisé
        talent['likes_count'] = likes.length;
        talent['comments_count'] = comments.length;
        talent['is_liked_by_me'] = likes.any(
          (l) => l['user_id'].toString().trim() == widget.user.id.trim(),
        );
        talent['reposts_count'] =
            int.tryParse(talent['reposts_count']?.toString() ?? '0') ?? 0;

        return talent;
      }).toList();

      // Filtre recherche locale
      if (_searchQuery.isNotEmpty) {
        mapped = mapped.where((t) {
          final name = (t['users']?['full_name'] ?? '')
              .toString()
              .toLowerCase();
          final city = (t['city'] ?? t['users']?['city'] ?? '')
              .toString()
              .toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || city.contains(q);
        }).toList();
      }

      return mapped;
    } catch (e) {
      debugPrint("🦁 ERREUR FETCH TALENTS: $e");
      return [];
    }
  }
}
