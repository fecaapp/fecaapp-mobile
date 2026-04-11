import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import direct de Supabase

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? pickedFile;
  bool uploading = false;

  // Instance Supabase
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController diplomaController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();

  @override
  void dispose() {
    diplomaController.dispose();
    institutionController.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => pickedFile = File(result.files.single.path!));
    }
  }

  // --- LOGIQUE D'UPLOAD SUPABASE ---
  Future<void> doUpload() async {
    if (pickedFile == null ||
        diplomaController.text.isEmpty ||
        institutionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Session utilisateur introuvable";

      // 1. Upload du fichier dans le dossier 'supporters' du bucket certifications
      final fileExtension = pickedFile!.path.split('.').last;
      final fileName =
          "supporter_${DateTime.now().millisecondsSinceEpoch}.$fileExtension";
      final filePath = "${user.id}/supporters/$fileName";

      await supabase.storage
          .from('certifications')
          .upload(
            filePath,
            pickedFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // 2. Récupération de l'URL publique
      final String publicUrl = supabase.storage
          .from('certifications')
          .getPublicUrl(filePath);

      // 3. Insertion dans la table 'certifications'
      await supabase.from('certifications').insert({
        'user_id': user.id,
        'proof_document_url': publicUrl,
        'status': 'pending',
        'diploma_type': diplomaController.text.trim(), // ex: CNI
        'institution': institutionController.text.trim(), // ex: Numéro de pièce
      });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(
            Icons.access_time_filled,
            color: Colors.amber,
            size: 60,
          ),
          content: const Text(
            "Document soumis avec succès ! ✅\n\nVotre compte supporter sera certifié dans les 30 minutes maximum.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "D'ACCORD",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'CERTIFICATION SUPPORTER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.amber,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Colors.amber,
                    size: 28,
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Vérification d'identité pour les fans. Fournissez une pièce officielle.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            _buildLabel("TYPE DE DOCUMENT"),
            const SizedBox(height: 10),
            _buildTextField(
              diplomaController,
              'Ex: CNI, Passeport...',
              Icons.badge,
            ),
            const SizedBox(height: 20),
            _buildLabel("NUMÉRO OU RÉFÉRENCE"),
            const SizedBox(height: 10),
            _buildTextField(
              institutionController,
              'Numéro de pièce...',
              Icons.tag,
            ),
            const SizedBox(height: 35),
            _buildLabel("PREUVE NUMÉRIQUE"),
            const SizedBox(height: 15),
            _buildFilePicker(),
            const SizedBox(height: 45),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w900,
      color: Colors.white38,
      fontSize: 11,
      letterSpacing: 1,
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
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return GestureDetector(
      onTap: pickFile,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.greenAccent.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
          color: Colors.greenAccent.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.file_present_rounded,
              size: 40,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 10),
            Text(
              pickedFile == null
                  ? 'Choisir un fichier (PDF, JPG, PNG)'
                  : 'Fichier prêt !',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: uploading ? null : doUpload,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        backgroundColor: Colors.greenAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: uploading
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text(
              'ACTIVER MON COMPTE CERTIFIÉ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
    );
  }
}
