import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Page de destination pour les chapitres
class ChapterDetailScreen extends StatelessWidget {
  final Map<String, dynamic> chapter;
  const ChapterDetailScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    const Color goldColor = Color(0xFFD4AF37);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(
        child: Text(
          "Contenu du chapitre: ${chapter['title']}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class FinanceEducationScreen extends StatefulWidget {
  const FinanceEducationScreen({super.key});

  @override
  State<FinanceEducationScreen> createState() => _FinanceEducationScreenState();
}

class _FinanceEducationScreenState extends State<FinanceEducationScreen> {
  final supabase = Supabase.instance.client;

  // Stream pour récupérer les modules en temps réel
  final Stream<List<Map<String, dynamic>>> _modulesStream = Supabase
      .instance
      .client
      .from('modules')
      .stream(primaryKey: ['id'])
      .order('order_index');

  // Fonction pour récupérer le nombre de modules complétés par l'utilisateur
  Future<int> _getCompletedModulesCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    // On compte combien de modules ont TOUS leurs chapitres complétés dans 'user_progress'
    // Pour simplifier ici, on simule ou on récupère une valeur.
    // Logique recommandée : Compter les chapitres uniques complétés / total par module.
    return 1; // Valeur par défaut pour le test
  }

  @override
  Widget build(BuildContext context) {
    const Color goldColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: goldColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ÉDUCATION FINANCIÈRE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: FutureBuilder<int>(
        future: _getCompletedModulesCount(),
        builder: (context, progressSnapshot) {
          int completedCount = progressSnapshot.data ?? 0;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _modulesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: goldColor),
                );
              }

              final modules = snapshot.data!;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressCard(
                      goldColor,
                      completedCount,
                      modules.length,
                    ),
                    const SizedBox(height: 35),
                    _buildSectionTitle("VOTRE CURRICULUM"),
                    const SizedBox(height: 20),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        // UNLOCK LOGIC:
                        // Le module est débloqué si c'est le premier (index 0)
                        // OU si l'index est inférieur ou égal au nombre de modules complétés.
                        bool isUnlocked = index <= completedCount;

                        return GestureDetector(
                          onTap: () {
                            if (isUnlocked) {
                              _showModuleChapters(
                                context,
                                module['id'],
                                module['title'],
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Module verrouillé. Terminez les étapes précédentes.",
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: _buildCourseModule(
                            step: module['order_index'].toString(),
                            title: module['title'],
                            desc: module['description'] ?? "",
                            isUnlocked: isUnlocked,
                            goldColor: goldColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Affiche la liste des chapitres pour un module donné
  void _showModuleChapters(
    BuildContext context,
    String moduleId,
    String title,
  ) async {
    final chapters = await supabase
        .from('chapters')
        .select()
        .eq('module_id', moduleId)
        .order('order_index');

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              ...chapters.map(
                (ch) => ListTile(
                  leading: const Icon(
                    Icons.menu_book,
                    color: Color(0xFFD4AF37),
                  ),
                  title: Text(
                    ch['title'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChapterDetailScreen(chapter: ch),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(Color goldColor, int completed, int total) {
    double progress = total > 0 ? completed / total : 0;
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [goldColor, const Color(0xFF8A6E2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "STATUT ACTUEL",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const Text(
            "Futur Investisseur",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 25),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "$completed module(s) sur $total complétés (${(progress * 100).toInt()}%)",
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildCourseModule({
    required String step,
    required String title,
    required String desc,
    required bool isUnlocked,
    required Color goldColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnlocked ? goldColor.withOpacity(0.4) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: isUnlocked ? goldColor : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: isUnlocked ? Colors.black : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            isUnlocked ? Icons.play_circle_fill : Icons.lock_outline,
            color: isUnlocked ? goldColor : Colors.white10,
            size: 26,
          ),
        ],
      ),
    );
  }
}
