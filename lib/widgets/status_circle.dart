import 'package:flutter/material.dart';

class StatusCircle extends StatelessWidget {
  final dynamic status; // Les données reçues de Supabase
  final VoidCallback onTap;

  const StatusCircle({super.key, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Récupération sécurisée des données du profil
    final profile = status['profiles'];
    final String avatarUrl = profile != null ? profile['avatar_url'] ?? '' : '';
    final String fullName = profile != null
        ? profile['full_name'] ?? 'Lion'
        : 'Lion';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(
                3,
              ), // L'espace pour la bordure dorée
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber, Colors.orangeAccent, Colors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.black,
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 70,
              child: Text(
                fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
