import 'package:flutter/material.dart';
import '../models/user.dart';
import 'home_screen.dart';
import 'talents_screen.dart';
import 'avis_screen.dart';
import 'profile_screen.dart';
import 'museum_screen.dart'; // Pour ton Drawer (Centre de contrôle)
import 'saga_kings_screen.dart'; // Pour ton Drawer
import 'settings_screen.dart'; // Pour ton Drawer

class RootPage extends StatefulWidget {
  final User user;
  const RootPage({super.key, required this.user});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;

  // Liste des pages pour le Rail Principal
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(user: widget.user),
      TalentsScreen(user: widget.user),
      const AvisScreen(),
      ProfileScreen(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- AXE 2 : LE CENTRE DE CONTRÔLE (DRAWER) ---
      // Utilisé pour les rubriques "bibliothèques"
      drawer: _buildDrawer(context),

      body: IndexedStack(index: _currentIndex, children: _pages),

      // --- AXE 1 : LE RAIL PRINCIPAL ---
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0A0A0A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white38,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_rounded),
            label: "Talents",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_alt),
            label: "Avis",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0A0A0A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Text(
              "BIBLIOTHÈQUES",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.museum, color: Colors.white),
            title: const Text("Musée", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MuseumScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_edu, color: Colors.white),
            title: const Text(
              "Saga des Rois",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SagaKingsScreen()),
            ),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text(
              "Paramètres",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
