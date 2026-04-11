import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import direct de Supabase

class UploadCertProScreen extends StatefulWidget {
  const UploadCertProScreen({super.key});

  @override
  State<UploadCertProScreen> createState() => _UploadCertProScreenState();
}

class _UploadCertProScreenState extends State<UploadCertProScreen> {
  File? pickedFile;
  bool uploading = false;

  // Instance Supabase
  final SupabaseClient supabase = Supabase.instance.client;

  // Contrôleurs pour identifier l'organisation
  final TextEditingController orgController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => pickedFile = File(result.files.single.path!));
    }
  }

  // --- LOGIQUE SUPABASE STORAGE + DATABASE ---
  Future<void> _submitProDossier() async {
    if (pickedFile == null || orgController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez remplir les informations et joindre votre licence",
          ),
        ),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Utilisateur non connecté";

      // 1. Upload du fichier vers le Storage Supabase
      // Chemin : bucket certifications / user_id / timestamp_nom_fichier
      final fileExtension = pickedFile!.path.split('.').last;
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}.$fileExtension";
      final filePath = "${user.id}/$fileName";

      await supabase.storage
          .from('certifications')
          .upload(
            filePath,
            pickedFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // 2. Récupération de l'URL publique du fichier
      final String publicUrl = supabase.storage
          .from('certifications')
          .getPublicUrl(filePath);

      // 3. Enregistrement dans la table SQL 'certifications'
      await supabase.from('certifications').insert({
        'user_id': user.id,
        'proof_document_url': publicUrl,
        'status': 'pending',
        'diploma_type': 'PRO_LICENSE',
        'institution': orgController.text.trim(),
        // Note: licenseController peut être stocké dans une autre colonne ou métadonnées si besoin
      });

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(
          Icons.access_time_filled,
          color: Colors.blueAccent,
          size: 60,
        ),
        content: const Text(
          "Dossier professionnel soumis ! ✅\n\nNos administrateurs vérifient vos accréditations. Votre accès complet sera activé dans les 30 minutes maximum.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                "D'ACCORD",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.verified_user, color: Colors.blueAccent, size: 80),
            const SizedBox(height: 20),
            const Text(
              "ESPACE PROFESSIONNEL",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Agents, Clubs et Journalistes doivent valider leur identité pour accéder aux outils de scouting.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 40),

            _buildInputLabel("NOM DE L'ORGANISATION / CLUB"),
            _buildTextField(
              orgController,
              "Ex: Manchester United, FIFA, France Football...",
              Icons.business,
            ),

            const SizedBox(height: 25),
            _buildInputLabel("NUMÉRO DE LICENCE / CARTE PRESSE"),
            _buildTextField(licenseController, "Numéro officiel...", Icons.tag),

            const SizedBox(height: 35),
            _buildInputLabel("JUSTIFICATIF (PDF, JPG, PNG)"),
            const SizedBox(height: 10),
            _buildUploadZone(),

            const SizedBox(height: 50),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF111111),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickDocument,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: pickedFile != null ? Colors.blueAccent : Colors.white10,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              color: pickedFile != null ? Colors.blueAccent : Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              pickedFile == null
                  ? "Cliquer pour joindre votre document"
                  : "Fichier prêt : ${pickedFile!.path.split('/').last}",
              style: TextStyle(
                color: pickedFile != null ? Colors.blueAccent : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: uploading ? null : _submitProDossier,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: uploading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              "ENVOYER POUR VALIDATION",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }
}
