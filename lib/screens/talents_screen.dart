import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'upload_talent_video.dart';
import 'talent_video_player.dart';
import '../models/user.dart';
import '../services/social_service.dart';

final supabase = sb.Supabase.instance.client;

class TalentsScreen extends StatefulWidget {
  final User user;
  const TalentsScreen({super.key, required this.user});

  @override
  State<TalentsScreen> createState() => _TalentsScreenState();
}

class _TalentsScreenState extends State<TalentsScreen> {
  final SocialService _socialService = SocialService();

  // Garder la position du scroll
  final PageController _pageController = PageController(keepPage: true);

  // Contrôleur pour l'âge
  final TextEditingController _ageController = TextEditingController();

  String searchQuery = "";
  String selectedFoot = "Tous";
  String selectedCategory = "Tous";
  String selectedSpecialty = "Tous";
  int? selectedAge;
  double selectedHeight = 140.0;

  final Map<String, List<String>> _postesData = {
    "Gardien": ["Titulaire", "Remplaçant", "Spécialiste Penalty"],
    "Défenseur": ["Central", "Latéral Droit", "Latéral Gauche", "Libéro"],
    "Milieu": [
      "Meneur de jeu",
      "Offensif",
      "Défensif (Sentinelle)",
      "Relayeur",
    ],
    "Avant-Centre": [
      "Buteur (9)",
      "Ailier Droit",
      "Ailier Gauche",
      "Second Attaquant",
    ],
  };

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _handleJoinRequest(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadTalentScreen(userId: widget.user.id),
      ),
    );
    setState(() {}); // Rafraîchir après l'upload
  }

  // --- FILTRE DE DÉTECTION ---
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<String> specialties = ["Tous"];
            if (_postesData.containsKey(selectedCategory)) {
              specialties.addAll(_postesData[selectedCategory]!);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 25,
                right: 25,
                top: 25,
                bottom: MediaQuery.of(context).viewInsets.bottom + 25,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "FILTRES DE DÉTECTION",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "LIGNE DE POSTE",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            "Tous",
                            "Gardien",
                            "Défenseur",
                            "Milieu",
                            "Avant-Centre",
                          ].map((cat) {
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              selectedColor: Colors.greenAccent,
                              labelStyle: TextStyle(
                                color: selectedCategory == cat
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              onSelected: (val) {
                                setModalState(() {
                                  selectedCategory = cat;
                                  selectedSpecialty = "Tous";
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "POSTE DÉTAILLÉ",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: specialties.map((spec) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(spec),
                              selected: selectedSpecialty == spec,
                              selectedColor: Colors.greenAccent,
                              labelStyle: TextStyle(
                                color: selectedSpecialty == spec
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              onSelected: (val) =>
                                  setModalState(() => selectedSpecialty = spec),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "ÂGE EXACT RECHERCHÉ",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Ex: 17",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          selectedAge = int.tryParse(val);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "TAILLE MINIMUM",
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        Text(
                          "${selectedHeight.toInt()} cm",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: selectedHeight,
                      min: 140,
                      max: 210,
                      divisions: 70,
                      activeColor: Colors.greenAccent,
                      inactiveColor: Colors.white10,
                      onChanged: (val) =>
                          setModalState(() => selectedHeight = val),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "PIED PRÉFÉRÉ",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ["Tous", "Droitier", "Gaucher", "Ambidextre"]
                          .map((foot) {
                            return ChoiceChip(
                              label: Text(foot),
                              selected: selectedFoot == foot,
                              selectedColor: Colors.greenAccent,
                              labelStyle: TextStyle(
                                color: selectedFoot == foot
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              onSelected: (val) =>
                                  setModalState(() => selectedFoot = foot),
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "LANCER LA DÉTECTION",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSeeJoinButton = [
      "joueur",
      "jeune talent",
    ].contains(widget.user.role.toLowerCase().trim());

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Rechercher un talent...",
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.white24, size: 18),
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.greenAccent, size: 28),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        key: ValueKey(
          "$searchQuery$selectedFoot$selectedCategory$selectedHeight$selectedSpecialty$selectedAge",
        ),
        future: _fetchFilteredTalents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Aucun talent ne correspond aux filtres",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final talents = snapshot.data!;
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: talents.length,
            itemBuilder: (context, index) {
              return TalentVideoPlayer(talent: talents[index]);
            },
          );
        },
      ),
      floatingActionButton: canSeeJoinButton
          ? FloatingActionButton.extended(
              backgroundColor: Colors.greenAccent,
              onPressed: () => _handleJoinRequest(context),
              icon: const Icon(Icons.rocket_launch, color: Colors.black),
              label: const Text(
                "REJOINDRE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Future<List<dynamic>> _fetchFilteredTalents() async {
    try {
      // CORRECTION : On pointe vers la table 'likes' unifiée
      var query = supabase.from('talents').select('''
            *, 
            users:user_id(full_name, img_url, is_certified),
            likes(user_id)
          ''');

      if (selectedCategory != "Tous") {
        query = query.eq('category', selectedCategory);
      }
      if (selectedFoot != "Tous") query = query.eq('foot', selectedFoot);
      if (selectedSpecialty != "Tous") {
        query = query.eq('specialty', selectedSpecialty);
      }
      if (selectedAge != null) query = query.eq('age', selectedAge!);
      if (selectedHeight > 140) {
        query = query.gte('height', selectedHeight.toInt());
      }

      final data = await query.order('created_at', ascending: false);

      final List<dynamic> mappedData = (data as List).map((talent) {
        final List likes = talent['likes'] ?? [];

        // Détection robuste du like (comparaison trim/string)
        talent['is_liked_by_me'] = likes.any(
          (l) =>
              l['user_id'].toString().trim() ==
              widget.user.id.toString().trim(),
        );

        // PERSISTANCE : Forçage du typage pour lire les données calculées par SQL
        talent['likes_count'] =
            int.tryParse(talent['likes_count']?.toString() ?? '0') ?? 0;
        talent['comments_count'] =
            int.tryParse(talent['comments_count']?.toString() ?? '0') ?? 0;
        talent['reposts_count'] =
            int.tryParse(talent['reposts_count']?.toString() ?? '0') ?? 0;

        return talent;
      }).toList();

      if (searchQuery.isNotEmpty) {
        return mappedData.where((t) {
          final fullName = (t['users']?['full_name'] ?? "")
              .toString()
              .toLowerCase();
          return fullName.contains(searchQuery.toLowerCase());
        }).toList();
      }
      return mappedData;
    } catch (e) {
      debugPrint("🦁 ERREUR FETCH TALENTS: $e");
      return [];
    }
  }
}
