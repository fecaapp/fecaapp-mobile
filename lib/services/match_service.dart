import 'package:supabase_flutter/supabase_flutter.dart';

class MatchService {
  final _supabase = Supabase.instance.client;

  // 1. ÉCOUTER UN MATCH EN TEMPS RÉEL (FLUTTER STREAM)
  // Idéal pour l'écran de détails du match (Score, Chrono, Stats)
  Stream<Map<String, dynamic>> watchMatch(String matchId) {
    return _supabase
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((data) => data.first);
  }

  // 2. ÉCOUTER TOUS LES MATCHS D'UNE LIGUE
  Stream<List<Map<String, dynamic>>> watchMatchesByLeague(String leagueId) {
    return _supabase
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('league_id', leagueId)
        .order('start_time', ascending: false);
  }

  // 3. RÉCUPÉRER LES ÉVÉNEMENTS (BUTS, CARTONS)
  // On écoute la table events pour mettre à jour la timeline automatiquement
  Stream<List<Map<String, dynamic>>> watchEvents(String matchId) {
    return _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at', ascending: false);
  }

  // 4. RÉCUPÉRER LE CLASSEMENT (STANDINGS - FOOTBALL)
  Stream<List<Map<String, dynamic>>> watchStandings(String leagueId) {
    return _supabase
        .from('standings')
        .stream(primaryKey: ['id'])
        .eq('league_id', leagueId)
        .order('points', ascending: false)
        .order('goal_diff', ascending: false);
  }

  // --- AJOUT POUR LE BASKET (NOUVEAU) ---
  // 4b. RÉCUPÉRER LE CLASSEMENT BASKETBALL (NORME FIBA/NBA)
  Stream<List<Map<String, dynamic>>> watchBasketballStandings(String leagueId) {
    return _supabase
        .from('basketball_standings')
        .stream(primaryKey: ['id'])
        .eq('league_id', leagueId)
        .order('points', ascending: false) // 2 pts victoire / 1 pt défaite
        .order('points_for', ascending: false); // Différence en cas d'égalité
  }

  // --- AJOUT POUR LE HANDBALL (NOUVEAU) ---
  // 4c. RÉCUPÉRER LE CLASSEMENT HANDBALL (NORME IHF)
  Stream<List<Map<String, dynamic>>> watchHandballStandings(String leagueId) {
    return _supabase
        .from('handball_standings')
        .stream(primaryKey: ['id'])
        .eq('league_id', leagueId)
        .order(
          'points',
          ascending: false,
        ) // 2 pts victoire / 1 pt nul / 0 pt défaite
        .order('goal_diff', ascending: false); // Différence de buts
  }

  // 5. MISE À JOUR LIVE (Si tu veux aussi piloter depuis l'app mobile)
  Future<void> updateLiveScore({
    required String matchId,
    required int score1,
    required int score2,
    required String time,
    required String status,
    bool isTimerActive = false,
  }) async {
    await _supabase
        .from('matches')
        .update({
          'score1': score1,
          'score2': score2,
          'time': time,
          'status': status,
          'is_timer_active': isTimerActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', matchId);
  }

  // 6. RÉCUPÉRER LES INFOS DE COMPOSITION (LINEUP)
  Future<Map<String, dynamic>> getMatchDetails(String matchId) async {
    final data = await _supabase
        .from('matches')
        .select('*, leagues(name, logo)')
        .eq('id', matchId)
        .single();
    return data;
  }
}
