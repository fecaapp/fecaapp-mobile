import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/museum_provider.dart';
// Note : Décommente ceci quand ton AuthProvider sera prêt
// import '../providers/auth_provider.dart';

class QuizGameScreen extends StatefulWidget {
  final int sessionNumber;
  const QuizGameScreen({super.key, required this.sessionNumber});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  int currentQuestionIndex = 0;
  int score = 0;
  int? selectedIndex;
  Timer? _timer;
  int _secondsLeft = 15;
  bool _isAnswered = false;
  bool _showBadge = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 15;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _handleTimeout();
        }
      });
    });
  }

  void _handleTimeout() => _checkAnswer(-1);

  void _checkAnswer(int index) {
    if (_isAnswered) return;
    _timer?.cancel();

    final questions = context.read<MuseumProvider>().quizQuestions;

    // Correction Robuste : Extraction sécurisée de l'index correct depuis le JSONB de Supabase
    final dynamic rawCorrectIndex =
        questions[currentQuestionIndex]['correct_index']; // Corrigé pour matcher le SQL (correct_index)
    final int correctIndex = rawCorrectIndex is int
        ? rawCorrectIndex
        : int.tryParse(rawCorrectIndex.toString()) ?? 0;

    setState(() {
      _isAnswered = true;
      selectedIndex = index;
      if (index == correctIndex) score++;
    });

    // Temps de pause pour voir la correction (Vert/Rouge)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (currentQuestionIndex < questions.length - 1) {
        setState(() {
          currentQuestionIndex++;
          _isAnswered = false;
          selectedIndex = null;
        });
        _startTimer();
      } else {
        _finishQuiz();
      }
    });
  }

  void _finishQuiz() async {
    final museumProvider = context.read<MuseumProvider>();

    // Récupération de l'ID utilisateur réel via Supabase
    final String currentUserId = museumProvider.currentUserId;

    String badgeName = _getBadgeName(widget.sessionNumber);

    // Condition de réussite : 7/10
    if (score >= 7) {
      bool success = await museumProvider.validateQuizSession(
        userId: currentUserId,
        sessionCompleted: widget.sessionNumber,
        badgeName: badgeName,
      );

      if (success) {
        setState(() {
          _showBadge = true;
        });
        _confettiController.play();
      }
    } else {
      _showFailureDialog();
    }
  }

  String _getBadgeName(int session) {
    if (session <= 2) return "Lionceau d'Argile";
    if (session <= 4) return "Guerrier de Bronze";
    if (session <= 6) return "Griffe d'Argent";
    if (session <= 8) return "Légende d'Or";
    if (session == 9) return "Rugissement de Platine";
    return "LION DE DIAMANT";
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "DÉFAITE DANS LA TANIÈRE",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Tu as obtenu $score/10. Un vrai Lion ne renonce jamais. Entraîne-toi et reviens plus fort !",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("RETOUR", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showBadge) return _buildBadgeDiscovery();

    final questions = context.watch<MuseumProvider>().quizQuestions;

    if (questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final q = questions[currentQuestionIndex];
    final List<dynamic> options = q['options'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(questions.length),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Text(
                    q['question'] ?? "",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 30,
              ),
              child: Column(
                children: List.generate(options.length, (index) {
                  final dynamic rawCorrect = q['correct_index']; // Corrigé SQL
                  final int correctIndex = rawCorrect is int
                      ? rawCorrect
                      : int.tryParse(rawCorrect.toString()) ?? 0;

                  return _buildOption(
                    index,
                    options[index].toString(),
                    correctIndex,
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "SÉANCE ${widget.sessionNumber} • ${currentQuestionIndex + 1}/$total",
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsLeft < 5
                  ? Colors.red.withOpacity(0.2)
                  : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$_secondsLeft s",
              style: TextStyle(
                color: _secondsLeft < 5 ? Colors.red : Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int index, String text, int correctIndex) {
    Color borderColor = Colors.white10;
    if (_isAnswered) {
      if (index == correctIndex) {
        borderColor = Colors.green;
      } else if (index == selectedIndex) {
        borderColor = Colors.red;
      }
    }

    return GestureDetector(
      onTap: () => _checkAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isAnswered && index == correctIndex
              ? Colors.green.withOpacity(0.1)
              : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (_isAnswered && index == correctIndex)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            if (_isAnswered && index == selectedIndex && index != correctIndex)
              const Icon(Icons.cancel, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeDiscovery() {
    String badge = _getBadgeName(widget.sessionNumber);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.amber, Colors.green, Colors.red],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "NOUVEAU GRADE ATTEINT",
                style: TextStyle(
                  color: Colors.white60,
                  letterSpacing: 4,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15),
                      blurRadius: 60,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                  size: 140,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                badge.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ta légende s'écrit dans l'histoire.",
                style: TextStyle(color: Colors.white38),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CONTINUER L'AVENTURE",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
