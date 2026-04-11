import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/feca_video_player.dart';

class SagaKingsScreen extends StatefulWidget {
  const SagaKingsScreen({super.key});

  @override
  State<SagaKingsScreen> createState() => _SagaKingsScreenState();
}

class _SagaKingsScreenState extends State<SagaKingsScreen> {
  // Instance Supabase
  final SupabaseClient supabase = Supabase.instance.client;

  // Stream pour le temps réel et la récupération automatique
  final Stream<List<Map<String, dynamic>>> _sagaStream = Supabase
      .instance
      .client
      .from('saga_kings')
      .stream(primaryKey: ['id'])
      .order('created_at');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "SAGA DES ROIS",
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _sagaStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Erreur de connexion au Sanctuaire",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          final videos = snapshot.data!;

          if (videos.isEmpty) {
            return const Center(
              child: Text(
                "Les archives sont encore secrètes...",
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return _buildVideoCard(context, video);
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.amber.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // LECTEUR VIDÉO (Directement accessible)
          FecaVideoPlayer(
            videoUrl: video['video_url'] ?? "",
            title: (video['title'] ?? "ÉPISODE").toString().toUpperCase(),
          ),

          // ZONE INFOS STYLE "MUSÉE"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0A0A),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        video['category'] ?? "ARCHIVE",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.share_outlined,
                      color: Colors.white24,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  video['title'] ?? "Sans titre",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  video['description'] ??
                      "Aucune description disponible pour cet épisode.",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(
                      Icons.history_toggle_off,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "AJOUTÉ RÉCEMMENT",
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
