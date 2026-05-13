import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// SOCIAL_SERVICE.DART — VERSION FINALE
// Fix : comptage likes / comments / reposts
// posts   → likes comptés depuis table likes (jointure)
// talents → likes ET comments comptés depuis tables (jointure)
// ==========================================

class SocialService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ── 1. FETCH POSTS ────────────────────────────────────────────
  // Likes comptés depuis la jointure (pas likes_count colonne)
  // Comments/Reposts lus depuis la colonne DB (trigger COUNT(*) fiable)
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

        // Likes : compter depuis la vraie table (jamais désynchronisé)
        post['likes_count'] = likes.length;
        post['is_liked_by_me'] = likes.any(
          (l) => l['user_id'].toString() == userId.toString(),
        );

        // Comments/Reposts : trigger COUNT(*) côté Supabase → fiable
        post['comments_count'] = post['comments_count'] ?? 0;
        post['reposts_count'] = post['reposts_count'] ?? 0;
        return post;
      }).toList();

      return posts;
    } catch (e) {
      debugPrint("🦁 Erreur fetchPosts: $e");
      return [];
    }
  }

  // ── 2. CRÉER UN POST ──────────────────────────────────────────
  Future<bool> createPost({
    required String userId,
    required String content,
    required String type,
    File? file,
    List<File>? files,
  }) async {
    try {
      String? mediaUrl;
      List<String> mediaUrls = [];

      if (files != null && files.length > 1) {
        for (int i = 0; i < files.length; i++) {
          final fileExt = files[i].path.split('.').last;
          final fileName =
              "${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt";
          final filePath = "${userId.trim()}/$fileName";
          await supabase.storage.from('posts').upload(filePath, files[i]);
          mediaUrls.add(supabase.storage.from('posts').getPublicUrl(filePath));
        }
      } else if (file != null) {
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
        'media_url': mediaUrls.isNotEmpty ? mediaUrls.first : mediaUrl,
        'media_urls': mediaUrls.isNotEmpty ? mediaUrls : null,
        'created_at': DateTime.now().toIso8601String(),
        'is_repost': false,
        'likes_count': 0,
        'comments_count': 0,
        'reposts_count': 0,
      });
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur createPost: $e");
      return false;
    }
  }

  // ── 3. MISE À JOUR MÉDIAS PROFIL ─────────────────────────────
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
      debugPrint("🦁 Erreur updateProfileMedia: $e");
      return false;
    }
  }

  // ── 4. TOGGLE LIKE (posts) ────────────────────────────────────
  // On ne touche PAS likes_count manuellement
  // fetchPosts recompte depuis la jointure likes(user_id)
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
        return false; // unliked
      } else {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId.trim(),
          // NE PAS mettre talent_id ici — sinon handle_counters
          // va aussi toucher talents par erreur
        });
        return true; // liked
      }
    } catch (e) {
      debugPrint("🦁 Erreur toggleLike: $e");
      rethrow;
    }
  }

  // ── 5. TOGGLE FOLLOW ─────────────────────────────────────────
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
      debugPrint("🦁 Erreur toggleFollow: $e");
      return null;
    }
  }

  // ── 6. FETCH STATUTS ─────────────────────────────────────────
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
      debugPrint("🦁 Erreur fetchStatuses: $e");
      return [];
    }
  }

  // ── 7. CRÉER UN STATUT ────────────────────────────────────────
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
      debugPrint("🦁 Erreur createStatus: $e");
      return false;
    }
  }

  // ── 8. AJOUTER UN COMMENTAIRE (posts) ─────────────────────────
  // NE PAS mettre talent_id → sinon handle_counters touche talents
  // NE PAS incrémenter comments_count manuellement → trigger COUNT(*)
  Future<bool> addComment(String postId, String userId, String content) async {
    try {
      final userData = await supabase
          .from('users')
          .select('full_name, img_url, is_certified')
          .eq('id', userId.trim())
          .single();

      await supabase.from('comments').insert({
        'post_id': postId,
        // talent_id intentionnellement absent → null implicite
        'author_id': userId.trim(),
        'content': content,
        'author_name': userData['full_name'],
        'author_img_url': userData['img_url'],
        'is_certified': userData['is_certified'],
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur addComment: $e");
      return false;
    }
  }

  // ── 9. STREAM COMMENTAIRES (posts) ───────────────────────────
  Stream<List<dynamic>> getCommentsStream(String postId) {
    return supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  // ── 10. REPOST ────────────────────────────────────────────────
  // On ne touche PAS reposts_count manuellement
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

      // Vérifier si déjà reposté
      final existingRepost = await supabase
          .from('reposts')
          .select()
          .eq('user_id', userId.trim())
          .eq('post_id', fullPost['id'])
          .maybeSingle();

      if (existingRepost != null) {
        debugPrint("🦁 Déjà reposté");
        return;
      }

      await supabase.from('reposts').insert({
        'user_id': userId.trim(),
        'post_id': fullPost['id'],
      });

      await supabase.from('posts').insert({
        'author_id': userId.trim(),
        'content': fullPost['content'] ?? "",
        'media_url': fullPost['media_url'],
        'media_urls': fullPost['media_urls'],
        'type': fullPost['type'] ?? "TEXT",
        'is_repost': true,
        'original_author_name': authorName,
        'original_author_img': fullPost['users']?['img_url'],
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
        'comments_count': 0,
        'reposts_count': 0,
      });
    } catch (e) {
      debugPrint("🦁 Erreur repost: $e");
      rethrow;
    }
  }

  // ── 11. SUPPRIMER UN POST ─────────────────────────────────────
  Future<void> deletePost(dynamic postId) async {
    try {
      await supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint("🦁 Erreur deletePost: $e");
    }
  }

  // ── 12. REALTIME ──────────────────────────────────────────────
  // On écoute uniquement INSERT et DELETE sur posts
  // Les UPDATE (compteurs) sont ignorés pour ne pas casser l'optimistic UI
  void subscribeToPosts(Function onUpdate) {
    supabase
        .channel('public:posts:stable')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  // ── 13. VÉRIFIER LE STATUT DE SUIVI ──────────────────────────
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

  // ── 14. RECHERCHE ────────────────────────────────────────────
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
      debugPrint("🦁 Erreur recherche: $e");
      return [];
    }
  }

  // ── 15. TALENTS ──────────────────────────────────────────────

  // FIX PRINCIPAL : on joint likes ET comments pour compter
  // côté client — exactement comme fetchPosts fait pour les likes
  // Ainsi le compteur est toujours exact même si le trigger est en retard
  Future<List<dynamic>> fetchTalents(String userId, {String? talentId}) async {
    try {
      var query = supabase.from('talents').select('''
        *,
        users:user_id(full_name, img_url, is_certified),
        likes(user_id),
        comments(id)
      ''');
      // On filtre les comments pour ne prendre que ceux du talent
      // La jointure Supabase filtre automatiquement sur talent_id = talent.id

      if (talentId != null) query = query.eq('id', talentId);
      final response = await query.order('created_at', ascending: false);

      final talents = (response as List).map((talent) {
        final List likes = talent['likes'] ?? [];
        final List comments = talent['comments'] ?? [];

        // Likes : depuis la jointure → jamais désynchronisé
        talent['likes_count'] = likes.length;
        talent['is_liked_by_me'] = likes.any(
          (l) => l['user_id'].toString() == userId.trim(),
        );

        // Comments : depuis la jointure → jamais désynchronisé
        // Plus besoin du trigger handle_counters pour l'affichage
        talent['comments_count'] = comments.length;

        // Reposts : trigger Supabase (pas de jointure facile)
        talent['reposts_count'] =
            int.tryParse(talent['reposts_count']?.toString() ?? '0') ?? 0;

        return talent;
      }).toList();
      return talents;
    } catch (e) {
      debugPrint("🦁 Erreur fetchTalents: $e");
      return [];
    }
  }

  // FIX : NE PAS mettre post_id dans le like d'un talent
  // sinon le trigger sync_comments_count va toucher posts par erreur
  Future<bool> toggleTalentLike(String talentId, String userId) async {
    try {
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
        return false; // unliked
      } else {
        await supabase.from('likes').insert({
          'talent_id': talentId,
          'user_id': userId.trim(),
          // post_id intentionnellement absent → null implicite
        });
        return true; // liked
      }
    } catch (e) {
      debugPrint("🦁 Erreur toggleTalentLike: $e");
      rethrow;
    }
  }

  // FIX : NE PAS mettre post_id dans un commentaire de talent
  // sinon sync_comments_count va incrémenter posts par erreur
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

      await supabase.from('comments').insert({
        'talent_id': talentId,
        // post_id intentionnellement absent → null implicite
        'author_id': userId.trim(),
        'content': content,
        'author_name': userData['full_name'],
        'author_img_url': userData['img_url'],
        'is_certified': userData['is_certified'],
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur addTalentComment: $e");
      return false;
    }
  }

  // ── STREAM COMMENTAIRES (talents) ────────────────────────────
  Stream<List<dynamic>> getTalentCommentsStream(String talentId) {
    return supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('talent_id', talentId)
        .order('created_at', ascending: true);
  }

  // ── REPOST TALENT ────────────────────────────────────────────
  Future<void> talentRepost(String talentId, String userId) async {
    try {
      await supabase.from('reposts').insert({
        'talent_id': talentId,
        'user_id': userId.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("🦁 Erreur talentRepost: $e");
      rethrow;
    }
  }

  // ── 16. FECAAI ───────────────────────────────────────────────
  Future<Map<String, String>> getUserProfileForAI(String userId) async {
    try {
      final data = await supabase
          .from('users')
          .select('full_name, role, img_url, sport, level')
          .eq('id', userId.trim())
          .single();
      return {
        'full_name': (data['full_name'] ?? 'Athlète').toString(),
        'role': (data['role'] ?? 'joueur').toString().toLowerCase(),
        'img_url': (data['img_url'] ?? '').toString(),
        'sport': (data['sport'] ?? 'Football').toString(),
        'level': (data['level'] ?? 'Amateur').toString(),
      };
    } catch (e) {
      debugPrint("🦁 Erreur getUserProfileForAI: $e");
      return {
        'full_name': 'Athlète',
        'role': 'joueur',
        'img_url': '',
        'sport': 'Football',
        'level': 'Amateur',
      };
    }
  }

  Future<bool> saveAIMessage({
    required String userId,
    required String role,
    required String content,
  }) async {
    try {
      await supabase.from('ai_conversations').insert({
        'user_id': userId.trim(),
        'role': role,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur saveAIMessage: $e");
      return false;
    }
  }

  Future<List<Map<String, String>>> getAIConversationHistory({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final response = await supabase
          .from('ai_conversations')
          .select('role, content')
          .eq('user_id', userId.trim())
          .order('created_at', ascending: true)
          .limit(limit);
      return (response as List)
          .map(
            (row) => {
              'role': row['role'].toString(),
              'content': row['content'].toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint("🦁 Erreur getAIConversationHistory: $e");
      return [];
    }
  }

  Future<bool> clearAIConversationHistory(String userId) async {
    try {
      await supabase
          .from('ai_conversations')
          .delete()
          .eq('user_id', userId.trim());
      return true;
    } catch (e) {
      debugPrint("🦁 Erreur clearAIConversationHistory: $e");
      return false;
    }
  }
}
