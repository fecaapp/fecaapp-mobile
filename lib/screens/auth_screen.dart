import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as model;
import 'upload_cert_pro_screen.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  String selectedRole = "supporter";
  bool requireCertification = false;
  bool loading = false;
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void updateRole(String? role) {
    if (role == null) return;
    setState(() {
      selectedRole = role;
      requireCertification =
          role == "club" || role == "agent" || role == "journaliste";
    });
  }

  void showMessage(String m, [bool success = true]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: success ? const Color(0xFF00FF85) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- INSCRIPTION ---
  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage("Veuillez remplir tous les champs", false);
      return;
    }

    setState(() => loading = true);
    try {
      // Inscription Auth
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'role': selectedRole},
      );

      if (res.user != null) {
        showMessage('Compte créé ! Connectez-vous maintenant ✅');
        _tabController.animateTo(0); // Bascule vers l'onglet Connexion
        passwordController.clear();
      }
    } on AuthException catch (e) {
      // C'est ici que l'erreur "Database error saving new user" est captée
      showMessage("Erreur d'inscription : ${e.message}", false);
    } catch (e) {
      showMessage('Erreur inattendue : $e', false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- CONNEXION ---
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Identifiants manquants", false);
      return;
    }

    setState(() => loading = true);
    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // On récupère le profil dans la table public.users
        final data = await supabase
            .from('users')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();

        if (data == null) {
          showMessage("Profil introuvable en base de données", false);
          return;
        }

        final loggedInUser = model.User.fromJson(data);

        bool isProRole =
            (loggedInUser.role == "club" ||
            loggedInUser.role == "agent" ||
            loggedInUser.role == "journaliste");

        if (isProRole && !loggedInUser.isCertified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UploadCertProScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(user: loggedInUser)),
          );
        }
      }
    } on AuthException catch (e) {
      showMessage(e.message, false);
    } catch (e) {
      showMessage('Erreur : $e', false);
    } finally {
      if (mounted) setState(() => loading = false);
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
          "FECAAPP",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            letterSpacing: 2,
            color: Color(0xFF00FF85),
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF85),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: "CONNEXION"),
            Tab(text: "INSCRIPTION"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildForm(isLogin: true), _buildForm(isLogin: false)],
      ),
    );
  }

  Widget _buildForm({required bool isLogin}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          if (!isLogin) ...[
            _buildField(nameController, "Nom et prénom", Icons.person),
            const SizedBox(height: 20),
          ],
          _buildField(emailController, "Email", Icons.email),
          const SizedBox(height: 20),
          _buildField(
            passwordController,
            "Mot de passe",
            Icons.lock,
            isPassword: true,
          ),
          if (!isLogin) ...[const SizedBox(height: 30), _buildRoleDropdown()],
          const SizedBox(height: 50),
          _buildSubmitButton(isLogin),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword && !isVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white24,
                ),
                onPressed: () => setState(() => isVisible = !isVisible),
              )
            : null,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF00FF85)),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quel est votre rôle ?",
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
        DropdownButtonFormField<String>(
          initialValue: selectedRole,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: const [
            DropdownMenuItem(value: "supporter", child: Text("Supporter")),
            DropdownMenuItem(value: "joueur", child: Text("Joueur / Talent")),
            DropdownMenuItem(value: "club", child: Text("Club")),
            DropdownMenuItem(value: "agent", child: Text("Agent / Recruteur")),
            DropdownMenuItem(value: "journaliste", child: Text("Journaliste")),
          ],
          onChanged: updateRole,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10),
            ),
          ),
        ),
        if (requireCertification)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              "⚠️ Certification pro requise",
              style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLogin) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: loading ? null : (isLogin ? login : register),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.black)
            : Text(
                isLogin ? "SE CONNECTER" : "CRÉER MON COMPTE",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
