import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawalScreen extends StatefulWidget {
  final double amount;
  const WithdrawalScreen({super.key, required this.amount});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _supabase = Supabase.instance.client;

  // Contrôleurs (Le numéro sera pré-rempli et bloqué)
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  String selectedOperator = "MTN MoMo";
  bool isProcessing = false;
  bool isLoadingData = true;
  String? correctPin; // Récupéré de la base pour vérification

  @override
  void initState() {
    super.initState();
    _loadUserWithdrawalData();
  }

  // RÉCUPÉRATION DES INFOS VERROUILLÉES DANS SETTINGS
  Future<void> _loadUserWithdrawalData() async {
    try {
      final user = _supabase.auth.currentUser;
      final data = await _supabase
          .from('users')
          .select('withdrawal_phone, withdrawal_pin')
          .eq('id', user!.id)
          .single();

      setState(() {
        _phoneController.text = data['withdrawal_phone'] ?? "";
        correctPin = data['withdrawal_pin'];
        isLoadingData = false;
      });
    } catch (e) {
      setState(() => isLoadingData = false);
      debugPrint("Erreur de chargement: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "RETRAIT SÉCURISÉ",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BOX RÉCAPITULATIF MONTANT ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const Text(
                    "MONTANT DISPONIBLE",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${widget.amount.toInt()} FCFA",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),
            _sectionTitle("1. CHOISIR L'OPÉRATEUR"),
            const SizedBox(height: 15),

            Row(
              children: [
                _operatorTile("MTN MoMo", Colors.yellow[700]!),
                const SizedBox(width: 15),
                _operatorTile("Orange Money", Colors.orange[800]!),
              ],
            ),

            const SizedBox(height: 35),
            _sectionTitle("2. COORDONNÉES DE RÉCEPTION (VERROUILLÉES)"),
            const SizedBox(height: 20),

            // --- CHAMP NUMÉRO (GRISÉ / IMPOSSIBLE À MODIFIER ICI) ---
            _buildLockedField(
              "Numéro de réception (+237)",
              _phoneController,
              Icons.lock_outline,
            ),

            const SizedBox(height: 25),
            _sectionTitle("3. SÉCURITÉ"),
            const SizedBox(height: 15),

            // --- CHAMP PIN DE RETRAIT ---
            _buildPinField(),

            const SizedBox(height: 35),

            // --- AVERTISSEMENT ---
            _buildWarningBox(),

            const SizedBox(height: 40),

            // --- BOUTON DE VALIDATION ---
            _buildSubmitButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLockedField(
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: ctrl,
        readOnly: true, // Empêche la modification
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          border: InputBorder.none,
          suffixIcon: Icon(icon, color: Colors.white10, size: 18),
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _pinController,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      style: const TextStyle(
        color: Colors.greenAccent,
        fontSize: 24,
        letterSpacing: 10,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: "ENTREZ VOTRE PIN DE RETRAIT",
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        counterText: "",
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.greenAccent),
        ),
      ),
    );
  }

  Widget _operatorTile(String name, Color color) {
    bool isSelected = selectedOperator == name;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedOperator = name),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.1)
                : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? color : Colors.white10,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: isSelected ? color : Colors.white24,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.security, color: Colors.greenAccent, size: 20),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Le numéro de retrait ne peut être modifié que par le support FecaApp. Validation sous 24h.",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: isProcessing ? null : _validateAndSubmit,
        child: isProcessing
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text(
                "VALIDER LE RETRAIT",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  // --- LOGIQUE DE VALIDATION ---

  void _validateAndSubmit() {
    if (_phoneController.text.isEmpty) {
      _showError(
        "Veuillez d'abord configurer votre numéro dans les paramètres.",
      );
      return;
    }
    if (_pinController.text != correctPin) {
      _showError("Code PIN de retrait incorrect.");
      return;
    }

    setState(() => isProcessing = true);

    // Simulation d'enregistrement de la demande dans Supabase
    // Dans une version réelle, tu ferais un insert dans une table 'withdrawals'
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => isProcessing = false);
      _showSuccess();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.greenAccent, size: 70),
            const SizedBox(height: 20),
            const Text(
              "DEMANDE ENVOYÉE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Votre demande est en cours de traitement. L'administrateur valide l'envoi vers votre numéro enregistré.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  "TERMINER",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
