import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Tes imports d'écrans
import 'screens/auth_screen.dart';

// Tes imports de Providers
import 'providers/museum_provider.dart';

/// --- LE WIDGET DE LA BANNIÈRE ANIMÉE (SLIDE) ---
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final connectivity = snapshot.data;
        // Vérifie si on est hors-ligne
        bool isOffline =
            connectivity != null &&
            connectivity.contains(ConnectivityResult.none);

        // L'animation gère la position : 0 pour afficher, -110 pour cacher
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
          top: isOffline ? 0 : -110,
          left: 0,
          right: 0,
          child: Material(
            elevation: 10,
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    "CONNEXION PERDUE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation des dates (Français)
  await initializeDateFormatting('fr_FR', null);

  // Initialisation Supabase
  await Supabase.initialize(
    url: "https://xmbuqisqmxigdcuivdjc.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtYnVxaXNxbXhpZ2RjdWl2ZGpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5ODkzNDEsImV4cCI6MjA4MTU2NTM0MX0.QZS1y1gwQnTWIFsWw2Jw9NoNL6j0vgUmufjwul88T3g",
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MuseumProvider())],
      child: const FecaApp(),
    ),
  );
}

class FecaApp extends StatelessWidget {
  const FecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FecaApp',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
      ),

      // GESTION DE LA BANNIÈRE GLOBALE SUR TOUTE L'APP
      builder: (context, child) {
        return Stack(
          children: [
            child!, // L'application (Splash, Auth, etc.)
            const ConnectivityBanner(), // La bannière animée par-dessus
          ],
        );
      },

      home: const SplashScreen(),
    );
  }
}

/// ================= SPLASH MEDIA SPORT MODERNE =================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo_fecaapp.png',
                  width: 140,
                  height: 140,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.sports_soccer,
                    size: 100,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "FecaApp",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Actu • Scores • Talents",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.1,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
