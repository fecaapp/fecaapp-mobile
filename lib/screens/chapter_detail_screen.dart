import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChapterDetailScreen extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final Color goldColor = const Color(0xFFD4AF37);

  const ChapterDetailScreen({super.key, required this.chapter});

  Future<void> _markAsCompleted(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('user_progress').upsert({
        'user_id': user.id,
        'chapter_id': chapter['id'],
        'is_completed': true,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chapitre terminé ! Suite débloquée.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("Erreur progression: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          chapter['title'],
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: goldColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image d'illustration ou Vidéo
            if (chapter['image_url'] != null)
              Image.network(
                chapter['image_url'],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter['title'],
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    chapter['content'] ?? "Pas de contenu disponible.",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Bouton de validation
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => _markAsCompleted(context),
                      child: const Text(
                        "TERMINER CE CHAPITRE",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
