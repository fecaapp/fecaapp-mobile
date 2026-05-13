// lib/services/fecaai_service.dart
//
// Service FecaAI — Appelle la Supabase Edge Function "fecaai-chat"
// La clé Gemini est dans les secrets Supabase, jamais dans l'APK.
//
// DÉPENDANCE : http: ^1.2.0 (déjà dans pubspec.yaml)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config.dart';

class FecaAIService {
  // URL de la Edge Function Supabase
  static String get _functionUrl => dotenv.env['SUPABASE_FUNCTION_URL'] ?? '';

  // Secret partagé avec la Edge Function
  static String get _appSecret => dotenv.env['FECAAPP_SECRET'] ?? '';

  // Clé anon Supabase — déjà présente dans config.dart
  static String get _anonKey => AppConfig.supabaseAnonKey;

  // ─── Envoi d'un message à FecaAI via Supabase Edge Function ──────────────

  static Future<String> sendMessage({
    required String userMessage,
    required String userRole,
    required String userName,
    required String userSport,
    required String userLevel,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final body = jsonEncode({
      'user_message': userMessage,
      'user_role': userRole,
      'user_name': userName,
      'user_sport': userSport,
      'user_level': userLevel,
      // Historique limité aux 10 derniers échanges
      'conversation_history': conversationHistory.length > 10
          ? conversationHistory
                .sublist(conversationHistory.length - 10)
                .map((m) => {'role': m['role'], 'content': m['content']})
                .toList()
          : conversationHistory
                .map((m) => {'role': m['role'], 'content': m['content']})
                .toList(),
    });

    try {
      final response = await http
          .post(
            Uri.parse(_functionUrl),
            headers: {
              'Content-Type': 'application/json',
              // Headers requis par Supabase pour appeler une Edge Function
              'Authorization': 'Bearer $_anonKey',
              'apikey': _anonKey,
              // Clé secrète FecaApp pour authentifier la requête
              'X-FecaApp-Secret': _appSecret,
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw Exception('Délai dépassé'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['response'] as String? ?? '';
        if (text.isEmpty) return 'Réponse vide. Réessaie ! 🔄';
        return text;
      } else if (response.statusCode == 401) {
        print('🦁 FecaAI 401 : clé secrète invalide');
        return 'Erreur d\'authentification. Contacte le support. 🔒';
      } else {
        print('🦁 FecaAI Error ${response.statusCode}: ${response.body}');
        return 'Erreur du serveur (${response.statusCode}). Réessaie. 🔧';
      }
    } on Exception catch (e) {
      print('🦁 Erreur FecaAIService: $e');
      return 'Je rencontre une difficulté technique. Vérifie ta connexion et réessaie. 🔧';
    }
  }

  // ─── Vérification que la fonction est joignable ───────────────────────────

  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse(_functionUrl),
            headers: {'Authorization': 'Bearer $_anonKey', 'apikey': _anonKey},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode != 500;
    } catch (_) {
      return false;
    }
  }
}
