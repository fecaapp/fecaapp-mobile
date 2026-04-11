import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class AvisScreen extends StatefulWidget {
  const AvisScreen({super.key});

  @override
  State<AvisScreen> createState() => _AvisScreenState();
}

class _AvisScreenState extends State<AvisScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _reviewController = TextEditingController();
  bool _isAnonymous = false;
  String? _editingReviewId;

  // --- NOUVEAUX ÉLÉMENTS POUR LE TRI ---
  String _activeFilter = "Tous";
  DateTime? _customStartDate;

  String? get currentUserId => supabase.auth.currentUser?.id;

  final _reviewsStream = Supabase.instance.client
      .from('reviews')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  // LOGIQUE DE FILTRAGE INTERACTIF
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> reviews) {
    final now = DateTime.now();
    if (_activeFilter == "7 jours") {
      return reviews
          .where(
            (r) => now.difference(DateTime.parse(r['created_at'])).inDays <= 7,
          )
          .toList();
    } else if (_activeFilter == "30 jours") {
      return reviews
          .where(
            (r) => now.difference(DateTime.parse(r['created_at'])).inDays <= 30,
          )
          .toList();
    } else if (_activeFilter == "Précis" && _customStartDate != null) {
      // Filtre sur la journée précise choisie
      return reviews.where((r) {
        final date = DateTime.parse(r['created_at']);
        return date.year == _customStartDate!.year &&
            date.month == _customStartDate!.month &&
            date.day == _customStartDate!.day;
      }).toList();
    }
    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FF85).withOpacity(0.03),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 140, // Augmenté pour accueillir les filtres
                floating: true,
                pinned: true,
                backgroundColor: Colors.black.withOpacity(0.8),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      color: _activeFilter == "Précis"
                          ? const Color(0xFF00FF85)
                          : Colors.white54,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF00FF85),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _customStartDate = picked;
                          _activeFilter = "Précis";
                        });
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                  title: const Text(
                    "CRITIQUES & AVIS",
                    style: TextStyle(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF00FF85),
                    ),
                  ),
                  background: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_buildFilterBar(), const SizedBox(height: 10)],
                  ),
                ),
              ),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _reviewsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "Erreur réseau",
                          style: TextStyle(color: Colors.white24),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FF85),
                        ),
                      ),
                    );
                  }

                  final filteredReviews = _applyFilter(snapshot.data!);

                  if (filteredReviews.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "Aucun avis sur cette période",
                          style: TextStyle(color: Colors.white24),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildReviewCard(filteredReviews[index]),
                      childCount: filteredReviews.length,
                    ),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00FF85),
        onPressed: () {
          _editingReviewId = null;
          _reviewController.clear();
          _isAnonymous = false;
          _showAddReviewSheet(context);
        },
        label: const Text(
          "EXPRIMER UN AVIS",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        icon: const Icon(Icons.add_comment_rounded, color: Colors.black),
      ),
    );
  }

  // --- WIDGET BARRE DE FILTRE INTERACTIVE ---
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: ["Tous", "7 jours", "30 jours"].map((filter) {
          bool isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) => setState(() => _activeFilter = filter),
              backgroundColor: Colors.white12,
              selectedColor: const Color(0xFF00FF85).withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF00FF85) : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF00FF85)
                    : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    bool isAnon = review['is_anonymous'] ?? false;
    bool isMine = review['user_id'] == currentUserId;

    DateTime createdAt = DateTime.parse(review['created_at']);
    bool canEdit =
        isMine && DateTime.now().difference(createdAt).inMinutes < 30;
    bool isModified = review['updated_at'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white10,
                backgroundImage: (!isAnon && review['user_img_url'] != null)
                    ? NetworkImage(review['user_img_url'])
                    : null,
                child: (isAnon || review['user_img_url'] == null)
                    ? const Icon(Icons.person, size: 16, color: Colors.white30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnon ? "Anonyme" : (review['user_full_name'] ?? "Fan"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatDate(review['created_at']),
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                        if (isModified)
                          const Text(
                            " • modifié",
                            style: TextStyle(
                              color: Color(0xFF00FF85),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMine) ...[
                if (canEdit)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF00FF85),
                      size: 22,
                    ),
                    onPressed: () {
                      _editingReviewId = review['id'];
                      _reviewController.text = review['content'];
                      _isAnonymous = isAnon;
                      _showAddReviewSheet(context);
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _confirmDeletion(context, review['id']),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: _buildContentWithTags(review['content']),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                _editingReviewId == null ? "NOUVEL AVIS" : "MODIFIER L'AVIS",
                style: const TextStyle(
                  color: Color(0xFF00FF85),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Votre analyse...",
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_editingReviewId == null)
                SwitchListTile(
                  title: const Text(
                    "Publier anonymement",
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  value: _isAnonymous,
                  activeThumbColor: const Color(0xFF00FF85),
                  onChanged: (v) => setModalState(() => _isAnonymous = v),
                )
              else
                const SizedBox(height: 20),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF85),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => _handlePublish(context),
                child: Text(
                  _editingReviewId == null ? "PUBLIER" : "METTRE À JOUR",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePublish(BuildContext context) async {
    final text = _reviewController.text.trim();
    if (text.isEmpty) return;
    try {
      if (_editingReviewId == null) {
        final userData = await supabase
            .from('users')
            .select('full_name, img_url')
            .eq('id', currentUserId!)
            .single();
        await supabase.from('reviews').insert({
          'user_id': currentUserId,
          'user_full_name': userData['full_name'],
          'user_img_url': userData['img_url'],
          'content': text,
          'is_anonymous': _isAnonymous,
        });
      } else {
        await supabase
            .from('reviews')
            .update({'content': text})
            .eq('id', _editingReviewId!);
      }
      _reviewController.clear();
      _editingReviewId = null;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Action impossible.")));
    }
  }

  void _confirmDeletion(BuildContext context, dynamic reviewId) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Supprimer ?",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ANNULER"),
            ),
            TextButton(
              onPressed: () async {
                await supabase.from('reviews').delete().eq('id', reviewId);
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                "OUI",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildContentWithTags(String content) {
    List<TextSpan> spans = [];
    content.split(" ").forEach((word) {
      bool isTag = word.startsWith("@");
      spans.add(
        TextSpan(
          text: "$word ",
          style: TextStyle(
            color: isTag ? const Color(0xFF00FF85) : Colors.white70,
            fontWeight: isTag ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    });
    return spans;
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.day}/${dt.month} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
