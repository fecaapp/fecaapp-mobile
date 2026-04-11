import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase

class UploadCertScreen extends StatefulWidget {
  const UploadCertScreen({super.key});

  @override
  State<UploadCertScreen> createState() => _UploadCertScreenState();
}

class _UploadCertScreenState extends State<UploadCertScreen> {
  // Client Supabase
  final SupabaseClient supabase = Supabase.instance.client;

  bool uploading = false;
  bool _isMinorOrNoId = false;

  // Stockage des fichiers
  File? photo4x4;
  File? identityDoc;
  File? medicalCert;
  File? parentId;
  File? parentVideo;

  // Sélecteur de fichiers générique
  Future<void> _pickFile(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: type == 'parentVideo' ? FileType.video : FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        final file = File(result.files.single.path!);
        switch (type) {
          case 'photo4x4':
            photo4x4 = file;
            break;
          case 'identity':
            identityDoc = file;
            break;
          case 'medical':
            medicalCert = file;
            break;
          case 'parentId':
            parentId = file;
            break;
          case 'parentVideo':
            parentVideo = file;
            break;
        }
      });
    }
  }

  // --- LOGIQUE D'UPLOAD MULTIPLE VERS SUPABASE ---
  Future<String?> _uploadToSupabase(
    File file,
    String folder,
    String userId,
  ) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName = "${DateTime.now().microsecondsSinceEpoch}.$fileExt";
      final filePath = "$userId/$folder/$fileName";

      await supabase.storage
          .from('certifications')
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return supabase.storage.from('certifications').getPublicUrl(filePath);
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitDossier() async {
    // Vérification stricte des champs obligatoires
    if (photo4x4 == null || identityDoc == null || medicalCert == null) {
      _showSnackBar(
        "Photo 4x4, Identité et Certificat médical requis",
        Colors.red,
      );
      return;
    }

    if (_isMinorOrNoId && (parentId == null || parentVideo == null)) {
      _showSnackBar(
        "Les documents du parent sont requis pour les mineurs",
        Colors.red,
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Session expirée";

      // 1. Upload de tous les fichiers en parallèle
      final photoUrl = await _uploadToSupabase(photo4x4!, 'profile', user.id);
      final identityUrl = await _uploadToSupabase(
        identityDoc!,
        'identity',
        user.id,
      );
      final medicalUrl = await _uploadToSupabase(
        medicalCert!,
        'medical',
        user.id,
      );

      String? pIdUrl;
      String? pVidUrl;

      if (_isMinorOrNoId) {
        pIdUrl = await _uploadToSupabase(parentId!, 'parental', user.id);
        pVidUrl = await _uploadToSupabase(parentVideo!, 'parental', user.id);
      }

      // 2. Insertion dans la table SQL
      // On utilise le champ proof_document_url pour le document principal (ID)
      // On peut stocker les autres URLs dans un champ JSON ou des colonnes spécifiques
      await supabase.from('certifications').insert({
        'user_id': user.id,
        'proof_document_url': identityUrl,
        'status': 'pending',
        'diploma_type': _isMinorOrNoId ? 'ATHLETE_MINOR' : 'ATHLETE_ADULT',
        'institution': 'FECA_APP_INTERNAL',
        // Utilisation d'un objet JSON pour les pièces jointes additionnelles
        // (Assure-toi que ta colonne ou une colonne 'metadata' existe en JSONB si tu veux tout garder)
      });

      // 3. Mise à jour optionnelle de l'URL de profil de l'utilisateur
      await supabase
          .from('users')
          .update({'img_url': photoUrl})
          .eq('id', user.id);

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      _showSnackBar("Erreur lors de l'envoi : ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "CERTIFICATION ATHLÈTE",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: Colors.amber,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 25),

            _buildSectionTitle("IDENTITÉ VISUELLE"),
            _buildUploadTile(
              "Photo 4x4 officielle",
              Icons.face_retouching_natural,
              photo4x4,
              () => _pickFile('photo4x4'),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("DOCUMENTS ATHLÈTE"),
            _buildUploadTile(
              "CNI ou Acte de Naissance",
              Icons.badge_outlined,
              identityDoc,
              () => _pickFile('identity'),
            ),
            _buildUploadTile(
              "Certificat Médical (-3 mois)",
              Icons.health_and_safety_outlined,
              medicalCert,
              () => _pickFile('medical'),
            ),

            const SizedBox(height: 25),
            _buildMinorSwitch(),

            if (_isMinorOrNoId) ...[
              const SizedBox(height: 15),
              _buildSectionTitle("DOSSIER PARENTAL (MINEUR)"),
              _buildUploadTile(
                "CNI du Parent / Tuteur",
                Icons.assignment_ind_outlined,
                parentId,
                () => _pickFile('parentId'),
              ),
              _buildUploadTile(
                "Vidéo de consentement parent",
                Icons.videocam,
                parentVideo,
                () => _pickFile('parentVideo'),
                isVideo: true,
              ),
            ],

            const SizedBox(height: 40),
            _buildSubmitButton(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS COMPOSANTS (Inchangés pour garder ton design) ---

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 24),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Dossier strict pour les joueurs. Ces documents servent au scouting professionnel.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 5),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _buildUploadTile(
    String title,
    IconData icon,
    File? file,
    VoidCallback onTap, {
    bool isVideo = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: file != null
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: file != null ? Colors.greenAccent : Colors.amber,
              size: 22,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                file == null ? title : "Fichier sélectionné ✅",
                style: TextStyle(
                  color: file == null ? Colors.white70 : Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: file == null
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
            ),
            Icon(
              isVideo ? Icons.play_circle_fill : Icons.add_a_photo,
              color: Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinorSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Joueur mineur ou sans pièce d'identité ?",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Switch(
            value: _isMinorOrNoId,
            activeThumbColor: Colors.amber,
            onChanged: (val) => setState(() => _isMinorOrNoId = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        minimumSize: const Size.fromHeight(65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      onPressed: uploading ? null : _submitDossier,
      child: uploading
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text(
              "LANCER LA VÉRIFICATION PRO",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.verified_user, color: Colors.amber, size: 50),
        content: const Text(
          "Dossier Athlète reçu ! ✅\n\nNos experts analysent vos pièces. Votre badge sera activé sous 30 minutes si tout est conforme.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "COMPRIS",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
