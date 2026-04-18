// lib/screens/fecaai_screen.dart
//
// Page FecaAI — Intégration Drawer HomeScreen
// Branchée sur SocialService + Supabase auth
//
// Dans ton Drawer :
//   ListTile(
//     leading: const Text('🤖', style: TextStyle(fontSize: 22)),
//     title: const Text('FecaAI'),
//     onTap: () {
//       Navigator.pop(context);
//       Navigator.push(context,
//         MaterialPageRoute(builder: (_) => const FecaAIScreen()));
//     },
//   )

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/social_service.dart';
import '../services/fecaai_service.dart';

// ─── Modèle de message ────────────────────────────────────────────────────────

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
  // ── Services ────────────────────────────────────────────────────────────────
  final SocialService _socialService = SocialService();

  // ── Controllers ─────────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── État général ─────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isLoadingProfile = true;
  String? _initError;

  // ── Profil utilisateur (chargé depuis Supabase via SocialService) ────────────
  String _userId = '';
  String _userName = 'Athlète';
  String _userRole = 'joueur';
  String _userSport = 'Football';
  String _userLevel = 'Amateur';
  String _userImgUrl = '';

  // ── Animation pulse (logo IA) ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ─── Suggestions rapides par rôle ────────────────────────────────────────────
  static const Map<String, List<String>> _quickSuggestions = {
    'joueur': [
      '💪 Programme de la semaine',
      '🥗 Nutrition pré-match',
      '⚡ Améliorer ma vitesse',
      '🧘 Récupération rapide',
    ],
    'athlète': [
      '🏃 Plan d\'entraînement',
      '📊 Analyser mes perfs',
      '🥗 Alimentation sportive',
      '🎯 Objectifs de la semaine',
    ],
    'talent': [
      '⭐ Progresser rapidement',
      '🌍 Clubs qui recrutent',
      '📋 Construire mon profil',
      '💡 Conseils de carrière',
    ],
    'supporter': [
      '⚽ Actu Lions Indomptables',
      '🏆 Classement Elite One',
      '📅 Prochains matchs',
      '🔥 Débat tactique',
    ],
    'club': [
      '👥 Stratégie de recrutement',
      '📋 Réglementation FECAFOOT',
      '💰 Plan sponsoring',
      '🎓 Formation des jeunes',
    ],
    'journaliste': [
      '✍️ Idées d\'articles',
      '📊 Stats d\'un joueur',
      '❓ Préparer une interview',
      '🔍 Vérifier une information',
    ],
    'agent': [
      '🔍 Critères de scouting',
      '📄 Rédiger une fiche joueur',
      '⚖️ Règles de transfert FIFA',
      '🌍 Clubs partenaires Afrique',
    ],
    'recruteur': [
      '🎯 Définir un profil recherché',
      '📋 Évaluer un talent',
      '💼 Structure d\'un contrat',
      '🗺️ Marchés cibles Afrique',
    ],
  };

  // ─── Couleur accent selon le rôle ────────────────────────────────────────────
  Color get _roleAccentColor {
    switch (_userRole) {
      case 'supporter':
        return const Color(0xFF1565C0); // Bleu
      case 'club':
        return const Color(0xFF6A1B9A); // Violet
      case 'journaliste':
        return const Color(0xFFE65100); // Orange foncé
      case 'agent':
      case 'recruteur':
        return const Color(0xFF00695C); // Vert teal
      default:
        return const Color(0xFF00A651); // Vert FecaApp
    }
  }

  // ─── Label rôle affiché ───────────────────────────────────────────────────────
  String get _roleLabel {
    const labels = {
      'joueur': 'Joueur',
      'athlète': 'Athlète',
      'talent': 'Talent',
      'supporter': 'Supporter',
      'club': 'Club',
      'journaliste': 'Journaliste',
      'agent': 'Agent',
      'recruteur': 'Recruteur',
    };
    return labels[_userRole] ?? 'Utilisateur';
  }

  // ─── Icône rôle ───────────────────────────────────────────────────────────────
  String get _roleIcon {
    const icons = {
      'joueur': '⚽',
      'athlète': '🏃',
      'talent': '⭐',
      'supporter': '🔥',
      'club': '🏟️',
      'journaliste': '✍️',
      'agent': '🤝',
      'recruteur': '🔍',
    };
    return icons[_userRole] ?? '👤';
  }

  // ─── Suggestions du rôle actuel ───────────────────────────────────────────────
  List<String> get _currentSuggestions {
    return _quickSuggestions[_userRole] ??
        [
          '💬 Pose une question',
          '🎯 Aide-moi à progresser',
          '📊 Analyser mes données',
          '💡 Donne-moi des conseils',
        ];
  }

  // ─── Message de bienvenue personnalisé par rôle ───────────────────────────────
  String get _welcomeMessage {
    final Map<String, String> messages = {
      'joueur':
          'Salut $_userName ! 💪 Je suis FecaAI, ton coach IA personnel. '
          'Je vois que tu pratiques $_userSport au niveau $_userLevel. '
          'Prêt à optimiser tes performances ? Pose ta question ou choisis une suggestion !',
      'athlète':
          'Salut $_userName ! 🏃 Je suis FecaAI, ton assistant performance. '
          'Niveau $_userLevel en $_userSport — on a du travail pour atteindre le sommet. '
          'Par où on commence ?',
      'talent':
          'Hey $_userName ! ⭐ Je suis FecaAI. '
          'En tant que talent en $_userSport, je suis là pour t\'aider à construire ta carrière. '
          'Qu\'est-ce qu\'on travaille aujourd\'hui ?',
      'supporter':
          'Hey $_userName ! ⚽ Je suis FecaAI, ton expert du foot camerounais. '
          'Actu des Lions, résultats, débats tactiques… je suis là ! '
          'De quoi veux-tu parler ?',
      'club':
          'Bonjour $_userName ! 🏟️ Je suis FecaAI, votre consultant sportif. '
          'Je suis là pour vous accompagner dans la gestion et le développement de votre club. '
          'Quelle est votre priorité aujourd\'hui ?',
      'journaliste':
          'Bonjour $_userName ! ✍️ Je suis FecaAI, votre assistant rédaction. '
          'Stats, angles éditoriaux, préparation d\'interviews, vérification de faits… '
          'Comment puis-je vous aider ?',
      'agent':
          'Bonjour $_userName ! 🤝 Je suis FecaAI, votre assistant scouting. '
          'Identification de talents, transferts, gestion de carrière… '
          'Par où souhaitez-vous commencer ?',
      'recruteur':
          'Bonjour $_userName ! 🔍 Je suis FecaAI, votre expert recrutement. '
          'Dites-moi le profil que vous recherchez et je vous aide à structurer votre démarche.',
    };
    return messages[_userRole] ??
        'Bonjour $_userName ! 👋 Je suis FecaAI. Comment puis-je vous aider aujourd\'hui ?';
  }

  // ============================================================
  // INIT & DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Animation pulse pour le logo IA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Chargement du profil utilisateur
    _initializeScreen();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGEMENT PROFIL UTILISATEUR (SUPABASE → SOCIALSERVICE)
  // ============================================================

  Future<void> _initializeScreen() async {
    try {
      // Récupération de l'utilisateur connecté via Supabase Auth
      final authUser = Supabase.instance.client.auth.currentUser;

      if (authUser == null) {
        setState(() {
          _initError = 'Utilisateur non connecté.';
          _isLoadingProfile = false;
          _isInitialized = true;
        });
        return;
      }

      _userId = authUser.id;

      // Appel à SocialService.getUserProfileForAI()
      // qui lit full_name, role, img_url, sport, level depuis la table 'users'
      final profile = await _socialService.getUserProfileForAI(_userId);

      setState(() {
        _userName = profile['full_name'] ?? 'Athlète';
        _userRole = (profile['role'] ?? 'joueur').toLowerCase();
        _userSport = profile['sport'] ?? 'Football';
        _userLevel = profile['level'] ?? 'Amateur';
        _userImgUrl = profile['img_url'] ?? '';
        _isLoadingProfile = false;
      });

      // Chargement de l'historique de conversation depuis Supabase
      await _loadConversationHistory();

      // Si pas d'historique → message de bienvenue
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('🦁 Erreur _initializeScreen FecaAI: $e');
      setState(() {
        _initError = 'Erreur de chargement. Réessaie.';
        _isLoadingProfile = false;
        _isInitialized = true;
      });
      _addWelcomeMessage();
    }
  }

  // ─── Chargement historique depuis Supabase ────────────────────────────────

  Future<void> _loadConversationHistory() async {
    if (_userId.isEmpty) return;

    // Récupère les 20 derniers messages via SocialService
    final history = await _socialService.getAIConversationHistory(
      userId: _userId,
      limit: 20,
    );

    if (history.isEmpty) return;

    // Reconstruction de l'affichage UI depuis l'historique
    for (final msg in history) {
      final isUser = msg['role'] == 'user';
      _messages.add(
        ChatMessage(
          text: msg['content'] ?? '',
          isUser: isUser,
          timestamp: DateTime.now(),
        ),
      );
      // Reconstruction du contexte Gemini
      _conversationHistory.add({
        'role': msg['role'] ?? 'user',
        'content': msg['content'] ?? '',
      });
    }

    setState(() {});
    _scrollToBottom();
  }

  // ─── Message de bienvenue ─────────────────────────────────────────────────

  void _addWelcomeMessage() {
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

  // ============================================================
  // ENVOI DE MESSAGE
  // ============================================================

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMessage = text.trim();
    _inputController.clear();

    // Affichage immédiat du message utilisateur
    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      // Bulle de chargement temporaire
      _messages.add(
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          isLoading: true,
        ),
      );
    });

    _scrollToBottom();

    // Sauvegarde du message utilisateur dans Supabase
    if (_userId.isNotEmpty) {
      await _socialService.saveAIMessage(
        userId: _userId,
        role: 'user',
        content: userMessage,
      );
    }

    // Ajout à l'historique contexte Gemini
    _conversationHistory.add({'role': 'user', 'content': userMessage});

    try {
      // Contexte limité aux 10 derniers échanges pour Gemini
      final contextHistory = _conversationHistory.length > 10
          ? _conversationHistory.sublist(_conversationHistory.length - 10)
          : List<Map<String, String>>.from(_conversationHistory);

      // Retire le dernier message (le message actuel) pour éviter le doublon
      // dans l'historique envoyé à Gemini — il est passé via userMessage
      if (contextHistory.isNotEmpty &&
          contextHistory.last['role'] == 'user' &&
          contextHistory.last['content'] == userMessage) {
        contextHistory.removeLast();
      }

      // Appel Gemini via FecaAIService
      final response = await FecaAIService.sendMessage(
        userMessage: userMessage,
        userRole: _userRole,
        userName: _userName,
        userSport: _userSport,
        userLevel: _userLevel,
        conversationHistory: contextHistory,
      );

      // Ajout de la réponse IA à l'historique contexte
      _conversationHistory.add({'role': 'model', 'content': response});

      // Sauvegarde de la réponse IA dans Supabase
      if (_userId.isNotEmpty) {
        await _socialService.saveAIMessage(
          userId: _userId,
          role: 'model',
          content: response,
        );
      }

      // Mise à jour UI : retire bulle loading, affiche réponse
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
        );
        _isLoading = false;
      });
    } catch (e) {
      print('🦁 Erreur _sendMessage FecaAI: $e');
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            text:
                'Une erreur est survenue. Vérifie ta connexion et réessaie. 🔧',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  // ─── Reset conversation ───────────────────────────────────────────────────

  Future<void> _resetConversation() async {
    // Efface l'historique Supabase via SocialService
    if (_userId.isNotEmpty) {
      await _socialService.clearAIConversationHistory(_userId);
    }

    setState(() {
      _messages.clear();
      _conversationHistory.clear();
    });

    // Réaffiche le message de bienvenue
    _addWelcomeMessage();
  }

  // ─── Scroll to bottom ────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: _buildAppBar(),
      body: !_isInitialized
          ? _buildLoadingState()
          : _initError != null && _messages.isEmpty
          ? _buildErrorState()
          : Column(
              children: [
                _buildRoleBadge(),
                Expanded(child: _buildMessagesList()),
                // Suggestions uniquement au démarrage (1 message = welcome)
                if (_messages.length <= 1) _buildQuickSuggestions(),
                _buildInputBar(),
              ],
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Logo IA animé (pulse quand IA répond)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _isLoading ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _roleAccentColor,
                      _roleAccentColor.withOpacity(0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _roleAccentColor.withOpacity(0.45),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FecaAI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  // Point d'état (vert = en ligne, orange = en train de répondre)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLoading
                          ? Colors.orange
                          : const Color(0xFF00A651),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isLoading
                        ? 'En train de répondre...'
                        : _isLoadingProfile
                        ? 'Chargement...'
                        : 'En ligne',
                    style: TextStyle(
                      color: _isLoading
                          ? Colors.orange
                          : const Color(0xFF00A651),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Bouton reset → efface l'historique Supabase + UI
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white38,
            size: 22,
          ),
          onPressed: _isLoading ? null : _resetConversation,
          tooltip: 'Nouvelle conversation',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Badge rôle + infos utilisateur ───────────────────────────────────────

  Widget _buildRoleBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          // Avatar utilisateur (img_url depuis Supabase ou icône rôle)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _roleAccentColor.withOpacity(0.2),
              border: Border.all(
                color: _roleAccentColor.withOpacity(0.4),
                width: 1.5,
              ),
              image: _userImgUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_userImgUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _userImgUrl.isEmpty
                ? Center(
                    child: Text(
                      _roleIcon,
                      style: const TextStyle(fontSize: 15),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Badge rôle coloré
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleAccentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _roleAccentColor.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Text(
              _roleLabel,
              style: TextStyle(
                color: _roleAccentColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sport de l'utilisateur
          Text(
            '• $_userSport',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),

          const Spacer(),

          // Nom de l'utilisateur (depuis la table users)
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Liste des messages ────────────────────────────────────────────────────

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isLoading) return _buildLoadingBubble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar IA côté gauche
          if (!msg.isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _roleAccentColor,
                    _roleAccentColor.withOpacity(0.65),
                  ],
                ),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bulle de message
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Orange utilisateur / dark IA
                color: msg.isUser
                    ? const Color(0xFFFF6B1A)
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: Colors.white.withOpacity(0.07),
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (msg.isUser ? const Color(0xFFFF6B1A) : Colors.black)
                        .withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.58,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Bulle de chargement animée (3 points en vague) ───────────────────────

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_roleAccentColor, _roleAccentColor.withOpacity(0.65)],
              ),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
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

  // ── Suggestions rapides ───────────────────────────────────────────────────

  Widget _buildQuickSuggestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
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
            children: _currentSuggestions.map((suggestion) {
              return GestureDetector(
                onTap: () => _sendMessage(suggestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _roleAccentColor.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _roleAccentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: _roleAccentColor.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Barre de saisie ───────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Champ de saisie multi-lignes
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isLoading && _isInitialized,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _isLoading
                      ? 'FecaAI répond...'
                      : 'Écris ton message...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) => _sendMessage(value),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Bouton envoyer
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => _sendMessage(_inputController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isLoading
                    ? null
                    : LinearGradient(
                        colors: [
                          _roleAccentColor,
                          _roleAccentColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isLoading ? Colors.white10 : null,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: _roleAccentColor.withOpacity(0.4),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isLoading ? Colors.white24 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── État de chargement initial (pendant _initializeScreen) ───────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00A651).withOpacity(0.12),
                  border: Border.all(
                    color: const Color(0xFF00A651).withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'FecaAI se prépare...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chargement de ton profil',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── État d'erreur ─────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              _initError ?? 'Une erreur est survenue.',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isInitialized = false;
                  _initError = null;
                });
                _initializeScreen();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A651).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00A651).withOpacity(0.4),
                  ),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Color(0xFF00A651),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget : points d'animation "en train d'écrire" ─────────────────────────

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
    // Décalage pour l'effet "vague" entre les 3 points
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
