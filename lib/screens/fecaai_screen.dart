// lib/screens/fecaai_screen.dart
//
// Page FecaAI — Design premium inspiré de la maquette
// 5 onglets : Dashboard · Entraînement · Performances · Chat IA · Profil
// Branchée sur SocialService + Supabase auth + FecaAIService

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/social_service.dart';
import '../services/fecaai_service.dart';

// ─── Couleurs FecaAI ──────────────────────────────────────────────────────────

class _C {
  static const green = Color(0xFF00A651);
  static const greenDark = Color(0xFF007A3D);
  static const greenLight = Color(0xFF00C962);
  static const orange = Color(0xFFFF6B1A);
  static const orangeLight = Color(0xFFFF8C4B);
  static const darkBg = Color(0xFF111111);
  static const cardBg = Color(0xFF1A1A1A);
  static const cardBg2 = Color(0xFF222222);
  static const border = Color(0xFF2A2A2A);
  static const gray = Color(0xFF888888);
  static const grayLight = Color(0xFFCCCCCC);
  static const white = Color(0xFFF5F5F5);
}

// ─── Modèle de message chat ───────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });
}

// ─── Écran principal ──────────────────────────────────────────────────────────

class FecaAIScreen extends StatefulWidget {
  const FecaAIScreen({super.key});

  @override
  State<FecaAIScreen> createState() => _FecaAIScreenState();
}

class _FecaAIScreenState extends State<FecaAIScreen>
    with TickerProviderStateMixin {
  // ── Services ─────────────────────────────────────────────────────────────────
  final SocialService _socialService = SocialService();

  // ── Navigation interne ───────────────────────────────────────────────────────
  int _currentTab = 0; // 0=home 1=train 2=perf 3=ai 4=profil

  // ── Profil utilisateur ───────────────────────────────────────────────────────
  String _userId = '';
  String _userName = 'Athlète';
  String _userRole = 'joueur';
  String _userSport = 'Football';
  String _userLevel = 'Amateur';
  String _userImg = '';
  bool _isInitialized = false;

  // ── Chat IA ──────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  // ── Entraînement ─────────────────────────────────────────────────────────────
  bool _trainingStarted = false;
  int _currentExercise = 0;

  // ── Performances ─────────────────────────────────────────────────────────────
  String _perfFilter = 'semaine';

  // ── Animation pulse ───────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Données exercices ─────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _exercises = [
    {
      'name': 'Échauffement dynamique',
      'sets': '1×10 min',
      'icon': '🌡️',
      'muscle': 'Global',
      'diff': 1,
    },
    {
      'name': 'Fractionné 6×100m',
      'sets': '6×100m',
      'icon': '⚡',
      'muscle': 'Jambes',
      'diff': 3,
    },
    {
      'name': 'Gainage planche',
      'sets': '3×60 sec',
      'icon': '🏋️',
      'muscle': 'Core',
      'diff': 2,
    },
    {
      'name': 'Squats sautés',
      'sets': '4×15 reps',
      'icon': '🦵',
      'muscle': 'Cuisses',
      'diff': 3,
    },
    {
      'name': 'Étirements',
      'sets': '1×10 min',
      'icon': '🧘',
      'muscle': 'Global',
      'diff': 1,
    },
  ];

  // ── Données performances ──────────────────────────────────────────────────────
  final List<int> _weekData = [42, 58, 51, 73, 65, 78, 82];
  final List<String> _weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  // ── Suggestions rapides par rôle ─────────────────────────────────────────────
  static const Map<String, List<String>> _suggestions = {
    'joueur': [
      '💪 Programme semaine',
      '🥗 Nutrition pré-match',
      '⚡ Améliorer vitesse',
      '🧘 Récupération',
    ],
    'athlète': [
      '🏃 Plan entraînement',
      '📊 Analyser mes perfs',
      '🥗 Alimentation',
      '🎯 Objectifs',
    ],
    'talent': [
      '⭐ Progresser vite',
      '🌍 Clubs qui recrutent',
      '📋 Mon profil',
      '💡 Conseils carrière',
    ],
    'supporter': [
      '⚽ Actu Lions',
      '🏆 Classement Elite One',
      '📅 Prochains matchs',
      '🔥 Débat tactique',
    ],
    'club': [
      '👥 Recrutement',
      '📋 Réglementation FECAFOOT',
      '💰 Sponsoring',
      '🎓 Formation jeunes',
    ],
    'journaliste': [
      '✍️ Idées articles',
      '📊 Stats joueur',
      '❓ Interview',
      '🔍 Vérifier info',
    ],
    'agent': [
      '🔍 Critères scouting',
      '📄 Fiche joueur',
      '⚖️ Règles transfert',
      '🌍 Clubs Afrique',
    ],
    'recruteur': [
      '🎯 Profil recherché',
      '📋 Évaluer talent',
      '💼 Contrat type',
      '🗺️ Marchés cibles',
    ],
  };

  // ── Couleur rôle ─────────────────────────────────────────────────────────────
  Color get _roleColor {
    switch (_userRole) {
      case 'supporter':
        return const Color(0xFF1565C0);
      case 'club':
        return const Color(0xFF6A1B9A);
      case 'journaliste':
        return const Color(0xFFE65100);
      case 'agent':
      case 'recruteur':
        return const Color(0xFF00695C);
      default:
        return _C.green;
    }
  }

  // ── Label rôle ───────────────────────────────────────────────────────────────
  String get _roleLabel =>
      {
        'joueur': 'Joueur',
        'athlète': 'Athlète',
        'talent': 'Talent',
        'supporter': 'Supporter',
        'club': 'Club',
        'journaliste': 'Journaliste',
        'agent': 'Agent',
        'recruteur': 'Recruteur',
      }[_userRole] ??
      'Utilisateur';

  // ── Message bienvenue ─────────────────────────────────────────────────────────
  String get _welcomeMessage =>
      {
        'joueur':
            'Salut $_userName ! 💪 Je suis FecaAI, ton coach IA. Prêt à optimiser tes performances en $_userSport ?',
        'athlète':
            'Salut $_userName ! 🏃 FecaAI à ton service. Niveau $_userLevel en $_userSport — on va travailler !',
        'talent':
            'Hey $_userName ! ⭐ Je suis FecaAI, ton mentor carrière. On construit ton avenir en $_userSport.',
        'supporter':
            'Hey $_userName ! ⚽ FecaAI, expert foot camerounais. Actu, résultats, débats — je suis là !',
        'club':
            'Bonjour $_userName ! 🏟️ FecaAI, votre consultant sportif. Quelle est votre priorité aujourd\'hui ?',
        'journaliste':
            'Bonjour $_userName ! ✍️ FecaAI, assistant rédaction. Stats, angles, interviews — je suis prêt.',
        'agent':
            'Bonjour $_userName ! 🤝 FecaAI, assistant scouting. Talents, transferts — par où commencer ?',
        'recruteur':
            'Bonjour $_userName ! 🔍 FecaAI, expert recrutement. Quel profil recherchez-vous ?',
      }[_userRole] ??
      'Bonjour $_userName ! 👋 Je suis FecaAI. Comment puis-je vous aider ?';

  List<String> get _currentSuggestions =>
      _suggestions[_userRole] ??
      ['💬 Pose une question', '🎯 Aide-moi', '📊 Mes stats', '💡 Conseils'];

  // ============================================================
  // INIT & DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Chargement profil ─────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final auth = Supabase.instance.client.auth.currentUser;
      if (auth == null) {
        setState(() => _isInitialized = true);
        return;
      }
      _userId = auth.id;
      final profile = await _socialService.getUserProfileForAI(_userId);
      setState(() {
        _userName = profile['full_name'] ?? 'Athlète';
        _userRole = (profile['role'] ?? 'joueur').toLowerCase();
        _userSport = profile['sport'] ?? 'Football';
        _userLevel = profile['level'] ?? 'Amateur';
        _userImg = profile['img_url'] ?? '';
        _isInitialized = true;
      });
      await _loadChatHistory();
      if (_messages.isEmpty) _addWelcome();
    } catch (e) {
      setState(() => _isInitialized = true);
      _addWelcome();
    }
  }

  Future<void> _loadChatHistory() async {
    if (_userId.isEmpty) return;
    final history = await _socialService.getAIConversationHistory(
      userId: _userId,
      limit: 20,
    );
    for (final msg in history) {
      _messages.add(
        ChatMessage(
          text: msg['content'] ?? '',
          isUser: msg['role'] == 'user',
          timestamp: DateTime.now(),
        ),
      );
      _conversationHistory.add({
        'role': msg['role'] ?? 'user',
        'content': msg['content'] ?? '',
      });
    }
    if (mounted) setState(() {});
  }

  void _addWelcome() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: _welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  // ── Envoi message ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;
    final msg = text.trim();
    _chatController.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(
        ChatMessage(text: msg, isUser: true, timestamp: DateTime.now()),
      );
      _isChatLoading = true;
      _messages.add(
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          isLoading: true,
        ),
      );
    });
    _scrollChat();

    if (_userId.isNotEmpty) {
      await _socialService.saveAIMessage(
        userId: _userId,
        role: 'user',
        content: msg,
      );
    }
    _conversationHistory.add({'role': 'user', 'content': msg});

    try {
      final ctx = List<Map<String, String>>.from(
        _conversationHistory.length > 10
            ? _conversationHistory.sublist(_conversationHistory.length - 10)
            : _conversationHistory,
      );
      if (ctx.isNotEmpty &&
          ctx.last['role'] == 'user' &&
          ctx.last['content'] == msg) {
        ctx.removeLast();
      }

      final response = await FecaAIService.sendMessage(
        userMessage: msg,
        userRole: _userRole,
        userName: _userName,
        userSport: _userSport,
        userLevel: _userLevel,
        conversationHistory: ctx,
      );

      _conversationHistory.add({'role': 'model', 'content': response});
      if (_userId.isNotEmpty) {
        await _socialService.saveAIMessage(
          userId: _userId,
          role: 'model',
          content: response,
        );
      }

      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
        );
        _isChatLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            text: 'Une erreur est survenue. Réessaie. 🔧',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isChatLoading = false;
      });
    }
    _scrollChat();
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _resetChat() async {
    if (_userId.isNotEmpty) {
      await _socialService.clearAIConversationHistory(_userId);
    }
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
    });
    _addWelcome();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.darkBg,
      body: !_isInitialized
          ? _buildLoader()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(child: _buildCurrentTab()),
                  _buildBottomNav(),
                ],
              ),
            ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildTraining();
      case 2:
        return _buildPerformances();
      case 3:
        return _buildChat();
      case 4:
        return _buildProfil();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildBottomNav() {
    final tabs = [
      {'icon': '⚡', 'label': 'Accueil'},
      {'icon': '🏋️', 'label': 'Entraîn.'},
      {'icon': '📊', 'label': 'Perfs'},
      {'icon': '🤖', 'label': 'FecaAI'},
      {'icon': '👤', 'label': 'Profil'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _currentTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i]['icon']!,
                      style: TextStyle(
                        fontSize: 20,
                        color: isActive ? null : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[i]['label']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? _C.green : _C.gray,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    if (isActive)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.green,
                          boxShadow: [
                            BoxShadow(
                              color: _C.green.withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // ONGLET 0 — DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour 👋',
                            style: TextStyle(
                              fontSize: 12,
                              color: _C.gray,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _C.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_C.green, _C.greenDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: _C.greenLight, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _C.green.withOpacity(0.4),
                            blurRadius: 16,
                          ),
                        ],
                        image: _userImg.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_userImg),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _userImg.isEmpty
                          ? const Center(
                              child: Text('🦁', style: TextStyle(fontSize: 22)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),

              // Score hero card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [_C.greenDark, _C.green, _C.greenLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCORE DU JOUR',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '78',
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const Text(
                            '%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: 0.78,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_userRole • $_userSport • $_userLevel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        '🔥',
                        'Séances',
                        '12',
                        'ce mois',
                        '+3',
                        _C.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        '⚡',
                        'Vitesse',
                        '24.3',
                        'km/h',
                        '+0.8',
                        _C.orange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // FecaAI conseil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _C.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border(
                      left: BorderSide(color: _roleColor, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_roleColor, _C.greenDark],
                              ),
                            ),
                            child: const Center(
                              child: Text('🤖', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'FECAAI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _roleColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bonne récupération détectée. Aujourd\'hui : fractionné 6×100m + hydratation au bissap. 💪',
                        style: TextStyle(
                          fontSize: 13,
                          color: _C.grayLight,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CTA entraînement
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => setState(() => _currentTab = 1),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [_C.orange, _C.orangeLight],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.orange.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      '▶  DÉMARRER LA SÉANCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String icon,
    String label,
    String value,
    String unit,
    String delta,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  delta,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _C.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text('$label ', style: TextStyle(fontSize: 12, color: _C.gray)),
        ],
      ),
    );
  }

  // ============================================================
  // ONGLET 1 — ENTRAÎNEMENT
  // ============================================================

  Widget _buildTraining() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aujourd\'hui',
                    style: TextStyle(
                      fontSize: 11,
                      color: _C.gray,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Séance Sprint',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _C.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _C.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '~55 min',
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Barre progression
        if (_trainingStarted)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exercice ${_currentExercise + 1}/${_exercises.length}',
                      style: TextStyle(fontSize: 12, color: _C.gray),
                    ),
                    Text(
                      '${((_currentExercise / _exercises.length) * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: _C.green),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _currentExercise / _exercises.length,
                    backgroundColor: _C.border,
                    valueColor: AlwaysStoppedAnimation<Color>(_C.green),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

        // Liste exercices
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              ..._exercises.asMap().entries.map((e) {
                final i = e.key;
                final ex = e.value;
                final isActive = _trainingStarted && i == _currentExercise;
                final isDone = _trainingStarted && i < _currentExercise;
                return GestureDetector(
                  onTap: () => _trainingStarted
                      ? setState(() => _currentExercise = i)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive ? _C.green.withOpacity(0.12) : _C.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? _C.green : _C.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isDone
                                ? _C.green.withOpacity(0.2)
                                : isActive
                                ? _C.green
                                : Colors.white.withOpacity(0.05),
                          ),
                          child: Center(
                            child: Text(
                              isDone ? '✅' : ex['icon'] as String,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDone ? _C.gray : _C.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ex['sets']} • ${ex['muscle']}',
                                style: TextStyle(fontSize: 12, color: _C.gray),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(
                            3,
                            (d) => Container(
                              margin: const EdgeInsets.only(left: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d < (ex['diff'] as int)
                                    ? _C.orange
                                    : _C.border,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Bouton démarrer
              GestureDetector(
                onTap: () => setState(() {
                  _trainingStarted = !_trainingStarted;
                  if (!_trainingStarted) _currentExercise = 0;
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: _trainingStarted
                        ? null
                        : const LinearGradient(
                            colors: [_C.green, _C.greenDark],
                          ),
                    color: _trainingStarted ? _C.cardBg2 : null,
                    border: _trainingStarted
                        ? Border.all(color: _C.border)
                        : null,
                  ),
                  child: Text(
                    _trainingStarted ? '⏸  PAUSE' : '▶  DÉMARRER',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ONGLET 2 — PERFORMANCES
  // ============================================================

  Widget _buildPerformances() {
    final maxVal = _weekData.reduce((a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      children: [
        Text(
          'Analyse',
          style: TextStyle(fontSize: 11, color: _C.gray, letterSpacing: 2),
        ),
        const Text(
          'Performances',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _C.white,
          ),
        ),
        const SizedBox(height: 20),

        // Filtre
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _C.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: ['jour', 'semaine', 'mois'].map((f) {
              final isActive = _perfFilter == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _perfFilter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? _C.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive ? Colors.white : _C.gray,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Graphique barres
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score global — cette semaine',
                style: TextStyle(fontSize: 12, color: _C.gray),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weekData.asMap().entries.map((e) {
                    final i = e.key;
                    final v = e.value;
                    final isMax = v == maxVal;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$v',
                            style: TextStyle(fontSize: 9, color: _C.gray),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Container(
                              height: (v / maxVal) * 70,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: LinearGradient(
                                  colors: isMax
                                      ? [_C.greenLight, _C.green]
                                      : [
                                          _C.green.withOpacity(0.6),
                                          _C.green.withOpacity(0.3),
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _weekDays[i],
                            style: TextStyle(fontSize: 10, color: _C.gray),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats grille
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard('⚡', 'Vitesse max', '24.3', 'km/h', '+0.8', _C.green),
            _statCard('❤️', 'Endurance', '87', '%', '+5%', _C.orange),
            _statCard('💪', 'Force', '92', 'kg', '+2', _C.green),
            _statCard('📅', 'Séances', '12', '/ mois', 'Bon', _C.orange),
          ],
        ),
        const SizedBox(height: 16),

        // Analyse IA
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.greenDark.withOpacity(0.3), _C.cardBg],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🤖 ANALYSE FECAAI',
                style: TextStyle(
                  fontSize: 11,
                  color: _C.green,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ta vitesse progresse de +3.4% cette semaine. Maintiens le fractionné et augmente l\'hydratation les jours de compétition.',
                style: TextStyle(
                  fontSize: 13,
                  color: _C.grayLight,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ONGLET 3 — CHAT IA
  // ============================================================

  Widget _buildChat() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          color: const Color(0xFF0A0A0A),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _isChatLoading ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_roleColor, _roleColor.withOpacity(0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _roleColor.withOpacity(0.4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FecaAI',
                      style: TextStyle(
                        color: _C.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isChatLoading ? _C.orange : _C.green,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isChatLoading
                              ? 'En train de répondre...'
                              : 'En ligne',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isChatLoading ? _C.orange : _C.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge rôle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _roleColor.withOpacity(0.35)),
                ),
                child: Text(
                  _roleLabel,
                  style: TextStyle(
                    color: _roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isChatLoading ? null : _resetChat,
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white38,
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (context, i) => _buildBubble(_messages[i]),
          ),
        ),

        // Suggestions (si conversation vide)
        if (_messages.length <= 1) _buildSuggestions(),

        // Input
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.of(context).padding.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border(top: BorderSide(color: _C.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _C.border),
                  ),
                  child: TextField(
                    controller: _chatController,
                    enabled: !_isChatLoading,
                    style: const TextStyle(color: _C.white, fontSize: 15),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isChatLoading
                          ? 'FecaAI répond...'
                          : 'Écris ton message...',
                      hintStyle: const TextStyle(
                        color: Colors.white30,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isChatLoading
                    ? null
                    : () => _sendMessage(_chatController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isChatLoading
                        ? null
                        : LinearGradient(
                            colors: [_roleColor, _roleColor.withOpacity(0.7)],
                          ),
                    color: _isChatLoading ? Colors.white10 : null,
                    boxShadow: _isChatLoading
                        ? null
                        : [
                            BoxShadow(
                              color: _roleColor.withOpacity(0.4),
                              blurRadius: 14,
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _isChatLoading ? Colors.white24 : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _aiAvatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: _C.cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => _TypingDot(delay: Duration(milliseconds: i * 200)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[_aiAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser ? _C.orange : _C.cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: msg.isUser ? null : Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                    color: (msg.isUser ? _C.orange : Colors.black).withOpacity(
                      0.2,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: _C.white,
                  fontSize: 14,
                  height: 1.58,
                ),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _aiAvatar() => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [_roleColor, _roleColor.withOpacity(0.7)],
      ),
    ),
    child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
  );

  Widget _buildSuggestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions rapides',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentSuggestions
                .map(
                  (s) => GestureDetector(
                    onTap: () => _sendMessage(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _roleColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          color: _roleColor.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ============================================================
  // ONGLET 4 — PROFIL
  // ============================================================

  Widget _buildProfil() {
    return ListView(
      children: [
        // Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.greenDark, _C.darkBg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_C.orange, _C.orangeLight],
                  ),
                  border: Border.all(color: Colors.white12, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _C.orange.withOpacity(0.4),
                      blurRadius: 24,
                    ),
                  ],
                  image: _userImg.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_userImg),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _userImg.isEmpty
                    ? const Center(
                        child: Text('🦁', style: TextStyle(fontSize: 38)),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _C.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userRole.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: _roleColor,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _C.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Actif ce mois',
                      style: TextStyle(fontSize: 12, color: _C.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats grille
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2,
                children: [
                  _profilStat('🏆', _roleLabel, 'Rôle'),
                  _profilStat('🏃', _userSport, 'Sport'),
                  _profilStat('📅', '47 total', 'Séances'),
                  _profilStat('📍', 'Cameroun 🇨🇲', 'Pays'),
                ],
              ),
              const SizedBox(height: 20),

              // Objectifs
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _C.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Objectifs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[
                      'Passer sous 11s au 100m',
                      'Améliorer endurance (+20%)',
                      'Séances régulières (5/sem.)',
                    ].asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: e.key == 0 ? _C.green : _C.border,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 13,
                                color: e.key == 0 ? _C.white : _C.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bouton modifier
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.green),
                  ),
                  child: Text(
                    '✏️  MODIFIER LE PROFIL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _C.green,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profilStat(String icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: TextStyle(fontSize: 11, color: _C.gray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loader initial ────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.green.withOpacity(0.12),
              border: Border.all(color: _C.green.withOpacity(0.35), width: 2),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widget : points d'animation typing ──────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final Duration delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
