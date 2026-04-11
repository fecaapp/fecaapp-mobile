import 'package:flutter/material.dart';
import 'withdrawal_screen.dart';

class DashboardScreen extends StatelessWidget {
  final int followers;
  final double currentEarnings;

  const DashboardScreen({
    super.key,
    this.followers = 12500,
    this.currentEarnings = 45850.0,
  });

  @override
  Widget build(BuildContext context) {
    bool isEligible = followers >= 10000;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "FECA-FINANCE",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // AJOUT : On passe le 'context' ici
            _buildEarningsCard(context, isEligible),
            const SizedBox(height: 35),

            // ... reste du code identique ...
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ANALYTICS 30 DERNIERS JOURS",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.greenAccent.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatTile(
                  "Vues",
                  "1.2M",
                  Icons.remove_red_eye_outlined,
                  Colors.blueAccent,
                ),
                _buildStatTile(
                  "Abonnés",
                  "+850",
                  Icons.people_outline,
                  Colors.purpleAccent,
                ),
                _buildStatTile(
                  "Engagement",
                  "12.4%",
                  Icons.auto_awesome_outlined,
                  Colors.pinkAccent,
                ),
                _buildStatTile(
                  "RPM",
                  "0.04 FCFA",
                  Icons.speed_outlined,
                  Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 35),
            if (!isEligible)
              _buildEligibilityTracker()
            else
              _buildPayoutSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // MODIFICATION : Ajout du paramètre BuildContext context
  Widget _buildEarningsCard(BuildContext context, bool isEligible) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isEligible
              ? Colors.greenAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Solde disponible",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isEligible)
                const Icon(
                  Icons.verified_rounded,
                  color: Colors.greenAccent,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEligible
                ? "${currentEarnings.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA"
                : "--- FCFA",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEligible
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.05),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // MODIFICATION ICI : On ajoute le Navigator
              onPressed: isEligible
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WithdrawalScreen(amount: currentEarnings),
                        ),
                      );
                    }
                  : null,
              child: Text(
                isEligible
                    ? "RETIRER VIA MOBILE MONEY"
                    : "REVENUS INDISPONIBLES",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: isEligible ? Colors.black : Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Les autres widgets (_buildStatTile, _buildEligibilityTracker, _buildPayoutSection) restent identiques
  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityTracker() {
    double progress = (followers / 10000).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.amber.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "OBJECTIF MONÉTISATION",
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: Colors.amber,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$followers / 10 000 abonnés",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Color(0xFF1A1A1A),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.greenAccent,
            size: 20,
          ),
        ),
        title: Text(
          "Méthode de retrait",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "Configuré sur MoMo / Orange",
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: Icon(
          Icons.check_circle_outline,
          color: Colors.greenAccent,
          size: 20,
        ),
      ),
    );
  }
}
