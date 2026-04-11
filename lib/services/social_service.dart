import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// FICHIER : SOCIAL_SERVICE.DART (VERSION UNIFIÉE ET SÉCURISÉE)
// ==========================================

class SocialService {
  final SupabaseClient supabase = Supabase.instance.client;

  // --- 1. RÉCUPÉRER LE FLUX (POSTS & VIDEOS) ---
  Future<List<dynamic>> fetchPosts(String userId, {String? authorId}) async {
    try {
      var request = supabase.from('posts').select('''
            *, 
            users:author_id(full_name, img_url, is_certified), 
            likes(user_id)
          ''');

      if (authorId != null) {
        request = request.eq('author_id', authorId.trim());
      }

      final response = await request.order('created_at', ascending: false);

      final posts = (response as List).map((post) {
        final List likes = post['likes'] ?? [];
        post['is_liked_by_me'] = likes.any(
          (l) => l['user_id'].toString() == userId.toString(),
        );
        post['likes_count'] = post['likes_count'] ?? 0;
        post['comments_count'] = post['comments_count'] ?? 0;
        post['reposts_count'] = post['reposts_count'] ?? 0;
        return post;
      }).toList();

      return posts;
    } catch (e) {
      print("🦁 Erreur fetchPosts: $e");
      return [];
    }
  }

  // --- 2. CRÉER UN POST ---
  Future<bool> createPost({
    required String userId,
    required String content,
    required String type,
    File? file,
  }) async {
    try {
      String? mediaUrl;
      if (file != null) {
        final fileExt = file.path.split('.').last;
        final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";
        final filePath = "${userId.trim()}/$fileName";
        await supabase.storage.from('posts').upload(filePath, file);
        mediaUrl = supabase.storage.from('posts').getPublicUrl(filePath);
      }
      await supabase.from('posts').insert({
        'author_id': userId.trim(),
        'content': content,
        'type': type.toUpperCase(),
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_repost': false,
        'likes_count': 0,
        'comments_count': 0,
        'reposts_count': 0,
      });
      return true;
    } catch (e) {
      print("🦁 Erreur createPost: $e");
      return false;
    }
  }

  // --- 3. MISE À JOUR MÉDIAS PROFIL ---
  Future<bool> updateProfileMedia({
    required String userId,
    required File file,
    required String type,
  }) async {
    try {
      final fileExt = file.path.split('.').last;
      final filePath =
          "${userId.trim()}/${type}_${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      await supabase.storage
          .from('avatars')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);
      final String column = type == 'avatar' ? 'img_url' : 'cover_url';
      await supabase
          .from('users')
          .update({column: publicUrl})
          .eq('id', userId.trim());
      return true;
    } catch (e) {
      print("🦁 Erreur updateProfileMedia: $e");
      return false;
    }
  }

  // --- 4. LIKER / UNLIKER (POSTS) ---
  Future<bool> toggleLike(String postId, String userId) async {
    try {
      final existing = await supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId.trim())
          .maybeSingle();
      if (existing != null) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId.trim());
        return false;
      } else {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId.trim(),
        });
        return true;
      }
    } catch (e) {
      print("🦁 Erreur toggleLike: $e");
      rethrow;
    }
  }

  // --- 5. SYSTEME DE FOLLOW ---
  Future<bool?> toggleFollow(String followerId, String followingId) async {
    try {
      final existing = await supabase
          .from('follows')
          .select()
          .eq('follower_id', followerId.trim())
          .eq('following_id', followingId.trim())
          .maybeSingle();
      if (existing != null) {
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', followerId.trim())
            .eq('following_id', followingId.trim());
        return false;
      } else {
        await supabase.from('follows').insert({
          'follower_id': followerId.trim(),
          'following_id': followingId.trim(),
        });
        return true;
      }
    } catch (e) {
      print("🦁 Erreur Toggle Follow: $e");
      return null;
    }
  }

  // --- 6. RÉCUPÉRER LES STATUTS ---
  Future<List<dynamic>> fetchStatuses(String userId) async {
    try {
      final yesterday = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();
      final response = await supabase
          .from('statuses')
          .select('*, users:author_id(full_name, img_url)')
          .gt('created_at', yesterday)
          .order('created_at', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      print("🦁 Erreur fetchStatuses: $e");
      return [];
    }
  }

  // --- 7. CRÉER UN STATUT ---
  Future<bool> createStatus({
    required String userId,
    required String content,
    File? imageFile,
  }) async {
    try {
      String? mediaUrl;
      if (imageFile != null) {
        final fileExt = imageFile.path.split('.').last;
        final fileName =
            "status_${DateTime.now().millisecondsSinceEpoch}.$fileExt";
        final filePath = "${userId.trim()}/$fileName";
        await supabase.storage.from('statuses').upload(filePath, imageFile);
        mediaUrl = supabase.storage.from('statuses').getPublicUrl(filePath);
      }
      await supabase.from('statuses').insert({
        'author_id': userId.trim(),
        'content': content,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print("🦁 Erreur createStatus: $e");
      return false;
    }
  }

  // --- 8. AJOUTER UN COMMENTAIRE (POSTS) ---
  Future<bool> addComment(String postId, String userId, String content) async {
    try {
      final userData = await supabase
          .from('users')
          .select('full_name, img_url, is_certified')
          .eq('id', userId.trim())
          .single();
      await supabase.from('comments').insert({
        'post_id': postId,
        'author_id': userId.trim(),
        'content': content,
        'author_name': userData['full_name'],
        'author_img_url': userData['img_url'],
        'is_certified': userData['is_certified'],
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print("🦁 Erreur addComment: $e");
      return false;
    }
  }

  // --- 9. STREAM COMMENTAIRES (POSTS) ---
  Stream<List<dynamic>> getCommentsStream(String postId) {
    return supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  // --- 10. REPOSTER (POSTS) ---
  Future<void> repost(String userId, dynamic postDataOrId) async {
    try {
      Map<String, dynamic> fullPost;
      if (postDataOrId is Map) {
        fullPost = Map<String, dynamic>.from(postDataOrId);
      } else {
        fullPost = await supabase
            .from('posts')
            .select('*, users:author_id(full_name)')
            .eq('id', postDataOrId.toString())
            .single();
      }
      final String authorName = fullPost['users']?['full_name'] ?? "Membre";
      await supabase.from('reposts').insert({
        'user_id': userId.trim(),
        'post_id': fullPost['id'],
      });
      await supabase.from('posts').insert({
        'author_id': userId.trim(),
        'content': fullPost['content'] ?? "",
        'media_url': fullPost['media_url'],
        'type': fullPost['type'] ?? "TEXT",
        'is_repost': true,
        'original_author_name': authorName,
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
        'comments_count': 0,
        'reposts_count': 0,
      });
    } catch (e) {
      print("🦁 Erreur repost: $e");
      rethrow;
    }
  }

  // --- 11. SUPPRIMER UN POST ---
  Future<void> deletePost(dynamic postId) async {
    try {
      await supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      print("🦁 Erreur deletePost: $e");
    }
  }

  // --- 12. ABONNEMENT TEMPS RÉEL (POSTS) ---
  void subscribeToPosts(Function onUpdate) {
    supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  // --- 13. VÉRIFIER LE STATUT DE SUIVI ---
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final res = await supabase
          .from('follows')
          .select()
          .eq('follower_id', followerId.trim())
          .eq('following_id', followingId.trim())
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  // --- 14. RECHERCHE GLOBALE ---
  Future<List<dynamic>> searchEverything(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      final response = await supabase
          .from('users')
          .select('id, full_name, img_url, is_certified, email, role')
          .ilike('full_name', '%${query.trim()}%')
          .limit(15);
      return response as List<dynamic>;
    } catch (e) {
      print("🦁 Erreur recherche: $e");
      return [];
    }
  }

  // ======================================================
  // --- 15. GESTION UNIFIÉE TALENTS (CORRIGÉE) ---
  // ======================================================

  Future<List<dynamic>> fetchTalents(String userId, {String? talentId}) async {
    try {
      // On récupère les likes depuis la table unifiée 'likes'
      var query = supabase.from('talents').select('''
            *, 
            users:user_id(full_name, img_url, is_certified), 
            likes(user_id)
          ''');

      if (talentId != null) {
        query = query.eq('id', talentId);
      }

      final response = await query.order('created_at', ascending: false);

      final talents = (response as List).map((talent) {
        final List likes = talent['likes'] ?? [];

        talent['is_liked_by_me'] = likes.any(
          (l) => l['user_id'].toString() == userId.trim(),
        );

        // Forçage du typage pour garantir l'affichage des compteurs sync par Trigger
        talent['likes_count'] =
            int.tryParse(talent['likes_count']?.toString() ?? '0') ?? 0;
        talent['comments_count'] =
            int.tryParse(talent['comments_count']?.toString() ?? '0') ?? 0;
        talent['reposts_count'] =
            int.tryParse(talent['reposts_count']?.toString() ?? '0') ?? 0;

        return talent;
      }).toList();

      return talents;
    } catch (e) {
      print("🦁 Erreur fetchTalents: $e");
      return [];
    }
  }

  Future<bool> toggleTalentLike(String talentId, String userId) async {
    try {
      // Utilisation de la table unifiée 'likes' avec talent_id
      final existing = await supabase
          .from('likes')
          .select()
          .eq('talent_id', talentId)
          .eq('user_id', userId.trim())
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('likes')
            .delete()
            .eq('talent_id', talentId)
            .eq('user_id', userId.trim());
        return false;
      } else {
        await supabase.from('likes').insert({
          'talent_id': talentId,
          'user_id': userId.trim(),
        });
        return true;
      }
    } catch (e) {
      print("🦁 Erreur toggleTalentLike: $e");
      rethrow;
    }
  }

  Future<bool> addTalentComment(
    String talentId,
    String userId,
    String content,
  ) async {
    try {
      final userData = await supabase
          .from('users')
          .select('full_name, img_url, is_certified')
          .eq('id', userId.trim())
          .single();

      // Utilisation de la table unifiée 'comments' avec talent_id
      await supabase.from('comments').insert({
        'talent_id': talentId,
        'author_id': userId.trim(),
        'content': content,
        'author_name': userData['full_name'],
        'author_img_url': userData['img_url'],
        'is_certified': userData['is_certified'],
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print("🦁 Erreur addTalentComment: $e");
      return false;
    }
  }

  Stream<List<dynamic>> getTalentCommentsStream(String talentId) {
    // Stream sur la table unifiée 'comments'
    return supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('talent_id', talentId)
        .order('created_at', ascending: true);
  }

  Future<void> talentRepost(String talentId, String userId) async {
    try {
      // Utilisation de la table unifiée 'reposts' avec talent_id
      await supabase.from('reposts').insert({
        'talent_id': talentId,
        'user_id': userId.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("🦁 Erreur talentRepost: $e");
      rethrow;
    }
  }
}
