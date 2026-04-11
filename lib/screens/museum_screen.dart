import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/museum_provider.dart';
import 'legend_sanctuary_screen.dart';
import 'hall_of_fame_grid_screen.dart';
import 'quiz_game_screen.dart';
// Note : Assure-toi que ce widget gère bien les vidéos natives ou web
import '../widgets/feca_video_player.dart';

class MuseumScreen extends StatefulWidget {
  const MuseumScreen({super.key});

  @override
  State<MuseumScreen> createState() => _MuseumScreenState();
}

class _MuseumScreenState extends State<MuseumScreen> {
  @override
  void initState() {
    super.initState();
    // Chargement des données dès l'entrée dans le Musée
    Future.microtask(
      () =>
          Provider.of<MuseumProvider>(context, listen: false).fetchMuseumData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On écoute les changements du provider
    final museumData = Provider.of<MuseumProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Fond noir profond
      body: museumData.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : RefreshIndicator(
              color: Colors.amber,
              onRefresh: () => museumData.fetchMuseumData(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),

                  // --- BANNIÈRE QUIZ (SYSTÈME DE GRADES) ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
                      child: _buildQuizBanner(context, museumData),
                    ),
                  ),

                  // --- SECTION : HALL OF FAME (LÉGENDES) ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _buildHallOfFameSection(
                        context,
                        museumData.legends,
                      ),
                    ),
                  ),

                  // --- SECTION : VIDÉOTHÈQUE PRESTIGE ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("VIDÉOTHÈQUE PRESTIGE"),
                          const SizedBox(height: 20),
                          if (museumData.videos.isEmpty)
                            const Center(
                              child: Text(
                                "Archives en cours de restauration...",
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ...museumData.videos.map(
                              (video) => _buildVideoCard(context, video),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      backgroundColor: Colors.black,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          "ANTRE DES LIONS",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 14,
            color: Colors.white,
            // Ombre portée pour que le texte reste lisible sur les couleurs du drapeau
            shadows: [
              Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 2)),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // --- TON IMAGE LOCALE EXPORTÉE ---
            // BoxFit.cover force l'image à remplir tout l'espace et coupe le blanc
            Image.asset(
              "assets/fecaapp_final.png",
              fit: BoxFit.cover,
              alignment: Alignment.center,
              // Sécurité au cas où l'image aurait encore un souci
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1B4332),
                child: const Icon(Icons.flag, color: Colors.amber, size: 50),
              ),
            ),

            // Overlay dégradé pour le style "Premium" et la lisibilité du titre
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4), // Assombrit le haut
                    Colors.transparent, // Laisse voir le centre
                    const Color(0xFF050505), // Transition vers le fond noir
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizBanner(BuildContext context, MuseumProvider museumData) {
    final String currentBadge = museumData.userBadge;
    final int nextSession = museumData.nextSessionNumber;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFC5A028), Color(0xFF8B4513)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.black54,
            size: 40,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GRADE : $currentBadge",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "SÉANCE $nextSession DISPONIBLE",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      QuizGameScreen(sessionNumber: nextSession),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "JOUER",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallOfFameSection(BuildContext context, List legends) {
    if (legends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle("HALL OF FAME (L'ÉLITE)"),
              _buildSeeAllButton(context, legends),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            physics: const BouncingScrollPhysics(),
            itemCount: legends.length,
            itemBuilder: (context, index) =>
                _buildHallOfFameCard(context, legends[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHallOfFameCard(BuildContext context, dynamic legend) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LegendSanctuaryScreen(legendData: legend),
        ),
      ),
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 15, bottom: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF111111),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  legend['img_url'] ?? "https://via.placeholder.com/300",
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.person, color: Colors.white10, size: 50),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    legend['name']?.toString().toUpperCase() ?? "NOM",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    legend['title']?.toString() ?? "LÉGENDE",
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, dynamic video) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: FecaVideoPlayer(
              videoUrl: video['url'],
              title: video['title'],
            ),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    video['thumbnail'] ?? "",
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 30,
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? "Archive",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video['duration'] ?? "VOD",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.amber,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        fontSize: 11,
      ),
    );
  }

  Widget _buildSeeAllButton(BuildContext context, List legends) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HallOfFameGridScreen(legends: legends),
        ),
      ),
      child: const Text(
        "VOIR TOUT",
        style: TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
