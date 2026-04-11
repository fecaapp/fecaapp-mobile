// ==========================================
// CONFIGURATION INTEGRALE SUPABASE (MIGRATION)
// ==========================================

class AppConfig {
  // 1. PARAMÈTRES DE CONNEXION (Extraits de ton main.dart)
  static const String supabaseUrl = "https://xmbuqisqmxigdcuivdjc.supabase.co";
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtYnVxaXNxbXhpZ2RjdWl2ZGpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5ODkzNDEsImV4cCI6MjA4MTU2NTM0MX0.QZS1y1gwQnTWIFsWw2Jw9NoNL6j0vgUmufjwul88T3g";

  // 2. IDENTIFIANTS DES BUCKETS DE STOCKAGE (STORAGE)
  // Utilise ces constantes dans tes services pour éviter les fautes de frappe
  static const String bucketPosts = 'posts';
  static const String bucketStatuses = 'statuses';
  static const String bucketAvatars = 'avatars';

  // 3. RÉGLAGES DE L'INTERFACE
  static const double maxPostHeight = 600.0;
  static const int storyDurationHours = 24;

  // 4. LOGIQUE DE LIEN PUBLIC (Optionnel)
  // Cette fonction génère l'URL d'une image stockée si besoin hors SocialService
  static String getPublicUrl(String bucket, String path) {
    return "$supabaseUrl/storage/v1/object/public/$bucket/$path";
  }
}
