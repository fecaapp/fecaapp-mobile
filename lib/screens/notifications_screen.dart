import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Filtre actif par défaut
  String activeFilter = "Tout";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "NOTIFICATIONS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSectionTitle("RÉCENT"),
                _buildNotificationItem(
                  type: "certification",
                  title: "Profil Certifié",
                  desc: "Votre badge 'Talent Élite' est désormais actif.",
                  time: "2 min",
                  isUnread: true,
                ),
                _buildNotificationItem(
                  type: "agent",
                  title: "Nouvelle Opportunité",
                  desc: "Un recruteur a consulté votre CV sportif.",
                  time: "45 min",
                  isUnread: true,
                ),
                _buildSectionTitle("CETTE SEMAINE"),
                _buildNotificationItem(
                  type: "like",
                  title: "Nouveau Like",
                  desc: "Samuel E. et 15 autres ont aimé votre vidéo.",
                  time: "Hier",
                  isUnread: false,
                ),
                _buildNotificationItem(
                  type: "comment",
                  title: "Commentaire",
                  desc: "Coach Jean a répondu à votre publication.",
                  time: "2j",
                  isUnread: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BARRE DE FILTRES ---
  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          _filterChip("Tout"),
          _filterChip("Professionnel"),
          _filterChip("Social"),
          _filterChip("Système"),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.greenAccent
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // --- ITEM DE NOTIFICATION ---
  Widget _buildNotificationItem({
    required String type,
    required String title,
    required String desc,
    required String time,
    required bool isUnread,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case "certification":
        icon = Icons.stars_rounded;
        color = Colors.amber;
        break;
      case "agent":
        icon = Icons.work_rounded;
        color = Colors.blueAccent;
        break;
      case "like":
        icon = Icons.favorite_rounded;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.greenAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white.withOpacity(0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              time,
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            desc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: isUnread
            ? Container(
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
