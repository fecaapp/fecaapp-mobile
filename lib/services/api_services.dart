import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // On utilise l'instance globale de Supabase (déjà initialisée dans ton main.dart)
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- 1. INSCRIPTION (REMPLACE REGISTER) ---
  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    // Création de l'utilisateur dans Supabase Auth
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );

    // Note : Supabase crée automatiquement une ligne dans la table 'profiles'
    // si tu as configuré un Trigger SQL. Sinon, on peut le faire ici.
    return response;
  }

  // --- 2. CONNEXION (REMPLACE LOGIN) ---
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // --- 3. DÉCONNEXION ---
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // --- 4. CERTIFICATION (STORAGE + DATABASE) ---
  Future<void> submitCertification({
    required File file,
    required String diplomaType,
    required String institution,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Non authentifié");

    final fileName = 'cert_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${user.id}/$fileName';

    // A. Envoi du fichier dans le bucket 'certifications'
    await _supabase.storage.from('certifications').upload(filePath, file);

    // B. Récupération de l'URL publique
    final fileUrl = _supabase.storage
        .from('certifications')
        .getPublicUrl(filePath);

    // C. Enregistrement des infos dans ta table 'certifications'
    await _supabase.from('certifications').insert({
      'user_id': user.id,
      'diploma_type': diplomaType,
      'institution': institution,
      'file_url': fileUrl,
      'status': 'PENDING', // En attente de validation par un admin
    });
  }
}
