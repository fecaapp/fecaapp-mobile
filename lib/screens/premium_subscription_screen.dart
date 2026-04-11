import 'package:flutter/material.dart';

class PremiumSubscriptionScreen extends StatelessWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Fond avec un Lion en filigrane ou texture culturelle
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.network(
                "https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?q=80",
                fit: BoxFit.cover,
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 120,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    "LE CLUB DES LIONS",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        Icons.auto_awesome,
                        "Accès exclusif à la 'Saga des Rois'",
                      ),
                      _buildFeatureRow(
                        Icons.confirmation_number,
                        "Priorité billetterie (Grands Matchs)",
                      ),
                      _buildFeatureRow(
                        Icons.visibility,
                        "Highlights HD & Caméra Vestiaires",
                      ),
                      _buildFeatureRow(
                        Icons.stars,
                        "Badge 'Mécène du Football' doré",
                      ),
                      const SizedBox(height: 40),
                      _buildPlanCard(
                        "LIONCEAU",
                        "500",
                        "XAF /mois",
                        Colors.green,
                      ),
                      const SizedBox(height: 20),
                      _buildPlanCard(
                        "LION INDOMPTABLE",
                        "1500",
                        "XAF /mois",
                        Colors.amber,
                        isPremium: true,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "En vous abonnant, vous financez directement la formation des jeunes talents locaux.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 15),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String title,
    String price,
    String period,
    Color accentColor, {
    bool isPremium = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isPremium ? accentColor : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isPremium ? Colors.transparent : Colors.white10,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isPremium ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: isPremium ? Colors.black : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      color: isPremium ? Colors.black54 : Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.black : accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () {},
            child: Text(
              "CHOISIR",
              style: TextStyle(
                color: isPremium ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
