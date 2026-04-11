import 'dart:async';
import 'package:flutter/material.dart';
import '../services/social_service.dart';
import 'profile_screen.dart';
import '../models/user.dart'; // L'IMPORT MAGIQUE EST ICI

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SocialService _socialService = SocialService();

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = true);
      final results = await _socialService.searchEverything(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Rechercher un Lion...",
              hintStyle: TextStyle(color: Colors.white24),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.greenAccent,
                size: 18,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final data = _searchResults[index];
                return _buildResultTile(data);
              },
            ),
    );
  }

  Widget _buildResultTile(dynamic data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white10,
          backgroundImage: data['img_url'] != null
              ? NetworkImage(data['img_url'])
              : null,
          child: data['img_url'] == null
              ? const Icon(Icons.person, color: Colors.white24)
              : null,
        ),
        // --- RÉPARATION OVERFLOW (BANDEAU JAUNE) ---
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['full_name'] ?? "Lion Anonyme",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (data['is_certified'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 5),
                child: Icon(Icons.verified, color: Colors.blue, size: 16),
              ),
          ],
        ),
        subtitle: const Text(
          "Voir le profil",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white10,
          size: 14,
        ),
        onTap: () {
          // --- NAVIGATION SANS ERREUR ---
          // On remplit TOUS les champs "required" de ton modèle User
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                user: User(
                  id: data['id'].toString(),
                  fullName: data['full_name'] ?? "Inconnu",
                  email: "", // Champ requis par ton modèle
                  role: "USER", // Champ requis par ton modèle
                  isCertified:
                      data['is_certified'] ??
                      false, // Champ requis par ton modèle
                  img_url: data['img_url'],
                  bio: "Membre de l'Élite",
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
