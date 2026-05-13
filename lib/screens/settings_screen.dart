import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════════════════════════
// SETTINGS SCREEN — FECAAPP
// Modifications :
//  • Realtime sync → ProfileScreen se met à jour automatiquement
//  • Rappel certification 30 jours (snackbar discret)
// ════════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  // ── REALTIME : channel qui écoute les changements de l'user courant ──
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeToProfileChanges();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      _supabase.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  // ── Realtime : dès qu'un UPDATE touche la ligne de l'user,
  //    on rafraîchit l'état local → ProfileScreen reçoit aussi
  //    l'event via son propre channel et se met à jour.
  void _subscribeToProfileChanges() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _profileChannel = _supabase
        .channel('settings_profile_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                // Merge : on garde les clés existantes et on écrase
                // uniquement ce qui a changé
                _profile = {..._profile, ...payload.newRecord};
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      if (mounted)
        setState(() {
          _profile = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _role => (_profile['role'] ?? 'supporter').toString();
  bool get _isCertified => _profile['is_certified'] == true;

  // ── Calcul jours restants avant expiration certification ──
  int? get _certDaysLeft {
    final issuedRaw = _profile['cert_issued_at']?.toString();
    if (issuedRaw == null) return null;
    final issued = DateTime.tryParse(issuedRaw);
    if (issued == null) return null;
    return 30 - DateTime.now().difference(issued).inDays;
  }

  String _roleLabel(String r) {
    const m = {
      'supporter': 'Supporter',
      'athlete': 'Athlète',
      'club': 'Club',
      'agent': 'Agent / Recruteur',
      'journaliste': 'Journaliste',
    };
    return m[r] ?? r;
  }

  Color _roleColor(String r) {
    const m = {
      'supporter': Color(0xFF3CFF7E),
      'athlete': Colors.amber,
      'club': Colors.blueAccent,
      'agent': Colors.orangeAccent,
      'journaliste': Colors.purpleAccent,
    };
    return m[r] ?? const Color(0xFF3CFF7E);
  }

  IconData _roleIcon(String r) {
    const m = {
      'supporter': Icons.emoji_events_rounded,
      'athlete': Icons.sports_soccer_rounded,
      'club': Icons.shield_rounded,
      'agent': Icons.manage_accounts_rounded,
      'journaliste': Icons.mic_rounded,
    };
    return m[r] ?? Icons.person_rounded;
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _push(Widget page) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
  ).then((_) => _loadProfile());

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3CFF7E)),
        ),
      );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // ── App Bar
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            pinned: true,
            expandedHeight: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "PARAMÈTRES",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
            centerTitle: true,
            elevation: 0,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 28),

                  // ── Rappel renouvellement certification ──
                  if (_isCertified) _buildCertRenewalBanner(),
                  if (_isCertified) const SizedBox(height: 28),

                  _sectionLabel("CERTIFICATION"),
                  const SizedBox(height: 10),
                  _buildCertificationTile(),
                  const SizedBox(height: 28),

                  _sectionLabel("PROFIL ${_roleLabel(_role).toUpperCase()}"),
                  const SizedBox(height: 10),
                  _buildCvEntry(),
                  const SizedBox(height: 28),

                  _sectionLabel("COMPTE"),
                  const SizedBox(height: 10),
                  _buildGroup([
                    _tile(
                      Icons.person_outline_rounded,
                      "Informations personnelles",
                      () => _push(_PersonalInfoForm(profile: _profile)),
                    ),
                    _tile(
                      Icons.lock_outline_rounded,
                      "Mot de passe et sécurité",
                      () => _push(const _SecurityForm()),
                    ),
                    _tile(
                      Icons.language_rounded,
                      "Langue",
                      () => _push(const _LanguageSettings()),
                    ),
                    _tile(
                      Icons.payment_rounded,
                      "Modes de paiement",
                      () => _push(const _PaymentSettings()),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  _sectionLabel("AIDE & LÉGAL"),
                  const SizedBox(height: 10),
                  _buildGroup([
                    _tile(
                      Icons.support_agent_rounded,
                      "Contacter le support",
                      () => _push(const _SupportScreen()),
                    ),
                    _tile(
                      Icons.gavel_rounded,
                      "Conditions d'utilisation",
                      () => _push(const _TermsScreen()),
                    ),
                  ]),
                  const SizedBox(height: 40),

                  _buildLogoutBtn(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BANNIÈRE RENOUVELLEMENT CERTIFICATION (non-intrusive)
  // Affichée seulement si la certification expire dans ≤ 7 jours
  // ou est déjà expirée. Sinon invisible.
  // ─────────────────────────────────────────────────────────────
  Widget _buildCertRenewalBanner() {
    final days = _certDaysLeft;
    // Pas de date enregistrée → on n'affiche rien
    if (days == null) return const SizedBox.shrink();
    // Plus de 7 jours restants → pas de bannière
    if (days > 7) return const SizedBox.shrink();

    final isExpired = days <= 0;
    final color = isExpired ? Colors.orangeAccent : Colors.amber;
    final icon = isExpired
        ? Icons.warning_amber_rounded
        : Icons.access_time_rounded;
    final message = isExpired
        ? "Ta certification a expiré. Renouvelle-la pour garder ton badge vérifié."
        : "Ta certification expire dans $days jour${days > 1 ? 's' : ''}. Pense à la renouveler.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("RENOUVELLEMENT"),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _push(_certScreenForRole(_role));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Appuyer pour renouveler →",
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Retourne l'écran de certification selon le rôle
  Widget _certScreenForRole(String role) {
    switch (role) {
      case 'athlete':
        return const UploadCertScreen();
      case 'club':
      case 'agent':
      case 'journaliste':
        return const UploadCertProScreen();
      default:
        return const UploadScreen();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CARTE PROFIL
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final name = _profile['full_name'] ?? '';
    final email = _supabase.auth.currentUser?.email ?? '';
    final img = _profile['img_url']?.toString() ?? '';
    final color = _roleColor(_role);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [color, color.withOpacity(0.3), color],
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black,
              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
              child: img.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon(_role), color: color, size: 11),
                          const SizedBox(width: 5),
                          Text(
                            _roleLabel(_role).toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isCertified) ...[
                      const SizedBox(width: 8),
                      // ── Badge certifié avec indicateur expiration ──
                      Builder(
                        builder: (_) {
                          final days = _certDaysLeft;
                          final isExpiring = days != null && days <= 7;
                          final badgeColor = isExpiring
                              ? Colors.orangeAccent
                              : Colors.blueAccent;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExpiring
                                      ? Icons.access_time_rounded
                                      : Icons.verified_rounded,
                                  color: badgeColor,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExpiring ? "${days}J" : "CERTIFIÉ",
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CERTIFICATION TILE
  // ─────────────────────────────────────────────────────────────
  Widget _buildCertificationTile() {
    if (_isCertified) {
      final days = _certDaysLeft;
      final isExpired = days != null && days <= 0;
      final isExpiring = days != null && days > 0 && days <= 7;

      if (!isExpired && !isExpiring) {
        // Certifié, tout va bien
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 22),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Compte certifié",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Votre identité a été validée par l'équipe FecaApp.",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Certifié mais expiré ou bientôt expiré → cliquable pour renouveler
      final color = isExpired ? Colors.orangeAccent : Colors.amber;
      final label = isExpired
          ? "Certification expirée — Renouveler"
          : "Expire dans $days jour${days! > 1 ? 's' : ''} — Renouveler";

      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _push(_certScreenForRole(_role));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "La certification doit être renouvelée tous les 30 jours.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.5),
                size: 14,
              ),
            ],
          ),
        ),
      );
    }

    // Pas certifié → cliquable selon le rôle
    final data = _certDataForRole(_role);
    return GestureDetector(
      onTap: () => _push(data['screen'] as Widget),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (data['color'] as Color).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (data['color'] as Color).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (data['color'] as Color).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                data['icon'] as IconData,
                color: data['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['subtitle'] as String,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: (data['color'] as Color).withOpacity(0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _certDataForRole(String role) {
    switch (role) {
      case 'athlete':
        return {
          'color': Colors.amber,
          'icon': Icons.sports_soccer_rounded,
          'title': 'Certifier mon profil Athlète',
          'subtitle':
              'Documents sportifs requis pour le scouting professionnel',
          'screen': const UploadCertScreen(),
        };
      case 'club':
      case 'agent':
      case 'journaliste':
        return {
          'color': Colors.blueAccent,
          'icon': Icons.verified_user_rounded,
          'title': 'Certification Professionnelle',
          'subtitle': 'Licence ou accréditation officielle requise',
          'screen': const UploadCertProScreen(),
        };
      default:
        return {
          'color': const Color(0xFF3CFF7E),
          'icon': Icons.emoji_events_rounded,
          'title': 'Certifier mon profil Supporter',
          'subtitle':
              "Vérification d'identité pour rejoindre la communauté certifiée",
          'screen': const UploadScreen(),
        };
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CV ENTRY
  // ─────────────────────────────────────────────────────────────
  Widget _buildCvEntry() {
    return GestureDetector(
      onTap: () => _push(_CvEditScreen(profile: _profile, role: _role)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3CFF7E).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF3CFF7E),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Modifier mon CV sportif",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Mets à jour tes informations professionnelles",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS COMMUNS (inchangés)
  // ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withOpacity(0.28),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );

  Widget _buildGroup(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(
      children: children.asMap().entries.map((e) {
        final isLast = e.key == children.length - 1;
        return Column(
          children: [
            e.value,
            if (!isLast)
              Divider(
                color: Colors.white.withOpacity(0.05),
                height: 1,
                indent: 54,
              ),
          ],
        );
      }).toList(),
    ),
  );

  Widget _tile(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: Colors.white54, size: 17),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    trailing: const Icon(
      Icons.arrow_forward_ios_rounded,
      size: 12,
      color: Colors.white24,
    ),
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
  );

  Widget _buildLogoutBtn() => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Déconnexion",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            "Tu veux vraiment quitter la savane ?",
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "ANNULER",
                style: TextStyle(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: _logout,
              child: const Text(
                "DÉCONNEXION",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    },
    child: Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
          SizedBox(width: 10),
          Text(
            "Déconnexion",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// CV EDIT SCREEN — inchangé par rapport à l'original
// ════════════════════════════════════════════════════════════════

class _CvEditScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String role;
  const _CvEditScreen({required this.profile, required this.role});
  @override
  State<_CvEditScreen> createState() => _CvEditScreenState();
}

class _CvEditScreenState extends State<_CvEditScreen> {
  final _supabase = Supabase.instance.client;
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String> _drops = {};
  bool _saving = false;
  late String _currentSport;

  static const _sportItems = [
    'football',
    'basketball',
    'handball',
    'athletics',
    'tennis',
    'volleyball',
    'boxing',
    'mma',
    'karate',
  ];
  static const _sportLabels = [
    'Football',
    'Basketball',
    'Handball',
    'Athlétisme',
    'Tennis',
    'Volleyball',
    'Boxe',
    'MMA',
    'Karaté',
  ];
  static const _levelItems = [
    'amateur',
    'semi_pro',
    'professionnel',
    'international',
  ];
  static const _levelLabels = [
    'Amateur',
    'Semi-Professionnel',
    'Professionnel',
    'International',
  ];

  @override
  void initState() {
    super.initState();
    _currentSport = (widget.profile['sport'] ?? 'football')
        .toString()
        .toLowerCase();
    _buildFields();
  }

  void _buildFields() {
    for (final c in _ctrls.values) c.dispose();
    _ctrls.clear();
    _drops.clear();
    final fields = _getFields();
    for (final f in fields) {
      if (f.isDropdown) {
        final raw = (widget.profile[f.key]?.toString() ?? '').toLowerCase();
        final safe = f.items.contains(raw) ? raw : f.items.first;
        _drops[f.key] = safe;
      } else {
        _ctrls[f.key] = TextEditingController(
          text: widget.profile[f.key]?.toString() ?? '',
        );
      }
    }
  }

  List<_Field> _getFields() {
    final common = [
      _Field('city', 'Ville / Région', Icons.location_on_outlined),
      _Field('country', 'Pays', Icons.flag_outlined, def: 'Cameroun'),
      _Field(
        'birth_year',
        'Année de naissance',
        Icons.cake_outlined,
        numeric: true,
      ),
    ];

    switch (widget.role) {
      case 'athlete':
        return [
          ...common,
          _Field.drop(
            'sport',
            'Sport principal',
            Icons.sports_rounded,
            _sportItems,
            _sportLabels,
          ),
          _Field.drop(
            'level',
            'Niveau',
            Icons.bar_chart_rounded,
            _levelItems,
            _levelLabels,
          ),
          _Field(
            'experience',
            "Années d'expérience",
            Icons.timeline_rounded,
            numeric: true,
          ),
          ..._athleteSpecific(),
          _Field('current_club', 'Club actuel', Icons.shield_outlined),
          _Field(
            'achievements',
            'Palmarès',
            Icons.emoji_events_outlined,
            lines: 3,
          ),
        ];
      case 'club':
        return [
          ...common,
          _Field.drop(
            'sport',
            'Sport principal',
            Icons.sports_rounded,
            _sportItems,
            _sportLabels,
          ),
          _Field('club_name', 'Nom officiel du club', Icons.shield_rounded),
          _Field('league', 'Championnat / Ligue', Icons.emoji_events_outlined),
          _Field(
            'founded_year',
            'Année de fondation',
            Icons.calendar_today_outlined,
            numeric: true,
          ),
          _Field('stadium', 'Stade / Salle home', Icons.stadium_outlined),
          _Field('website', 'Site web / Réseaux', Icons.language_outlined),
          _Field(
            'achievements',
            'Palmarès du club',
            Icons.workspace_premium_outlined,
            lines: 3,
          ),
        ];
      case 'agent':
        return [
          ...common,
          _Field.drop(
            'sport',
            'Sport représenté',
            Icons.sports_rounded,
            _sportItems,
            _sportLabels,
          ),
          _Field('agency_name', 'Agence / Structure', Icons.business_outlined),
          _Field('license_number', 'N° Licence FIFA/CAF', Icons.badge_outlined),
          _Field(
            'experience',
            "Années d'expérience",
            Icons.timeline_rounded,
            numeric: true,
          ),
          _Field(
            'nb_players',
            'Athlètes représentés',
            Icons.people_outline,
            numeric: true,
          ),
          _Field(
            'markets',
            'Marchés / Pays couverts',
            Icons.public_outlined,
            lines: 2,
          ),
          _Field('bio', 'Présentation', Icons.info_outline, lines: 3),
        ];
      case 'journaliste':
        return [
          ...common,
          _Field.drop(
            'sport',
            'Sport couvert',
            Icons.sports_rounded,
            _sportItems,
            _sportLabels,
          ),
          _Field('media_name', 'Média / Rédaction', Icons.newspaper_outlined),
          _Field.drop(
            'media_type',
            'Type de média',
            Icons.tv_outlined,
            [
              'presse_ecrite',
              'television',
              'radio',
              'web',
              'podcast',
              'freelance',
            ],
            [
              'Presse écrite',
              'Télévision',
              'Radio',
              'Web/Blog',
              'Podcast',
              'Freelance',
            ],
          ),
          _Field(
            'experience',
            "Années d'expérience",
            Icons.timeline_rounded,
            numeric: true,
          ),
          _Field('press_card', 'N° Carte de presse', Icons.badge_outlined),
          _Field('bio', 'Biographie', Icons.info_outline, lines: 3),
        ];
      default:
        return [
          ...common,
          _Field.drop(
            'sport',
            'Sport favori',
            Icons.sports_rounded,
            _sportItems,
            _sportLabels,
          ),
          _Field('favorite_club', 'Club de cœur', Icons.favorite_outline),
          _Field(
            'supporter_since',
            'Supporter depuis',
            Icons.calendar_today_outlined,
            numeric: true,
          ),
          _Field('bio', 'Présentation', Icons.info_outline, lines: 3),
        ];
    }
  }

  List<_Field> _athleteSpecific() {
    switch (_currentSport) {
      case 'football':
        return [
          _Field.drop(
            'position',
            'Poste',
            Icons.place_rounded,
            ['gardien', 'defenseur', 'milieu', 'attaquant'],
            ['Gardien', 'Défenseur', 'Milieu', 'Attaquant'],
          ),
          _Field.drop(
            'strong_foot',
            'Pied fort',
            Icons.sports_soccer,
            ['gauche', 'droit', 'les_deux'],
            ['Gauche', 'Droit', 'Les deux'],
          ),
        ];
      case 'basketball':
      case 'volleyball':
        return [
          _Field.drop(
            'position',
            'Poste',
            Icons.place_rounded,
            [
              'meneur',
              'arriere',
              'ailier',
              'ailier_fort',
              'pivot',
              'passeur',
              'libero',
              'central',
              'pointu',
              'recepteur',
            ],
            [
              'Meneur',
              'Arrière',
              'Ailier',
              'Ailier Fort',
              'Pivot',
              'Passeur',
              'Libéro',
              'Central',
              'Pointu',
              'Réceptionneur',
            ],
          ),
          _Field(
            'height_cm',
            'Taille (cm)',
            Icons.height_rounded,
            numeric: true,
          ),
        ];
      case 'handball':
        return [
          _Field.drop(
            'position',
            'Poste',
            Icons.place_rounded,
            ['gardien', 'pivot', 'ailier', 'demi_centre', 'arriere'],
            ['Gardien', 'Pivot', 'Ailier', 'Demi-Centre', 'Arrière'],
          ),
        ];
      case 'athletics':
        return [
          _Field.drop(
            'discipline',
            'Discipline',
            Icons.directions_run,
            ['sprint', 'demi_fond', 'fond', 'saut', 'lancer', 'decathlon'],
            ['Sprint', 'Demi-fond', 'Fond', 'Saut', 'Lancer', 'Décathlon'],
          ),
          _Field('best_perf', 'Meilleure performance', Icons.timer_outlined),
        ];
      case 'tennis':
        return [
          _Field.drop(
            'dominant_hand',
            'Main dominante',
            Icons.back_hand_outlined,
            ['droitier', 'gaucher'],
            ['Droitier', 'Gaucher'],
          ),
          _Field(
            'ranking',
            'Classement national',
            Icons.leaderboard_outlined,
            numeric: true,
          ),
        ];
      case 'boxing':
      case 'mma':
        return [
          _Field.drop(
            'weight_class',
            'Catégorie de poids',
            Icons.monitor_weight_outlined,
            ['mouche', 'plume', 'leger', 'welter', 'moyen', 'lourd'],
            ['Mouche', 'Plume', 'Léger', 'Welter', 'Moyen', 'Lourd'],
          ),
          _Field('record', 'Record (V-D-N)', Icons.scoreboard_outlined),
          _Field('gym', 'Salle / Gym', Icons.fitness_center_outlined),
        ];
      case 'karate':
        return [
          _Field.drop(
            'discipline',
            'Discipline',
            Icons.sports_martial_arts,
            ['kata', 'kumite', 'les_deux'],
            ['Kata', 'Kumité', 'Les deux'],
          ),
          _Field.drop(
            'grade',
            'Ceinture',
            Icons.workspace_premium_outlined,
            ['blanche', 'jaune', 'orange', 'verte', 'bleue', 'marron', 'noire'],
            ['Blanche', 'Jaune', 'Orange', 'Verte', 'Bleue', 'Marron', 'Noire'],
          ),
          _Field('dojo', 'Dojo / Club', Icons.house_outlined),
        ];
      default:
        return [];
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final payload = <String, dynamic>{};
      for (final e in _ctrls.entries) {
        final v = e.value.text.trim();
        if (v.isNotEmpty) {
          final f = _getFields().firstWhere(
            (f) => f.key == e.key,
            orElse: () => _Field(e.key, '', Icons.info),
          );
          payload[e.key] = f.numeric ? int.tryParse(v) ?? v : v;
        }
      }
      for (final e in _drops.entries) {
        payload[e.key] = e.value;
      }
      // La mise à jour déclenche automatiquement le Realtime
      // → ProfileScreen et SettingsScreen se mettent à jour
      await _supabase.from('users').update(payload).eq('id', uid);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black, size: 17),
                SizedBox(width: 10),
                Text(
                  "CV mis à jour ✓",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF3CFF7E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _getFields();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "MON CV SPORTIF",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF3CFF7E).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF3CFF7E).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3CFF7E),
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Ces informations sont visibles sur ton profil public et valorisent ta présence sur FECAAPP.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...fields.map((f) {
            if (f.isDropdown) return _buildDropdown(f);
            return _buildTextField(f);
          }),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _saving
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF3CFF7E), Color(0xFF00E5B0)],
                      ),
                color: _saving ? Colors.white10 : null,
                borderRadius: BorderRadius.circular(17),
                boxShadow: _saving
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF3CFF7E).withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ENREGISTRER",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField(_Field f) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: TextField(
        controller: _ctrls[f.key],
        keyboardType: f.numeric
            ? TextInputType.number
            : f.lines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        maxLines: f.lines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.33),
            fontSize: 12,
          ),
          prefixIcon: Icon(f.icon, color: Colors.white38, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: f.lines > 1 ? 14 : 18,
          ),
        ),
      ),
    ),
  );

  Widget _buildDropdown(_Field f) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _drops[f.key] ?? f.items.first,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white38,
        ),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.33),
            fontSize: 12,
          ),
          prefixIcon: Icon(f.icon, color: Colors.white38, size: 18),
          border: InputBorder.none,
        ),
        items: List.generate(
          f.items.length,
          (i) => DropdownMenuItem(value: f.items[i], child: Text(f.labels[i])),
        ),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _drops[f.key] = v;
            if (f.key == 'sport') {
              _currentSport = v;
              _buildFields();
            }
          });
        },
      ),
    ),
  );
}

// ── Modèle champ ────────────────────────────────────────────────
class _Field {
  final String key, label;
  final IconData icon;
  final bool isDropdown, numeric;
  final int lines;
  final List<String> items, labels;
  final String def;

  const _Field(
    this.key,
    this.label,
    this.icon, {
    this.numeric = false,
    this.lines = 1,
    this.def = '',
  }) : isDropdown = false,
       items = const [],
       labels = const [];

  const _Field.drop(this.key, this.label, this.icon, this.items, this.labels)
    : isDropdown = true,
      numeric = false,
      lines = 1,
      def = '';
}

// ════════════════════════════════════════════════════════════════
// INFORMATIONS PERSONNELLES — inchangé
// ════════════════════════════════════════════════════════════════

class _PersonalInfoForm extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _PersonalInfoForm({required this.profile});
  @override
  State<_PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<_PersonalInfoForm> {
  final _supabase = Supabase.instance.client;
  late final _name = TextEditingController(
    text: widget.profile['full_name'] ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.profile['withdrawal_phone'] ?? '',
  );
  late final _dob = TextEditingController(
    text: widget.profile['birth_date'] ?? '',
  );
  late final _pin = TextEditingController(
    text: widget.profile['withdrawal_pin'] ?? '',
  );
  bool _isLocked = false;
  bool _obscurePin = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.profile['is_profile_locked'] == true;
  }

  Future<void> _save() async {
    if (_phone.text.length < 9 || _pin.text.length < 4) {
      _snack("Numéro (9 chiffres) ou PIN (4 chiffres) incomplet", ok: false);
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      // La mise à jour déclenche Realtime → ProfileScreen sync automatique
      await _supabase
          .from('users')
          .update({
            'full_name': _name.text.trim(),
            'withdrawal_phone': _phone.text.trim(),
            'birth_date': _dob.text.trim(),
            'withdrawal_pin': _pin.text.trim(),
            'is_profile_locked': true,
          })
          .eq('id', uid!);
      setState(() => _isLocked = true);
      _snack("Profil verrouillé et sauvegardé ✓");
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            m,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "INFORMATIONS PERSONNELLES",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_isLocked) _lockedBanner(),
        const SizedBox(height: 8),
        _f("Nom complet", _name, Icons.person_outline_rounded),
        _f(
          "Email",
          TextEditingController(text: _supabase.auth.currentUser?.email ?? ''),
          Icons.alternate_email_rounded,
          enabled: false,
        ),
        const SizedBox(height: 8),
        _label("COORDONNÉES DE RETRAIT"),
        const SizedBox(height: 12),
        _f(
          "Numéro Mobile Money (9 chiffres)",
          _phone,
          Icons.phone_android_rounded,
          type: TextInputType.phone,
          max: 9,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: TextField(
            controller: _pin,
            enabled: !_isLocked,
            maxLength: 4,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: _isLocked ? Colors.white24 : Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: "Code PIN de retrait (4 chiffres)",
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.33),
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white38,
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white24,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
        _f(
          "Date de naissance",
          _dob,
          Icons.cake_outlined,
          type: TextInputType.datetime,
        ),
        const SizedBox(height: 24),
        if (!_isLocked)
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3CFF7E), Color(0xFF00E5B0)],
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ENREGISTRER & VERROUILLER",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _lockedBanner() => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock_rounded, color: Colors.orangeAccent, size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            "Profil verrouillé. Contactez le support pour modifier vos coordonnées.",
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withOpacity(0.28),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.8,
    ),
  );

  Widget _f(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool enabled = true,
    TextInputType type = TextInputType.text,
    int? max,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: TextField(
      controller: ctrl,
      enabled: enabled && !_isLocked,
      keyboardType: type,
      maxLength: max,
      style: TextStyle(
        color: (enabled && !_isLocked) ? Colors.white : Colors.white24,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.33),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        border: InputBorder.none,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// SÉCURITÉ — inchangé
// ════════════════════════════════════════════════════════════════

class _SecurityForm extends StatefulWidget {
  const _SecurityForm();
  @override
  State<_SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends State<_SecurityForm> {
  final _supabase = Supabase.instance.client;
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _v1 = false, _v2 = false;

  Future<void> _changePassword() async {
    if (_new.text != _confirm.text) {
      _snack("Mots de passe différents", ok: false);
      return;
    }
    if (_new.text.length < 6) {
      _snack("6 caractères minimum", ok: false);
      return;
    }
    try {
      final data = await _supabase
          .from('users')
          .select('last_password_change')
          .eq('id', _supabase.auth.currentUser!.id)
          .single();
      final last =
          DateTime.tryParse(data['last_password_change'] ?? '') ??
          DateTime(2000);
      if (DateTime.now().difference(last).inDays < 30) {
        _snack("Changement possible une fois tous les 30 jours", ok: false);
        return;
      }
      await _supabase.auth.updateUser(UserAttributes(password: _new.text));
      await _supabase
          .from('users')
          .update({'last_password_change': DateTime.now().toIso8601String()})
          .eq('id', _supabase.auth.currentUser!.id);
      _snack("Mot de passe mis à jour ✓");
      _new.clear();
      _confirm.clear();
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    }
  }

  void _confirmDelete() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Supprimer le compte ?",
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: const Text(
        "Cette action est définitive et irréversible.",
        style: TextStyle(color: Colors.white38, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULER", style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () async {
            await _supabase.auth.admin.deleteUser(
              _supabase.auth.currentUser!.id,
            );
            if (mounted)
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
          },
          child: const Text(
            "SUPPRIMER",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  void _snack(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            m,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "MOT DE PASSE & SÉCURITÉ",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _pwField(
          "Nouveau mot de passe",
          _new,
          _v1,
          () => setState(() => _v1 = !_v1),
        ),
        _pwField(
          "Confirmer le mot de passe",
          _confirm,
          _v2,
          () => setState(() => _v2 = !_v2),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _changePassword,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3CFF7E), Color(0xFF00E5B0)],
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Center(
              child: Text(
                "CHANGER LE MOT DE PASSE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Divider(color: Colors.white.withOpacity(0.06)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _confirmDelete,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Supprimer mon compte",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Action irréversible — toutes vos données seront effacées",
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pwField(
    String label,
    TextEditingController ctrl,
    bool vis,
    VoidCallback toggle,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: TextField(
      controller: ctrl,
      obscureText: !vis,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.33),
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Colors.white38,
          size: 18,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            vis ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: Colors.white24,
            size: 18,
          ),
          onPressed: toggle,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// LANGUE — inchangé
// ════════════════════════════════════════════════════════════════

class _LanguageSettings extends StatefulWidget {
  const _LanguageSettings();
  @override
  State<_LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<_LanguageSettings> {
  String _selected = "Français";
  final _langs = [("Français", "🇫🇷"), ("English", "🇬🇧")];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "LANGUE",
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: _langs
          .map(
            (l) => GestureDetector(
              onTap: () => setState(() => _selected = l.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selected == l.$1
                      ? const Color(0xFF3CFF7E).withOpacity(0.08)
                      : const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selected == l.$1
                        ? const Color(0xFF3CFF7E).withOpacity(0.4)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Text(l.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Text(
                      l.$1,
                      style: TextStyle(
                        color: _selected == l.$1
                            ? const Color(0xFF3CFF7E)
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_selected == l.$1)
                      const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF3CFF7E),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// PAIEMENTS — inchangé
// ════════════════════════════════════════════════════════════════

class _PaymentSettings extends StatelessWidget {
  const _PaymentSettings();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "MODES DE PAIEMENT",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _pLabel("MÉTHODES ACTIVES"),
        const SizedBox(height: 10),
        _pTile(
          "MTN Mobile Money",
          "Disponible",
          Icons.phone_android_rounded,
          Colors.yellow,
          true,
        ),
        _pTile(
          "Orange Money",
          "Disponible",
          Icons.phone_android_rounded,
          Colors.orange,
          true,
        ),
        const SizedBox(height: 24),
        _pLabel("BIENTÔT DISPONIBLES"),
        const SizedBox(height: 10),
        _pTile(
          "Compte Bancaire",
          "En cours d'intégration",
          Icons.account_balance_rounded,
          Colors.white12,
          false,
        ),
        _pTile(
          "PayPal",
          "En cours d'intégration",
          Icons.credit_card_rounded,
          Colors.white12,
          false,
        ),
      ],
    ),
  );

  Widget _pLabel(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withOpacity(0.28),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.8,
    ),
  );

  Widget _pTile(
    String t,
    String sub,
    IconData icon,
    Color color,
    bool active,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active
            ? color.withOpacity(0.25)
            : Colors.white.withOpacity(0.05),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: active ? color : Colors.white12, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white24,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: active ? Colors.white38 : Colors.white12,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (active)
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF3CFF7E),
            size: 18,
          ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// SUPPORT — inchangé
// ════════════════════════════════════════════════════════════════

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint("Impossible d'ouvrir : $url");
  }
}

class _SupportScreen extends StatelessWidget {
  const _SupportScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "AIDE & SUPPORT",
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Une question ?",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Notre équipe répond dans les plus brefs délais.",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        _contactTile(
          "WhatsApp Officiel",
          "+237 656 678 841",
          Icons.chat_rounded,
          Colors.green,
          () => _launchUrl("https://wa.me/237656678841"),
        ),
        _contactTile(
          "Email Assistance",
          "fecaapp1@gmail.com",
          Icons.mail_rounded,
          Colors.blueAccent,
          () => _launchUrl(
            "mailto:fecaapp1@gmail.com?subject=Assistance FecaApp",
          ),
        ),
      ],
    ),
  );

  Widget _contactTile(
    String t,
    String sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.open_in_new_rounded,
            color: color.withOpacity(0.5),
            size: 15,
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// CGU — inchangé
// ════════════════════════════════════════════════════════════════

class _TermsScreen extends StatelessWidget {
  const _TermsScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "MENTIONS LÉGALES & CGU",
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          "Bienvenue sur FecaApp.",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Dernière révision : Février 2026",
          style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
        ),
        const SizedBox(height: 28),
        _article(
          "ARTICLE 1 — CADRE GÉNÉRAL",
          "Les présentes conditions régissent l'utilisation de FecaApp. En accédant à nos services, vous vous engagez à respecter les principes d'intégrité et de transparence de notre communauté.",
        ),
        _article(
          "ARTICLE 2 — PROTECTION DES DONNÉES",
          "La confidentialité est notre priorité. Vos informations personnelles et coordonnées de paiement sont cryptées via Supabase. Seul l'Administrateur de FecaApp dispose des droits d'accès nécessaires.",
        ),
        _article(
          "ARTICLE 3 — RESPONSABILITÉ DES UTILISATEURS",
          "Chaque utilisateur est responsable de l'exactitude des informations fournies. FecaApp se réserve le droit de suspendre tout compte présentant des données frauduleuses.",
        ),
        _article(
          "ARTICLE 4 — SYSTÈME DE PAIEMENT",
          "FecaApp s'appuie sur MTN MoMo et Orange Money. Les données de retrait saisies sont définitives et verrouillées pour votre sécurité.",
        ),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 8, bottom: 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            "Pour toute question : fecaapp1@gmail.com",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _article(String t, String c) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: const TextStyle(
            color: Color(0xFF3CFF7E),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          c,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// ÉCRANS DE CERTIFICATION — inchangés
// ════════════════════════════════════════════════════════════════

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _supabase = Supabase.instance.client;
  File? _file;
  bool _uploading = false;
  final _docType = TextEditingController();
  final _ref = TextEditingController();

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'jpeg'],
    );
    if (r != null && r.files.single.path != null)
      setState(() => _file = File(r.files.single.path!));
  }

  Future<void> _submit() async {
    if (_file == null || _docType.text.isEmpty || _ref.text.isEmpty) {
      _snack("Veuillez remplir tous les champs", ok: false);
      return;
    }
    setState(() => _uploading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final ext = _file!.path.split('.').last;
      final path =
          "${user.id}/supporters/cert_${DateTime.now().millisecondsSinceEpoch}.$ext";
      await _supabase.storage
          .from('certifications')
          .upload(path, _file!, fileOptions: const FileOptions(upsert: false));
      final url = _supabase.storage.from('certifications').getPublicUrl(path);
      await _supabase.from('certifications').insert({
        'user_id': user.id,
        'file_url': url,
        'status': 'PENDING',
        'diploma_type': _docType.text.trim(),
        'institution': _ref.text.trim(),
      });
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

  void _showSuccess() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Icon(
        Icons.access_time_filled_rounded,
        color: Colors.amber,
        size: 56,
      ),
      content: const Text(
        "Document soumis ✅\n\nVotre compte supporter sera certifié sous 30 minutes.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "D'ACCORD",
              style: TextStyle(
                color: Color(0xFF3CFF7E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "CERTIFICATION SUPPORTER",
        style: TextStyle(
          color: Colors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoBanner(
          Colors.amber,
          "Vérification d'identité. Fournissez une pièce officielle.",
        ),
        const SizedBox(height: 24),
        _fld("Type de document", _docType, Icons.badge_outlined),
        _fld("Numéro ou référence", _ref, Icons.tag_rounded),
        const SizedBox(height: 8),
        _uploadZone(Colors.amber),
        const SizedBox(height: 28),
        _submitBtn("CERTIFIER MON COMPTE", Colors.amber, _submit),
      ],
    ),
  );

  Widget _infoBanner(Color c, String t) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.withOpacity(0.06),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.verified_user_outlined, color: c, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fld(String label, TextEditingController ctrl, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.33),
              fontSize: 12,
            ),
            prefixIcon: Icon(icon, color: Colors.white38, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      );

  Widget _uploadZone(Color c) => GestureDetector(
    onTap: _pick,
    child: Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _file != null ? c : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_present_rounded,
            size: 36,
            color: _file != null ? c : Colors.white24,
          ),
          const SizedBox(height: 10),
          Text(
            _file == null
                ? 'Choisir un fichier (PDF, JPG, PNG)'
                : 'Fichier prêt ✓',
            style: TextStyle(
              color: _file != null ? c : Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _submitBtn(String label, Color c, VoidCallback onTap) =>
      GestureDetector(
        onTap: _uploading ? null : onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _uploading ? Colors.white10 : c,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _uploading
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      );
}

// ── Athlète ─────────────────────────────────────────────────────
class UploadCertScreen extends StatefulWidget {
  const UploadCertScreen({super.key});
  @override
  State<UploadCertScreen> createState() => _UploadCertScreenState();
}

class _UploadCertScreenState extends State<UploadCertScreen> {
  final _supabase = Supabase.instance.client;
  bool _uploading = false, _isMinor = false;
  File? _photo, _identity, _medical, _parentId, _parentVideo;

  Future<void> _pick(String type) async {
    final isVideo = type == 'parentVideo';
    final r = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
    );
    if (r == null || r.files.single.path == null) return;
    final f = File(r.files.single.path!);
    setState(() {
      switch (type) {
        case 'photo':
          _photo = f;
          break;
        case 'identity':
          _identity = f;
          break;
        case 'medical':
          _medical = f;
          break;
        case 'parentId':
          _parentId = f;
          break;
        case 'parentVideo':
          _parentVideo = f;
          break;
      }
    });
  }

  Future<String?> _upload(File f, String folder) async {
    try {
      final uid = _supabase.auth.currentUser!.id;
      final ext = f.path.split('.').last;
      final path = "$uid/$folder/${DateTime.now().microsecondsSinceEpoch}.$ext";
      await _supabase.storage
          .from('certifications')
          .upload(path, f, fileOptions: const FileOptions(upsert: false));
      return _supabase.storage.from('certifications').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_photo == null || _identity == null || _medical == null) {
      _snack("Photo 4x4, identité et certificat médical requis", ok: false);
      return;
    }
    if (_isMinor && (_parentId == null || _parentVideo == null)) {
      _snack("Documents parentaux requis pour les mineurs", ok: false);
      return;
    }
    setState(() => _uploading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final photoUrl = await _upload(_photo!, 'profile');
      final identityUrl = await _upload(_identity!, 'identity');
      await _upload(_medical!, 'medical');
      if (_isMinor) {
        await _upload(_parentId!, 'parental');
        await _upload(_parentVideo!, 'parental');
      }
      await _supabase.from('certifications').insert({
        'user_id': user.id,
        'file_url': identityUrl ?? '',
        'status': 'PENDING',
        'diploma_type': _isMinor ? 'ATHLETE_MINOR' : 'ATHLETE_ADULT',
        'institution': 'FECAAPP_INTERNAL',
      });
      if (photoUrl != null)
        await _supabase
            .from('users')
            .update({'img_url': photoUrl})
            .eq('id', user.id);
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

  void _showSuccess() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Icon(
        Icons.verified_user_rounded,
        color: Colors.amber,
        size: 56,
      ),
      content: const Text(
        "Dossier Athlète reçu ✅\n\nNos experts analysent vos pièces. Badge activé sous 30 minutes.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "COMPRIS",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "CERTIFICATION ATHLÈTE",
        style: TextStyle(
          color: Colors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoBanner(
          "Dossier strict pour les athlètes. Documents requis pour le scouting professionnel.",
        ),
        const SizedBox(height: 20),
        _sLabel("IDENTITÉ VISUELLE"),
        _docTile(
          "Photo 4x4 officielle",
          Icons.face_retouching_natural,
          _photo,
          () => _pick('photo'),
        ),
        _sLabel("DOCUMENTS ATHLÈTE"),
        _docTile(
          "CNI ou Acte de Naissance",
          Icons.badge_outlined,
          _identity,
          () => _pick('identity'),
        ),
        _docTile(
          "Certificat Médical (−3 mois)",
          Icons.health_and_safety_outlined,
          _medical,
          () => _pick('medical'),
        ),
        const SizedBox(height: 16),
        _minorSwitch(),
        if (_isMinor) ...[
          const SizedBox(height: 14),
          _sLabel("DOSSIER PARENTAL (MINEUR)"),
          _docTile(
            "CNI du Parent / Tuteur",
            Icons.assignment_ind_outlined,
            _parentId,
            () => _pick('parentId'),
          ),
          _docTile(
            "Vidéo de consentement parent",
            Icons.videocam_rounded,
            _parentVideo,
            () => _pick('parentVideo'),
            isVideo: true,
          ),
        ],
        const SizedBox(height: 28),
        _submitBtn("LANCER LA VÉRIFICATION PRO", Colors.amber, _submit),
        const SizedBox(height: 30),
      ],
    ),
  );

  Widget _infoBanner(String t) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.amber.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      t,
      style: TextStyle(
        color: Colors.white.withOpacity(0.28),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    ),
  );

  Widget _docTile(
    String t,
    IconData icon,
    File? f,
    VoidCallback onTap, {
    bool isVideo = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: f != null
              ? Colors.amber.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: f != null ? Colors.amber : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              f == null ? t : "Fichier sélectionné ✓",
              style: TextStyle(
                color: f != null ? Colors.amber : Colors.white70,
                fontSize: 13,
                fontWeight: f != null ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Icon(
            isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.add_a_photo_outlined,
            color: Colors.white24,
            size: 17,
          ),
        ],
      ),
    ),
  );

  Widget _minorSwitch() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            "Athlète mineur ou sans pièce d'identité ?",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Switch(
          value: _isMinor,
          activeColor: Colors.amber,
          onChanged: (v) => setState(() => _isMinor = v),
        ),
      ],
    ),
  );

  Widget _submitBtn(String label, Color c, VoidCallback onTap) =>
      GestureDetector(
        onTap: _uploading ? null : onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _uploading ? Colors.white10 : c,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _uploading
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      );
}

// ── Pro (Club / Agent / Journaliste) ────────────────────────────
class UploadCertProScreen extends StatefulWidget {
  const UploadCertProScreen({super.key});
  @override
  State<UploadCertProScreen> createState() => _UploadCertProScreenState();
}

class _UploadCertProScreenState extends State<UploadCertProScreen> {
  final _supabase = Supabase.instance.client;
  File? _file;
  bool _uploading = false;
  final _org = TextEditingController();
  final _license = TextEditingController();

  Future<void> _pickDoc() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );
    if (r != null && r.files.single.path != null)
      setState(() => _file = File(r.files.single.path!));
  }

  Future<void> _submit() async {
    if (_file == null || _org.text.isEmpty) {
      _snack("Organisation et document requis", ok: false);
      return;
    }
    setState(() => _uploading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final ext = _file!.path.split('.').last;
      final path =
          "${user.id}/pro/cert_${DateTime.now().millisecondsSinceEpoch}.$ext";
      await _supabase.storage
          .from('certifications')
          .upload(path, _file!, fileOptions: const FileOptions(upsert: false));
      final url = _supabase.storage.from('certifications').getPublicUrl(path);
      await _supabase.from('certifications').insert({
        'user_id': user.id,
        'file_url': url,
        'status': 'PENDING',
        'diploma_type': 'PRO_LICENSE',
        'institution': _org.text.trim(),
        'notes': _license.text.trim(),
      });
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      _snack("Erreur : $e", ok: false);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: ok ? const Color(0xFF3CFF7E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

  void _showSuccess() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Icon(
        Icons.access_time_filled_rounded,
        color: Colors.blueAccent,
        size: 56,
      ),
      content: const Text(
        "Dossier professionnel soumis ✅\n\nNos administrateurs vérifient vos accréditations. Accès activé sous 30 minutes.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "D'ACCORD",
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "CERTIFICATION PROFESSIONNELLE",
        style: TextStyle(
          color: Colors.blueAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Colors.blueAccent,
                size: 18,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Agents, Clubs et Journalistes doivent valider leur identité pour accéder aux outils professionnels.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _fld(
          "Nom de l'organisation / Club / Média",
          _org,
          Icons.business_outlined,
        ),
        _fld(
          "Numéro de licence / Carte de presse",
          _license,
          Icons.badge_outlined,
        ),
        const SizedBox(height: 8),
        _uploadZone(),
        const SizedBox(height: 28),
        _submitBtn(),
      ],
    ),
  );

  Widget _fld(String label, TextEditingController ctrl, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.33),
              fontSize: 12,
            ),
            prefixIcon: Icon(icon, color: Colors.blueAccent, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      );

  Widget _uploadZone() => GestureDetector(
    onTap: _pickDoc,
    child: Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _file != null
              ? Colors.blueAccent
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: _file != null ? Colors.blueAccent : Colors.white24,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            _file == null
                ? 'Joindre votre document (PDF, JPG, PNG)'
                : 'Fichier prêt : ${_file!.path.split('/').last}',
            style: TextStyle(
              color: _file != null ? Colors.blueAccent : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _submitBtn() => GestureDetector(
    onTap: _uploading ? null : _submit,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: _uploading ? Colors.white10 : Colors.blueAccent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _uploading
            ? []
            : [
                const BoxShadow(
                  color: Colors.blueAccent,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Center(
        child: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "ENVOYER POUR VALIDATION",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
      ),
    ),
  );
}
