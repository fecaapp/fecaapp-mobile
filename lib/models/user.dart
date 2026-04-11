class User {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isCertified;
  final String? bio;

  // --- CHAMPS MODIFIABLES (URLs des médias) ---
  String? img_url;
  String? cover_url;

  // --- STATISTIQUES LIONS ---
  final int followersCount;
  final int followingCount;
  final int postsCount;

  // --- SÉCURITÉ / FINANCES ---
  final String? withdrawalPhone;
  final String? withdrawalPin;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isCertified,
    this.bio,
    this.img_url,
    this.cover_url,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.withdrawalPhone,
    this.withdrawalPin,
  });

  // ============================================================
  // 1. DU JSON VERS L'OBJET (MAPPING SUPABASE -> FLUTTER)
  // ============================================================
  factory User.fromJson(Map<String, dynamic> json) {
    // Supabase renvoie les noms de colonnes exacts définis dans ton SQL (snake_case)
    return User(
      id: json['id']?.toString() ?? '',

      // Correspondance exacte avec 'full_name' dans ton SQL
      fullName: json['full_name'] ?? 'Lion anonyme',

      email: json['email'] ?? '',

      role: json['role']?.toString() ?? 'USER',

      // Supabase stocke le BOOLEAN SQL directement
      isCertified: json['is_certified'] == true,

      bio: json['bio']?.toString(),

      // Mapping direct des colonnes img_url et cover_url
      img_url: json['img_url']?.toString(),
      cover_url: json['cover_url']?.toString(),

      // Statistiques (Valeurs par défaut à 0 selon ton SQL)
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      postsCount: json['posts_count'] ?? 0,

      // Données financières (si elles existent dans ta table ou via extension)
      withdrawalPhone: json['withdrawal_phone']?.toString(),
      withdrawalPin: json['withdrawal_pin']?.toString(),
    );
  }

  // ============================================================
  // 2. DE L'OBJET VERS LE JSON (POUR .UPDATE() DANS SUPABASE)
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'is_certified': isCertified,
      'bio': bio,
      'img_url': img_url,
      'cover_url': cover_url,
      'followers_count': followersCount,
      'following_count': followingCount,
      'posts_count': postsCount,
      'withdrawal_phone': withdrawalPhone,
      'withdrawal_pin': withdrawalPin,
    };
  }

  // ============================================================
  // 3. MÉTHODE COPYWITH (GESTION D'ÉTAT PROVIDER)
  // ============================================================
  User copyWith({
    String? fullName,
    String? bio,
    String? img_url,
    String? cover_url,
    bool? isCertified,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    String? withdrawalPhone,
    String? withdrawalPin,
  }) {
    return User(
      id: id,
      email: email,
      role: role,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      img_url: img_url ?? this.img_url,
      cover_url: cover_url ?? this.cover_url,
      isCertified: isCertified ?? this.isCertified,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      withdrawalPhone: withdrawalPhone ?? this.withdrawalPhone,
      withdrawalPin: withdrawalPin ?? this.withdrawalPin,
    );
  }
}
