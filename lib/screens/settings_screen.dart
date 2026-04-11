import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// Importation des fichiers secondaires (Assurez-vous que les noms correspondent à vos fichiers)
// import 'personal_info_form.dart';
// import 'certification_screen.dart';
// import 'security_form.dart';

// -------------------------------------------------------------------------
// FONCTION GLOBALE : OUVERTURE EXTERNE (WHATSAPP / MAIL)
// -------------------------------------------------------------------------
Future<void> _launchExternalApp(String urlString) async {
  final Uri url = Uri.parse(urlString);
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    debugPrint("Erreur de lancement : $urlString");
  }
}

// -------------------------------------------------------------------------
// 1. ÉCRAN PRINCIPAL : PARAMÈTRES
// -------------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint("Erreur déconnexion: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "PARAMÈTRES",
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 2,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildGroup(context, "COMPTE", [
            _tile(
              context,
              Icons.person_outline,
              "Informations personnelles",
              const PersonalInfoForm(),
            ),
            _tile(
              context,
              Icons.verified_user_outlined,
              "Badge de certification",
              const CertificationScreen(),
            ),
            _tile(
              context,
              Icons.lock_outline,
              "Mot de passe et sécurité",
              const SecurityForm(),
            ),
          ]),
          const SizedBox(height: 25),
          _buildGroup(context, "PRÉFÉRENCES & SUPPORT", [
            _tile(context, Icons.language, "Langue", const LanguageSettings()),
            _tile(
              context,
              Icons.payment,
              "Modes de paiement",
              const PaymentSettings(),
            ),
            _tile(
              context,
              Icons.help_outline,
              "Aide et Assistance",
              const SupportScreen(),
            ),
          ]),
          const SizedBox(height: 50),
          _logoutButton(context),
        ],
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: Colors.white24,
      ),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _handleLogout(context),
        child: const Text(
          "Déconnexion",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 2. CONDITIONS GÉNÉRALES D'UTILISATION (CGU)
// -------------------------------------------------------------------------
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "MENTIONS LÉGALES & CGU",
          style: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bienvenue sur FecaApp.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Dernière révision : Février 2026",
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 30),
            _legalSection(
              "ARTICLE 1 : CADRE GÉNÉRAL",
              "Les présentes conditions régissent l'utilisation de FecaApp par l'ensemble des utilisateurs. En accédant à nos services, vous vous engagez à respecter les principes d'intégrité et de transparence de notre communauté.",
            ),
            _legalSection(
              "ARTICLE 2 : PROTECTION DES DONNÉES",
              "La confidentialité est notre priorité. Vos informations personnelles et coordonnées de paiement sont cryptées via Supabase. Seul l'Administrateur de FecaApp dispose des droits d'accès nécessaires pour valider les transactions.",
            ),
            _legalSection(
              "ARTICLE 3 : RESPONSABILITÉ DES UTILISATEURS",
              "Chaque utilisateur est responsable de l'exactitude des informations fournies. FecaApp se réserve le droit de suspendre tout compte présentant des données frauduleuses ou usurpées.",
            ),
            _legalSection(
              "ARTICLE 4 : SYSTÈME DE PAIEMENT",
              "FecaApp s'appuie sur les protocoles sécurisés MTN MoMo et Orange Money au Cameroun. Les données de retrait saisies sont définitives et verrouillées pour votre sécurité.",
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                "Pour toute question relative à ces conditions, contactez le département juridique à : fecaapp1@gmail.com",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _legalSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 3. SUPPORT CLIENT
// -------------------------------------------------------------------------
class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Support FecaApp",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Une assistance dédiée",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Nos conseillers vous répondent dans les plus brefs délais.",
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 30),
            _contactCard(
              Icons.chat_outlined,
              "WhatsApp Officiel",
              "+237 656 678 841",
              Colors.green,
              () => _launchExternalApp("https://wa.me/237656678841"),
            ),
            _contactCard(
              Icons.mail_outline,
              "Email Assistance",
              "fecaapp1@gmail.com",
              Colors.blue,
              () => _launchExternalApp(
                "mailto:fecaapp1@gmail.com?subject=Assistance FecaApp",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(
    IconData i,
    String t,
    String s,
    Color c,
    VoidCallback onTap,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Icon(i, color: c),
      title: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        s,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      trailing: const Icon(Icons.open_in_new, size: 14, color: Colors.white24),
    ),
  );
}

// -------------------------------------------------------------------------
// 4. PAGES SECONDAIRES & LOGIQUE (CONNECTÉES SUPABASE)
// -------------------------------------------------------------------------
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text(
        "Aide & Support",
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: ListView(
      children: [
        _sTile(
          context,
          Icons.support_agent,
          "Contacter le support",
          const ContactSupportScreen(),
        ),
        _sTile(
          context,
          Icons.gavel,
          "Conditions d'utilisation",
          const TermsScreen(),
        ),
      ],
    ),
  );

  Widget _sTile(BuildContext ctx, IconData i, String t, Widget p) => ListTile(
    leading: Icon(i, color: Colors.greenAccent),
    title: Text(t, style: const TextStyle(color: Colors.white)),
    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => p)),
  );
}

class PaymentSettings extends StatelessWidget {
  const PaymentSettings({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text("Paiements", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "MÉTHODES ACTIVES",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        _pTile("MTN Mobile Money", Colors.yellow),
        _pTile("Orange Money", Colors.orange),
        const SizedBox(height: 30),
        const Text(
          "BIENTÔT DISPONIBLES",
          style: TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        _lTile(Icons.account_balance, "Compte Bancaire"),
        _lTile(Icons.credit_card, "PayPal"),
      ],
    ),
  );

  Widget _pTile(String t, Color c) => ListTile(
    leading: Icon(Icons.phone_android, color: c),
    title: Text(t, style: const TextStyle(color: Colors.white)),
    trailing: const Icon(
      Icons.check_circle,
      color: Colors.greenAccent,
      size: 18,
    ),
  );

  Widget _lTile(IconData i, String t) => ListTile(
    leading: Icon(i, color: Colors.white10),
    title: Text(t, style: const TextStyle(color: Colors.white10)),
  );
}

// --- INFORMATIONS PERSONNELLES (VERROUILLAGE DÉFINITIF SUPABASE) ---
class PersonalInfoForm extends StatefulWidget {
  const PersonalInfoForm({super.key});
  @override
  State<PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<PersonalInfoForm> {
  final _supabase = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _withdrawalPin = TextEditingController();

  bool _isLocked = false;
  bool _isLoading = true;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final data = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();
    setState(() {
      _name.text = data['full_name'] ?? "";
      _email.text = user.email ?? "";
      _phone.text = data['withdrawal_phone'] ?? "";
      _dob.text = data['birth_date'] ?? "";
      _withdrawalPin.text = data['withdrawal_pin'] ?? "";
      _isLocked = data['is_profile_locked'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveAndLock() async {
    if (_phone.text.length < 9 || _withdrawalPin.text.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Numéro ou PIN incomplet")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      await _supabase
          .from('users')
          .update({
            'full_name': _name.text,
            'withdrawal_phone': _phone.text,
            'birth_date': _dob.text,
            'withdrawal_pin': _withdrawalPin.text,
            'is_profile_locked': true, // Verrouillage définitif
          })
          .eq('id', user!.id);

      setState(() {
        _isLocked = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Données enregistrées et verrouillées.")),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la sauvegarde")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profil Privé"),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          _input("NOM COMPLET", _name),
          _input("EMAIL", _email, enabled: false), // L'email ne change pas ici

          const SizedBox(height: 10),
          const Text(
            "COORDONNÉES DE RETRAIT",
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              const Text(
                "+237 ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: _input("NUMÉRO DE RETRAIT (9 CHIFFRES)", _phone, max: 9),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              controller: _withdrawalPin,
              enabled: !_isLocked,
              maxLength: 4,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: _isLocked ? Colors.white24 : Colors.white,
              ),
              decoration: InputDecoration(
                labelText: "CODE PIN DE RETRAIT (4 CHIFFRES)",
                counterText: "",
                labelStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white24,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
              ),
            ),
          ),

          _input("DATE DE NAISSANCE (JJMMAAAA)", _dob, max: 8),
          const SizedBox(height: 40),

          if (_isLocked)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Profil verrouillé. Contactez le service client FecaApp pour toute modification.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveAndLock,
              child: const Text(
                "ENREGISTRER",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController ctrl, {
    int? max,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: ctrl,
      enabled: enabled && !_isLocked,
      maxLength: max,
      keyboardType: max != null ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: (enabled && !_isLocked) ? Colors.white : Colors.white24,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
    ),
  );
}

// --- MOT DE PASSE ET SÉCURITÉ (LOGIQUE 30 JOURS) ---
class SecurityForm extends StatefulWidget {
  const SecurityForm({super.key});
  @override
  State<SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends State<SecurityForm> {
  final _supabase = Supabase.instance.client;
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  Future<void> _updatePassword() async {
    if (_newPass.text != _confirmPass.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      // Vérification SQL de la date (via RPC ou calcul local)
      final userData = await _supabase
          .from('users')
          .select('last_password_change')
          .eq('id', user!.id)
          .single();
      DateTime lastChange = DateTime.parse(userData['last_password_change']);

      if (DateTime.now().difference(lastChange).inDays < 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous ne pouvez changer de mot de passe qu'une fois tous les 30 jours.",
            ),
          ),
        );
        return;
      }

      await _supabase.auth.updateUser(UserAttributes(password: _newPass.text));
      await _supabase
          .from('users')
          .update({'last_password_change': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mot de passe mis à jour !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la mise à jour.")),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Supprimer le compte ?",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          "Cette action est irréversible. Toutes vos données seront effacées.",
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              await _supabase.auth.admin.deleteUser(
                _supabase.auth.currentUser!.id,
              );
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text("Sécurité"),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: ListView(
      padding: const EdgeInsets.all(25),
      children: [
        _passInput("Nouveau mot de passe", _newPass),
        _passInput("Confirmer nouveau mot de passe", _confirmPass),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _updatePassword,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
          child: const Text(
            "CHANGER LE MOT DE PASSE",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 60),
        const Divider(color: Colors.white10),
        ListTile(
          onTap: _confirmDelete,
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: const Text(
            "Supprimer définitivement mon compte",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _passInput(String l, TextEditingController c) => TextField(
    controller: c,
    obscureText: true,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: l,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
    ),
  );
}

// --- LANGUE ---
class LanguageSettings extends StatefulWidget {
  const LanguageSettings({super.key});
  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
  String selected = "Français";
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text("Langue"),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Column(children: [_langTile("Français"), _langTile("English")]),
  );
  Widget _langTile(String lang) => ListTile(
    title: Text(lang, style: const TextStyle(color: Colors.white)),
    trailing: selected == lang
        ? const Icon(Icons.check, color: Colors.greenAccent)
        : null,
    onTap: () => setState(() => selected = lang),
  );
}

// --- BADGE DE CERTIFICATION ---
class CertificationScreen extends StatelessWidget {
  const CertificationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text("Certification"),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 20),
          const Text(
            "DEMANDE DE CERTIFICATION",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Le badge de certification FecaApp permet de prouver l'authenticité de votre profil.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 40),
          const Text(
            "BIENTÔT DISPONIBLES",
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );
}
