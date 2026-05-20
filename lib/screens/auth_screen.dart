import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as model;
import 'upload_cert_pro_screen.dart';
import 'home_screen.dart';

// ═══════════════════════════════════════════════════════════════
// CONSTANTES — RÔLES (5 rôles officiels)
// ═══════════════════════════════════════════════════════════════

class _RoleOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool requiresCert;
  const _RoleOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.requiresCert = false,
  });
}

const List<_RoleOption> _kRoles = [
  _RoleOption(
    value: 'supporter',
    label: 'Supporter',
    subtitle: 'Suis et soutiens tes Lions',
    icon: Icons.emoji_events_rounded,
  ),
  _RoleOption(
    value: 'athlete',
    label: 'Athlète',
    subtitle: 'Montre ton talent au monde',
    icon: Icons.sports_soccer_rounded,
  ),
  _RoleOption(
    value: 'club',
    label: 'Club',
    subtitle: 'Représente ton institution',
    icon: Icons.shield_rounded,
    requiresCert: true,
  ),
  _RoleOption(
    value: 'agent',
    label: 'Agent / Recruteur',
    subtitle: 'Découvre les prochaines stars',
    icon: Icons.manage_accounts_rounded,
    requiresCert: true,
  ),
  _RoleOption(
    value: 'journaliste',
    label: 'Journaliste',
    subtitle: 'Couvre l\'actualité du sport',
    icon: Icons.mic_rounded,
    requiresCert: true,
  ),
];

// ═══════════════════════════════════════════════════════════════
// CONSTANTES — SPORTS
// ═══════════════════════════════════════════════════════════════

const List<Map<String, dynamic>> _kSports = [
  {'value': 'football', 'label': 'Football', 'icon': Icons.sports_soccer},
  {
    'value': 'basketball',
    'label': 'Basketball',
    'icon': Icons.sports_basketball,
  },
  {'value': 'handball', 'label': 'Handball', 'icon': Icons.sports_handball},
  {'value': 'athletics', 'label': 'Athlétisme', 'icon': Icons.directions_run},
  {'value': 'tennis', 'label': 'Tennis', 'icon': Icons.sports_tennis},
  {
    'value': 'volleyball',
    'label': 'Volleyball',
    'icon': Icons.sports_volleyball,
  },
  {'value': 'boxing', 'label': 'Boxe', 'icon': Icons.sports_mma},
  {'value': 'mma', 'label': 'MMA', 'icon': Icons.sports_kabaddi},
  {'value': 'karate', 'label': 'Karaté', 'icon': Icons.sports_martial_arts},
];

// ═══════════════════════════════════════════════════════════════
// CHAMPS CV DYNAMIQUES PAR RÔLE + SPORT
// ═══════════════════════════════════════════════════════════════

List<_CvField> _cvFields(String role, String sport) {
  final common = <_CvField>[
    _CvField(
      key: 'city',
      label: 'Ville / Région',
      icon: Icons.location_on_outlined,
      hint: 'Ex : Yaoundé, Douala…',
    ),
    _CvField(
      key: 'country',
      label: 'Pays',
      icon: Icons.flag_outlined,
      hint: 'Ex : Cameroun',
    ),
    _CvField(
      key: 'birth_year',
      label: 'Année de naissance',
      icon: Icons.cake_outlined,
      hint: 'Ex : 1998',
      isNumeric: true,
    ),
  ];

  switch (role) {
    case 'athlete':
      final base = <_CvField>[
        ...common,
        _CvField(
          key: 'sport',
          label: 'Sport principal',
          icon: Icons.sports_rounded,
          isDropdown: true,
          dropdownItems: _kSports.map((s) => s['value'] as String).toList(),
          dropdownLabels: _kSports.map((s) => s['label'] as String).toList(),
        ),
        _CvField(
          key: 'level',
          label: 'Niveau actuel',
          icon: Icons.bar_chart_rounded,
          isDropdown: true,
          dropdownItems: [
            'amateur',
            'semi_pro',
            'professionnel',
            'international',
          ],
          dropdownLabels: [
            'Amateur',
            'Semi-Pro',
            'Professionnel',
            'International',
          ],
        ),
        _CvField(
          key: 'experience',
          label: 'Années d\'expérience',
          icon: Icons.timeline_rounded,
          hint: 'Ex : 5',
          isNumeric: true,
        ),
      ];
      switch (sport) {
        case 'football':
          return [
            ...base,
            _CvField(
              key: 'position',
              label: 'Poste',
              icon: Icons.place_rounded,
              isDropdown: true,
              dropdownItems: ['gardien', 'defenseur', 'milieu', 'attaquant'],
              dropdownLabels: ['Gardien', 'Défenseur', 'Milieu', 'Attaquant'],
            ),
            _CvField(
              key: 'strong_foot',
              label: 'Pied fort',
              icon: Icons.sports_soccer,
              isDropdown: true,
              dropdownItems: ['gauche', 'droit', 'les_deux'],
              dropdownLabels: ['Gauche', 'Droit', 'Les deux'],
            ),
            _CvField(
              key: 'current_club',
              label: 'Club actuel',
              icon: Icons.shield_outlined,
              hint: 'Ex : Canon Yaoundé',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Champion MTN Elite One 2022',
              maxLines: 3,
            ),
          ];
        case 'basketball':
          return [
            ...base,
            _CvField(
              key: 'position',
              label: 'Poste',
              icon: Icons.place_rounded,
              isDropdown: true,
              dropdownItems: [
                'meneur',
                'arriere',
                'ailier',
                'ailier_fort',
                'pivot',
              ],
              dropdownLabels: [
                'Meneur',
                'Arrière',
                'Ailier',
                'Ailier Fort',
                'Pivot',
              ],
            ),
            _CvField(
              key: 'height_cm',
              label: 'Taille (cm)',
              icon: Icons.height_rounded,
              hint: 'Ex : 192',
              isNumeric: true,
            ),
            _CvField(
              key: 'current_club',
              label: 'Club actuel',
              icon: Icons.shield_outlined,
              hint: 'Ex : FAP Basket',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : MVP Nationale 2023',
              maxLines: 3,
            ),
          ];
        case 'handball':
          return [
            ...base,
            _CvField(
              key: 'position',
              label: 'Poste',
              icon: Icons.place_rounded,
              isDropdown: true,
              dropdownItems: [
                'gardien',
                'pivot',
                'ailier',
                'demi_centre',
                'arriere',
              ],
              dropdownLabels: [
                'Gardien',
                'Pivot',
                'Ailier',
                'Demi-Centre',
                'Arrière',
              ],
            ),
            _CvField(
              key: 'current_club',
              label: 'Club actuel',
              icon: Icons.shield_outlined,
              hint: 'Ex : Aigle Royal Handball',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Championnat national 2022',
              maxLines: 3,
            ),
          ];
        case 'athletics':
          return [
            ...base,
            _CvField(
              key: 'discipline',
              label: 'Discipline',
              icon: Icons.directions_run,
              isDropdown: true,
              dropdownItems: [
                'sprint',
                'demi_fond',
                'fond',
                'saut',
                'lancer',
                'decathlon',
              ],
              dropdownLabels: [
                'Sprint',
                'Demi-fond',
                'Fond',
                'Saut',
                'Lancer',
                'Décathlon',
              ],
            ),
            _CvField(
              key: 'best_perf',
              label: 'Meilleure performance',
              icon: Icons.timer_outlined,
              hint: 'Ex : 10.4s / 200m',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Champion CEMAC 2022',
              maxLines: 3,
            ),
          ];
        case 'tennis':
          return [
            ...base,
            _CvField(
              key: 'dominant_hand',
              label: 'Main dominante',
              icon: Icons.back_hand_outlined,
              isDropdown: true,
              dropdownItems: ['droitier', 'gaucher'],
              dropdownLabels: ['Droitier', 'Gaucher'],
            ),
            _CvField(
              key: 'ranking',
              label: 'Classement national',
              icon: Icons.leaderboard_outlined,
              hint: 'Ex : 12',
              isNumeric: true,
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Open du Cameroun 2023',
              maxLines: 3,
            ),
          ];
        case 'volleyball':
          return [
            ...base,
            _CvField(
              key: 'position',
              label: 'Poste',
              icon: Icons.place_rounded,
              isDropdown: true,
              dropdownItems: [
                'passeur',
                'libero',
                'central',
                'pointu',
                'recepteur',
              ],
              dropdownLabels: [
                'Passeur',
                'Libéro',
                'Central',
                'Pointu',
                'Réceptionneur',
              ],
            ),
            _CvField(
              key: 'height_cm',
              label: 'Taille (cm)',
              icon: Icons.height_rounded,
              hint: 'Ex : 185',
              isNumeric: true,
            ),
            _CvField(
              key: 'current_club',
              label: 'Club actuel',
              icon: Icons.shield_outlined,
              hint: 'Ex : Nongoa VC',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Champion nationale 2022',
              maxLines: 3,
            ),
          ];
        case 'boxing':
        case 'mma':
          return [
            ...base,
            _CvField(
              key: 'weight_class',
              label: 'Catégorie de poids',
              icon: Icons.monitor_weight_outlined,
              isDropdown: true,
              dropdownItems: [
                'mouche',
                'plume',
                'leger',
                'welter',
                'moyen',
                'lourd',
              ],
              dropdownLabels: [
                'Mouche',
                'Plume',
                'Léger',
                'Welter',
                'Moyen',
                'Lourd',
              ],
            ),
            _CvField(
              key: 'record',
              label: 'Record (V-D-N)',
              icon: Icons.scoreboard_outlined,
              hint: 'Ex : 12-2-1',
            ),
            _CvField(
              key: 'gym',
              label: 'Salle / Gym',
              icon: Icons.fitness_center_outlined,
              hint: 'Ex : Boxing Club Yaoundé',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Champion Cameroun 2023',
              maxLines: 3,
            ),
          ];
        case 'karate':
          return [
            ...base,
            _CvField(
              key: 'discipline',
              label: 'Discipline',
              icon: Icons.sports_martial_arts,
              isDropdown: true,
              dropdownItems: ['kata', 'kumite', 'les_deux'],
              dropdownLabels: ['Kata', 'Kumité', 'Les deux'],
            ),
            _CvField(
              key: 'grade',
              label: 'Grade / Ceinture',
              icon: Icons.workspace_premium_outlined,
              isDropdown: true,
              dropdownItems: [
                'blanche',
                'jaune',
                'orange',
                'verte',
                'bleue',
                'marron',
                'noire',
              ],
              dropdownLabels: [
                'Blanche',
                'Jaune',
                'Orange',
                'Verte',
                'Bleue',
                'Marron',
                'Noire',
              ],
            ),
            _CvField(
              key: 'dojo',
              label: 'Dojo / Club',
              icon: Icons.house_outlined,
              hint: 'Ex : Dojo Central Yaoundé',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Ex : Médaille or CJSCA 2023',
              maxLines: 3,
            ),
          ];
        default:
          return [
            ...base,
            _CvField(
              key: 'current_club',
              label: 'Club / Structure',
              icon: Icons.shield_outlined,
              hint: 'Nom de votre club',
            ),
            _CvField(
              key: 'achievements',
              label: 'Palmarès / Titres',
              icon: Icons.emoji_events_outlined,
              hint: 'Vos meilleures performances',
              maxLines: 3,
            ),
          ];
      }

    case 'club':
      return [
        ...common,
        _CvField(
          key: 'sport',
          label: 'Sport principal',
          icon: Icons.sports_rounded,
          isDropdown: true,
          dropdownItems: _kSports.map((s) => s['value'] as String).toList(),
          dropdownLabels: _kSports.map((s) => s['label'] as String).toList(),
        ),
        _CvField(
          key: 'club_name',
          label: 'Nom officiel du club',
          icon: Icons.shield_outlined,
          hint: 'Ex : Canon Sportif de Yaoundé',
        ),
        _CvField(
          key: 'founded_year',
          label: 'Année de fondation',
          icon: Icons.calendar_today_outlined,
          hint: 'Ex : 1968',
          isNumeric: true,
        ),
        _CvField(
          key: 'league',
          label: 'Championnat / Ligue',
          icon: Icons.emoji_events_outlined,
          hint: 'Ex : MTN Elite One',
        ),
        _CvField(
          key: 'stadium',
          label: 'Stade / Salle home',
          icon: Icons.stadium_outlined,
          hint: 'Ex : Stade Ahmadou Ahidjo',
        ),
        _CvField(
          key: 'website',
          label: 'Site web / Réseaux',
          icon: Icons.language_outlined,
          hint: 'Ex : canon.cm',
        ),
        _CvField(
          key: 'achievements',
          label: 'Palmarès du club',
          icon: Icons.workspace_premium_outlined,
          hint: 'Titres et distinctions',
          maxLines: 4,
        ),
      ];

    case 'agent':
      return [
        ...common,
        _CvField(
          key: 'sport',
          label: 'Sport(s) représenté(s)',
          icon: Icons.sports_rounded,
          isDropdown: true,
          dropdownItems: _kSports.map((s) => s['value'] as String).toList(),
          dropdownLabels: _kSports.map((s) => s['label'] as String).toList(),
        ),
        _CvField(
          key: 'agency_name',
          label: 'Agence / Structure',
          icon: Icons.business_outlined,
          hint: 'Ex : Lions Sports Agency',
        ),
        _CvField(
          key: 'license_number',
          label: 'N° licence FIFA/CAF',
          icon: Icons.badge_outlined,
          hint: 'Ex : LIC-CAF-2023-XXXX',
        ),
        _CvField(
          key: 'experience',
          label: 'Années d\'expérience',
          icon: Icons.timeline_rounded,
          hint: 'Ex : 8',
          isNumeric: true,
        ),
        _CvField(
          key: 'nb_players',
          label: 'Athlètes représentés',
          icon: Icons.people_outline,
          hint: 'Ex : 12',
          isNumeric: true,
        ),
        _CvField(
          key: 'markets',
          label: 'Marchés / Pays couverts',
          icon: Icons.public_outlined,
          hint: 'Ex : Cameroun, France, Belgique',
          maxLines: 2,
        ),
        _CvField(
          key: 'bio',
          label: 'Présentation courte',
          icon: Icons.info_outline,
          hint: 'Votre parcours professionnel',
          maxLines: 4,
        ),
      ];

    case 'journaliste':
      return [
        ...common,
        _CvField(
          key: 'sport',
          label: 'Sport(s) couvert(s)',
          icon: Icons.sports_rounded,
          isDropdown: true,
          dropdownItems: _kSports.map((s) => s['value'] as String).toList(),
          dropdownLabels: _kSports.map((s) => s['label'] as String).toList(),
        ),
        _CvField(
          key: 'media_name',
          label: 'Média / Rédaction',
          icon: Icons.newspaper_outlined,
          hint: 'Ex : Cameroon Tribune, Canal2',
        ),
        _CvField(
          key: 'media_type',
          label: 'Type de média',
          icon: Icons.tv_outlined,
          isDropdown: true,
          dropdownItems: [
            'presse_ecrite',
            'television',
            'radio',
            'web',
            'podcast',
            'freelance',
          ],
          dropdownLabels: [
            'Presse écrite',
            'Télévision',
            'Radio',
            'Web/Blog',
            'Podcast',
            'Freelance',
          ],
        ),
        _CvField(
          key: 'experience',
          label: 'Années d\'expérience',
          icon: Icons.timeline_rounded,
          hint: 'Ex : 6',
          isNumeric: true,
        ),
        _CvField(
          key: 'press_card',
          label: 'N° Carte de presse',
          icon: Icons.badge_outlined,
          hint: 'Ex : CP-CAM-2022-XXXX',
        ),
        _CvField(
          key: 'bio',
          label: 'Biographie courte',
          icon: Icons.info_outline,
          hint: 'Vos spécialités et sujets de prédilection',
          maxLines: 4,
        ),
      ];

    default: // supporter
      return [
        ...common,
        _CvField(
          key: 'sport',
          label: 'Sport favori',
          icon: Icons.sports_rounded,
          isDropdown: true,
          dropdownItems: _kSports.map((s) => s['value'] as String).toList(),
          dropdownLabels: _kSports.map((s) => s['label'] as String).toList(),
        ),
        _CvField(
          key: 'favorite_club',
          label: 'Club de cœur',
          icon: Icons.favorite_outline,
          hint: 'Ex : Lions Indomptables, Canon…',
        ),
        _CvField(
          key: 'supporter_since',
          label: 'Supporter depuis',
          icon: Icons.calendar_today_outlined,
          hint: 'Ex : 2005',
          isNumeric: true,
        ),
        _CvField(
          key: 'bio',
          label: 'Présentation (optionnel)',
          icon: Icons.info_outline,
          hint: 'Dis-nous pourquoi tu soutiens le sport camerounais',
          maxLines: 3,
        ),
      ];
  }
}

class _CvField {
  final String key;
  final String label;
  final IconData icon;
  final String? hint;
  final bool isPassword;
  final bool isNumeric;
  final bool isDropdown;
  final List<String> dropdownItems;
  final List<String> dropdownLabels;
  final int maxLines;

  const _CvField({
    required this.key,
    required this.label,
    required this.icon,
    this.hint,
    this.isPassword = false,
    this.isNumeric = false,
    this.isDropdown = false,
    this.dropdownItems = const [],
    this.dropdownLabels = const [],
    this.maxLines = 1,
  });
}

// ═══════════════════════════════════════════════════════════════
// AUTH SCREEN
// ═══════════════════════════════════════════════════════════════

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cpwCtrl = TextEditingController();

  final Map<String, TextEditingController> _cvControllers = {};
  final Map<String, String> _cvDropdowns = {};

  late AnimationController _fadeCtrl, _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _page = 0;
  int _step = 0;
  String _role = 'supporter';
  String _sport = 'football';
  bool _loading = false;
  bool _pwVis = false;
  bool _cpwVis = false;
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
    _rebuildCvControllers();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _cpwCtrl.dispose();
    for (final c in _cvControllers.values) c.dispose();
    super.dispose();
  }

  void _rebuildCvControllers() {
    for (final c in _cvControllers.values) c.dispose();
    _cvControllers.clear();
    _cvDropdowns.clear();
    final fields = _cvFields(_role, _sport);
    for (final f in fields) {
      if (!f.isDropdown) {
        _cvControllers[f.key] = TextEditingController();
      } else {
        _cvDropdowns[f.key] = f.dropdownItems.isNotEmpty
            ? f.dropdownItems.first
            : '';
      }
    }
    if (_cvDropdowns.containsKey('sport')) _cvDropdowns['sport'] = _sport;
  }

  void _animate() {
    _fadeCtrl.reset();
    _slideCtrl.reset();
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  void _switchPage(int p) {
    if (p == _page) return;
    HapticFeedback.selectionClick();
    setState(() {
      _page = p;
      _step = 0;
    });
    _animate();
  }

  void _nextStep() {
    HapticFeedback.mediumImpact();
    setState(() => _step++);
    _animate();
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    setState(() => _step--);
    _animate();
  }

  _RoleOption get _roleOption => _kRoles.firstWhere((r) => r.value == _role);
  bool get _requiresCert => _roleOption.requiresCert;

  void _msg(String m, {bool ok = true}) {
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
                m,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text.trim();
    if (email.isEmpty || pw.isEmpty) {
      _msg("Identifiants manquants", ok: false);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: pw,
      );
      if (res.user != null) {
        final data = await supabase
            .from('users')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();
        if (data == null) {
          _msg("Profil introuvable", ok: false);
          return;
        }
        final user = model.User.fromJson(data);
        if (!mounted) return;
        const proRoles = ['club', 'agent', 'journaliste'];
        if (proRoles.contains(user.role) && !user.isCertified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UploadCertProScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
          );
        }
      }
    } on AuthException catch (e) {
      _msg(e.message, ok: false);
    } catch (e) {
      _msg('Erreur : $e', ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text.trim();
    final cpw = _cpwCtrl.text.trim();
    if (!_agree) {
      _msg("Veuillez accepter les CGU", ok: false);
      return;
    }
    if (name.isEmpty || email.isEmpty || pw.isEmpty) {
      _msg("Champs requis manquants", ok: false);
      return;
    }
    if (pw != cpw) {
      _msg("Mots de passe différents", ok: false);
      return;
    }
    if (pw.length < 6) {
      _msg("Mot de passe trop court (6 min)", ok: false);
      return;
    }

    final cvData = <String, dynamic>{};
    final fields = _cvFields(_role, _sport);
    for (final f in fields) {
      if (f.isDropdown) {
        cvData[f.key] = _cvDropdowns[f.key] ?? '';
      } else {
        final val = _cvControllers[f.key]?.text.trim() ?? '';
        if (val.isNotEmpty)
          cvData[f.key] = f.isNumeric ? int.tryParse(val) ?? val : val;
      }
    }

    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: pw,
        data: {'full_name': name, 'role': _role},
      );
      if (res.user != null) {
        await supabase
            .from('users')
            .update({
              'role': _role,
              'bio': cvData.remove('bio') ?? '',
              ...cvData,
            })
            .eq('id', res.user!.id);
        _msg('Compte créé ! Connecte-toi maintenant 🦁');
        _switchPage(0);
        _passwordCtrl.clear();
        _cpwCtrl.clear();
      }
    } on AuthException catch (e) {
      _msg("Erreur : ${e.message}", ok: false);
    } catch (e) {
      _msg('Erreur inattendue : $e', ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildToggle(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: _page == 0 ? _buildLogin() : _buildRegisterFlow(),
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

  Widget _buildBg() => Stack(
    children: [
      Positioned(
        top: -100,
        right: -80,
        child: _glow(300, const Color(0xFF3CFF7E), 0.10),
      ),
      Positioned(
        bottom: -120,
        left: -60,
        child: _glow(280, const Color(0xFF00C8FF), 0.07),
      ),
    ],
  );

  Widget _glow(double size, Color c, double op) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c.withOpacity(op), Colors.transparent]),
    ),
  );

  // ─── Header avec LOGO RÉEL ────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Logo de l'application (remplace l'emoji)
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3CFF7E).withOpacity(0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo_fecaapp.png',
                fit: BoxFit.cover,
                // Fallback si l'image ne charge pas
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3CFF7E), Color(0xFF00C8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text("🦁", style: TextStyle(fontSize: 30)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Titre adaptatif
          FittedBox(
            fit: BoxFit.scaleDown,
            child: const Text(
              "FECAAPP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Sous-titre adaptatif
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Le réseau social du sport camerounais",
              style: TextStyle(
                color: Colors.white.withOpacity(0.32),
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Toggle ──────────────────────────────────────────────────
  Widget _buildToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [_togBtn("CONNEXION", 0), _togBtn("INSCRIPTION", 1)],
      ),
    ),
  );

  Widget _togBtn(String lbl, int idx) {
    final on = _page == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchPage(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF3CFF7E) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                lbl,
                style: TextStyle(
                  color: on ? Colors.black : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // LOGIN
  // ═════════════════════════════════════════════════════════════
  Widget _buildLogin() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title("Bon retour parmi les Lions 🦁"),
        const SizedBox(height: 22),
        _field(
          ctrl: _emailCtrl,
          label: "Adresse email",
          icon: Icons.alternate_email_rounded,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _passwordCtrl,
          label: "Mot de passe",
          icon: Icons.lock_outline_rounded,
          isPw: true,
          vis: _pwVis,
          onVis: () => setState(() => _pwVis = !_pwVis),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _showForgotPassword,
            child: const Text(
              "Mot de passe oublié ?",
              style: TextStyle(
                color: Color(0xFF3CFF7E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _btn(label: "SE CONNECTER", onTap: _login),
        const SizedBox(height: 22),
        _orDiv(),
        const SizedBox(height: 22),
        _link(
          text: "Pas encore de compte ?",
          action: "Rejoindre FECAAPP",
          onTap: () => _switchPage(1),
        ),
      ],
    ),
  );

  // ═════════════════════════════════════════════════════════════
  // REGISTER — 3 ÉTAPES
  // ═════════════════════════════════════════════════════════════
  Widget _buildRegisterFlow() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  // ─── ÉTAPE 1 ─────────────────────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(1, 3),
        const SizedBox(height: 16),
        _title("Crée ton profil Lion"),
        Text(
          "Entre dans l'arène du sport camerounais",
          style: TextStyle(color: Colors.white.withOpacity(0.33), fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        _field(
          ctrl: _nameCtrl,
          label: "Nom complet",
          icon: Icons.person_outline_rounded,
          cap: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _emailCtrl,
          label: "Adresse email",
          icon: Icons.alternate_email_rounded,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _passwordCtrl,
          label: "Mot de passe",
          icon: Icons.lock_outline_rounded,
          isPw: true,
          vis: _pwVis,
          onVis: () => setState(() => _pwVis = !_pwVis),
          helper: "Minimum 6 caractères",
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _cpwCtrl,
          label: "Confirmer le mot de passe",
          icon: Icons.lock_outline_rounded,
          isPw: true,
          vis: _cpwVis,
          onVis: () => setState(() => _cpwVis = !_cpwVis),
        ),
        const SizedBox(height: 28),
        _btn(
          label: "CONTINUER →",
          onTap: () {
            final n = _nameCtrl.text.trim();
            final e = _emailCtrl.text.trim();
            final p = _passwordCtrl.text.trim();
            final c = _cpwCtrl.text.trim();
            if (n.isEmpty || e.isEmpty || p.isEmpty || c.isEmpty) {
              _msg("Champs requis manquants", ok: false);
              return;
            }
            if (p != c) {
              _msg("Mots de passe différents", ok: false);
              return;
            }
            if (p.length < 6) {
              _msg("Mot de passe trop court (6 min)", ok: false);
              return;
            }
            _nextStep();
          },
        ),
        const SizedBox(height: 18),
        _link(
          text: "Déjà membre ?",
          action: "Se connecter",
          onTap: () => _switchPage(0),
        ),
      ],
    ),
  );

  // ─── ÉTAPE 2 — Choix du rôle ──────────────────────────────────
  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _backBtn(_prevStep),
            const SizedBox(width: 12),
            Expanded(child: _stepBar(2, 3)),
          ],
        ),
        const SizedBox(height: 16),
        _title("Quel est ton rôle ?"),
        Text(
          "Choisis l'identité qui te correspond",
          style: TextStyle(color: Colors.white.withOpacity(0.33), fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        // Grille 2 colonnes — hauteur fixe suffisante pour le contenu
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            // Hauteur dynamique basée sur la largeur de la carte
            final cardHeight = cardWidth * 0.72;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kRoles
                  .map(
                    (r) => SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _roleCard(r),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (_requiresCert) _certBadge(),
        const SizedBox(height: 20),
        _agreeCheck(),
        const SizedBox(height: 20),
        _btn(
          label: "CONTINUER →",
          onTap: () {
            if (!_agree) {
              _msg("Veuillez accepter les CGU", ok: false);
              return;
            }
            _rebuildCvControllers();
            _nextStep();
          },
        ),
      ],
    ),
  );

  // ─── ÉTAPE 3 — CV Sportif ──────────────────────────────────────
  Widget _buildStep3() {
    final fields = _cvFields(_role, _sport);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _backBtn(_prevStep),
              const SizedBox(width: 12),
              Expanded(child: _stepBar(3, 3)),
            ],
          ),
          const SizedBox(height: 16),
          _title("Ton profil sportif"),
          Text(
            "Ces informations valorisent ta présence sur FECAAPP",
            style: TextStyle(
              color: Colors.white.withOpacity(0.33),
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Badge rôle sélectionné
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF3CFF7E).withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3CFF7E).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _roleOption.icon,
                  color: const Color(0xFF3CFF7E),
                  size: 15,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _roleOption.label,
                    style: const TextStyle(
                      color: Color(0xFF3CFF7E),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Champs CV
          ...fields.map((f) {
            if (f.isDropdown) return _cvDropdownField(f);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _field(
                ctrl: _cvControllers[f.key]!,
                label: f.label,
                icon: f.icon,
                hint: f.hint,
                type: f.isNumeric ? TextInputType.number : TextInputType.text,
                maxLines: f.maxLines,
              ),
            );
          }),
          // Note facultatif
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 24),
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
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Ces données ne sont visibles que par toi et les recruteurs certifiés. Tu peux les modifier à tout moment dans ton profil.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.28),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _btn(label: "CRÉER MON COMPTE 🦁", onTap: _register),
        ],
      ),
    );
  }

  // ─── Dropdown CV ─────────────────────────────────────────────
  Widget _cvDropdownField(_CvField f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<String>(
          value: _cvDropdowns[f.key] ?? f.dropdownItems.first,
          dropdownColor: const Color(0xFF1A1A1A),
          isExpanded: true, // ← IMPORTANT : empêche l'overflow
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white38,
          ),
          decoration: InputDecoration(
            labelText: f.label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
            ),
            prefixIcon: Icon(f.icon, color: Colors.white38, size: 20),
            border: InputBorder.none,
          ),
          items: List.generate(
            f.dropdownItems.length,
            (i) => DropdownMenuItem(
              value: f.dropdownItems[i],
              child: Text(f.dropdownLabels[i], overflow: TextOverflow.ellipsis),
            ),
          ),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _cvDropdowns[f.key] = v;
              if (f.key == 'sport') {
                _sport = v;
                _rebuildCvControllers();
                _cvDropdowns['sport'] = v;
              }
            });
          },
        ),
      ),
    );
  }

  // ─── Role Card (responsive, sans overflow) ───────────────────
  Widget _roleCard(_RoleOption r) {
    final sel = _role == r.value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _role = r.value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF3CFF7E).withOpacity(0.09)
              : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sel
                ? const Color(0xFF3CFF7E).withOpacity(0.55)
                : Colors.white.withOpacity(0.07),
            width: sel ? 1.5 : 1,
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: const Color(0xFF3CFF7E).withOpacity(0.11),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF3CFF7E).withOpacity(0.14)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      r.icon,
                      color: sel ? const Color(0xFF3CFF7E) : Colors.white54,
                      size: 17,
                    ),
                  ),
                  if (r.requiresCert)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "PRO",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FittedBox pour que le label s'adapte à la largeur de la carte
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        color: sel ? const Color(0xFF3CFF7E) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.32),
                      fontSize: 9,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets utilitaires ─────────────────────────────────────

  Widget _stepBar(int cur, int tot) => Row(
    children: [
      ...List.generate(tot, (i) {
        final done = i < cur;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < tot - 1 ? 5 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFF3CFF7E)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              boxShadow: (i == cur - 1)
                  ? [
                      BoxShadow(
                        color: const Color(0xFF3CFF7E).withOpacity(0.38),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
          ),
        );
      }),
      const SizedBox(width: 8),
      Text(
        "$cur/$tot",
        style: TextStyle(
          color: Colors.white.withOpacity(0.28),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      // Adaptatif : le texte peut passer à la ligne si besoin
      overflow: TextOverflow.visible,
    ),
  );

  Widget _backBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size: 15,
      ),
    ),
  );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
    bool isPw = false,
    bool vis = false,
    VoidCallback? onVis,
    TextInputType type = TextInputType.text,
    TextCapitalization cap = TextCapitalization.none,
    String? helper,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: isPw && !vis,
            keyboardType: maxLines > 1 ? TextInputType.multiline : type,
            textCapitalization: cap,
            maxLines: isPw ? 1 : maxLines,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.18),
                fontSize: 13,
              ),
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.34),
                fontSize: 13,
              ),
              prefixIcon: Icon(icon, color: Colors.white38, size: 19),
              suffixIcon: isPw
                  ? IconButton(
                      icon: Icon(
                        vis
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.white24,
                        size: 19,
                      ),
                      onPressed: onVis,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 14 : 18,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              // Empêche le label de déborder
              isDense: false,
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              helper,
              style: TextStyle(
                color: Colors.white.withOpacity(0.23),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _btn({required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: _loading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: _loading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF3CFF7E), Color(0xFF00E5B0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _loading ? Colors.white10 : null,
            borderRadius: BorderRadius.circular(17),
            boxShadow: _loading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF3CFF7E).withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
          ),
        ),
      );

  Widget _certBadge() => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.orangeAccent.withOpacity(0.28)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.13),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: Colors.orangeAccent,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Certification professionnelle requise",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              const Text(
                "Un justificatif officiel sera demandé après inscription",
                style: TextStyle(color: Colors.white38, fontSize: 9),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _agreeCheck() => GestureDetector(
    onTap: () => setState(() => _agree = !_agree),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: _agree ? const Color(0xFF3CFF7E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _agree ? const Color(0xFF3CFF7E) : Colors.white24,
              width: 1.5,
            ),
          ),
          child: _agree
              ? const Icon(Icons.check_rounded, color: Colors.black, size: 13)
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: 12,
                height: 1.5,
              ),
              children: const [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: "Conditions d'utilisation",
                  style: TextStyle(
                    color: Color(0xFF3CFF7E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: " et la "),
                TextSpan(
                  text: "Politique de confidentialité",
                  style: TextStyle(
                    color: Color(0xFF3CFF7E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: " de FECAAPP"),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _orDiv() => Row(
    children: [
      Expanded(
        child: Divider(color: Colors.white.withOpacity(0.07), thickness: 1),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          "ou",
          style: TextStyle(
            color: Colors.white.withOpacity(0.22),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Divider(color: Colors.white.withOpacity(0.07), thickness: 1),
      ),
    ],
  );

  Widget _link({
    required String text,
    required String action,
    required VoidCallback onTap,
  }) => Center(
    child: GestureDetector(
      onTap: onTap,
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text(
            "$text ",
            style: TextStyle(
              color: Colors.white.withOpacity(0.33),
              fontSize: 13,
            ),
          ),
          Text(
            action,
            style: const TextStyle(
              color: Color(0xFF3CFF7E),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );

  // ─── Mot de passe oublié ─────────────────────────────────────
  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          left: 24,
          right: 24,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 22),
            // Logo dans le bottom sheet aussi
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo_fecaapp.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Text("🦁", style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Réinitialiser le mot de passe",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              "Un lien te sera envoyé par email",
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            _field(
              ctrl: ctrl,
              label: "Adresse email",
              icon: Icons.alternate_email_rounded,
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 22),
            _btn(
              label: "ENVOYER LE LIEN",
              onTap: () async {
                final email = ctrl.text.trim();
                if (email.isEmpty) return;
                try {
                  await supabase.auth.resetPasswordForEmail(email);
                  if (mounted) {
                    Navigator.pop(context);
                    _msg("Lien envoyé à $email ✓");
                  }
                } catch (e) {
                  _msg("Erreur : $e", ok: false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
