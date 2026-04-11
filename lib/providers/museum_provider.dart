import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MuseumProvider with ChangeNotifier {
  // Instance du client Supabase
  final _supabase = Supabase.instance.client;

  List<dynamic> _legends = [];
  List<dynamic> _videos = [];
  List<dynamic> _quizQuestions = [];
  Map<String, dynamic>? _userProgress;
  bool _isLoading = false;

  // --- GETTERS ---
  List<dynamic> get legends => _legends;
  List<dynamic> get videos => _videos;
  List<dynamic> get quizQuestions => _quizQuestions;
  bool get isLoading => _isLoading;

  // Récupère l'ID de l'utilisateur actuellement connecté à Supabase
  String get currentUserId => _supabase.auth.currentUser?.id ?? "";

  // Grade actuel du Lion (mappé sur badge_type de ton SQL)
  String get userBadge {
    if (_userProgress == null) return "LIONCEAU";
    return _userProgress!['badge_type'] ?? "LIONCEAU";
  }

  // Nombre de paliers franchis (current_session - 1)
  int get completedSessions {
    if (_userProgress == null) return 0;
    int current = _userProgress!['current_session'] ?? 1;
    return (current > 0) ? current - 1 : 0;
  }

  // Prochaine séance à jouer
  int get nextSessionNumber {
    if (_userProgress == null) return 1;
    return _userProgress!['current_session'] ?? 1;
  }

  // --- MÉTHODES ---

  // 1. CHARGEMENT GLOBAL (Légendes + Vidéos + Progrès Quiz)
  Future<void> fetchMuseumData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = currentUserId;

      // Exécution en parallèle pour plus de performance
      final results = await Future.wait([
        _supabase.from('legends').select().order('name', ascending: true),
        _supabase
            .from('museum_videos')
            .select()
            .order('created_at', ascending: false),
        if (userId.isNotEmpty)
          _supabase
              .from('user_quiz_progress')
              .select()
              .eq('user_id', userId)
              .maybeSingle(),
      ]);

      _legends = results[0] as List<dynamic>;
      _videos = results[1] as List<dynamic>;

      if (userId.isNotEmpty) {
        _userProgress = results[2] as Map<String, dynamic>?;
      }

      // Une fois les données globales chargées, on pré-charge les questions du prochain quiz
      await fetchQuizQuestions(nextSessionNumber);
    } catch (e) {
      debugPrint("🦁 Erreur Supabase Museum (fetch): $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. RÉCUPÉRER LES QUESTIONS D'UNE SÉANCE
  Future<void> fetchQuizQuestions(int sessionNumber) async {
    try {
      final response = await _supabase
          .from('quiz_questions')
          .select()
          .eq('session_number', sessionNumber);

      _quizQuestions = response as List<dynamic>;
      notifyListeners();
    } catch (e) {
      debugPrint("🦁 Erreur Supabase Quiz Questions: $e");
    }
  }

  // 3. VALIDER UNE SÉANCE ET SAUVEGARDER DANS SUPABASE
  Future<bool> validateQuizSession({
    required String userId,
    required int sessionCompleted,
    required String badgeName,
  }) async {
    try {
      final nextSession = sessionCompleted + 1;

      // Utilisation de .upsert pour créer ou mettre à jour le progrès
      final response = await _supabase
          .from('user_quiz_progress')
          .upsert({
            'user_id': userId,
            'current_session': nextSession,
            'badge_type': badgeName,
            'last_success_date': DateTime.now().toIso8601String(),
            // Déblocage automatique (exemple: immédiatement ou +24h)
            'unlocked_until': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _userProgress = response;

      // Rafraîchir les questions pour la session suivante
      await fetchQuizQuestions(nextSession);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur Validation Quiz (Supabase): $e");
    }
    return false;
  }

  // 4. LOGIQUE DE TEMPORISATION
  bool canPlayNextSession() {
    if (_userProgress == null || _userProgress!['unlocked_until'] == null) {
      return true;
    }

    try {
      DateTime expiry = DateTime.parse(_userProgress!['unlocked_until']);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true;
    }
  }
}
