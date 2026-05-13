import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// API_SERVICE.DART
// Singleton — toutes les opérations Auth + Profil + Certification
// ================================================================

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Utilisateur courant ──────────────────────────────────────
  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isLoggedIn => currentUser != null;

  // ================================================================
  // 1. INSCRIPTION
  // ================================================================
  /// Crée le compte Auth + met à jour le profil avec les données du CV.
  /// [cvData] contient toutes les colonnes supplémentaires (city, sport, etc.)
  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    Map<String, dynamic> cvData = const {},
  }) async {
    // A. Création compte Auth
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );

    // B. Mise à jour du profil avec les données CV
    if (response.user != null && cvData.isNotEmpty) {
      await _upsertProfile(
        userId: response.user!.id,
        fullName: fullName,
        role: role,
        extra: cvData,
      );
    }

    return response;
  }

  // ================================================================
  // 2. CONNEXION
  // ================================================================
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ================================================================
  // 3. DÉCONNEXION
  // ================================================================
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ================================================================
  // 4. UPSERT PROFIL
  // Met à jour (ou crée si absent) la ligne dans la table users.
  // Appelé à l'inscription ET depuis les paramètres du profil.
  // ================================================================
  Future<void> _upsertProfile({
    required String userId,
    required String fullName,
    required String role,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': userId,
        'full_name': fullName,
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
        ...extra,
      };

      // On retire les clés dont la valeur est null ou vide
      payload.removeWhere((k, v) => v == null || v == '');

      await _supabase.from('users').upsert(payload);
    } catch (e) {
      debugPrint("🦁 Erreur upsertProfile: $e");
      rethrow;
    }
  }

  /// Méthode publique pour mettre à jour le CV depuis l'écran Profil.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) throw Exception("Non authentifié");
    try {
      final payload = Map<String, dynamic>.from(data)
        ..removeWhere((k, v) => v == null)
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('users').update(payload).eq('id', uid);
    } catch (e) {
      debugPrint("🦁 Erreur updateProfile: $e");
      rethrow;
    }
  }

  // ================================================================
  // 5. RÉCUPÉRER LE PROFIL COMPLET
  // ================================================================
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await _supabase
          .from('users')
          .select()
          .eq('id', userId.trim())
          .maybeSingle();
    } catch (e) {
      debugPrint("🦁 Erreur getProfile: $e");
      return null;
    }
  }

  // ================================================================
  // 6. CERTIFICATION PROFESSIONNELLE
  // Upload fichier → insert certifications → en attente admin
  // ================================================================
  Future<void> submitCertification({
    required File file,
    String? diplomaType,
    String? institution,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception("Non authentifié");

    final ext = file.path.split('.').last.toLowerCase();
    final fileName = 'cert_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$uid/$fileName';

    try {
      // A. Upload dans le bucket 'certifications'
      await _supabase.storage
          .from('certifications')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // B. URL publique
      final fileUrl = _supabase.storage
          .from('certifications')
          .getPublicUrl(filePath);

      // C. Enregistrement en base
      await _supabase.from('certifications').insert({
        'user_id': uid,
        'diploma_type': diplomaType,
        'institution': institution,
        'file_url': fileUrl,
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("🦁 Certification soumise : $fileUrl");
    } catch (e) {
      debugPrint("🦁 Erreur submitCertification: $e");
      rethrow;
    }
  }

  // ================================================================
  // 7. VÉRIFIER LE STATUT DE CERTIFICATION
  // ================================================================
  Future<String?> getCertificationStatus() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final res = await _supabase
          .from('certifications')
          .select('status')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res?['status'] as String?;
    } catch (e) {
      debugPrint("🦁 Erreur getCertificationStatus: $e");
      return null;
    }
  }

  // ================================================================
  // 8. RÉINITIALISATION MOT DE PASSE
  // ================================================================
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }

  // ================================================================
  // 9. MISE À JOUR MOT DE PASSE (depuis lien email)
  // ================================================================
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ================================================================
  // 10. UPLOAD AVATAR / COVER
  // ================================================================
  Future<String> uploadMedia({
    required File file,
    required String bucket, // 'avatars' ou 'posts'
    required String folder, // userId
    String prefix = 'img',
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$folder/$fileName';

    await _supabase.storage
        .from(bucket)
        .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

    return _supabase.storage.from(bucket).getPublicUrl(filePath);
  }
}
