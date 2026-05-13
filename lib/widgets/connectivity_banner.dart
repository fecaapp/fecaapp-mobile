import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY WRAPPER — à utiliser dans MaterialApp.builder
// Enveloppe toute l'app et affiche le banner au-dessus du contenu
//
// Usage dans main.dart :
//   MaterialApp(
//     builder: (context, child) => ConnectivityWrapper(child: child!),
//     ...
//   )
// ═══════════════════════════════════════════════════════════════

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isOffline = false;
  bool _justReconnected = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Vérification initiale
    _checkConnectivity();

    // Écoute les changements en temps réel
    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result.contains(ConnectivityResult.none);
    if (mounted && offline != _isOffline) {
      setState(() => _isOffline = offline);
      offline ? _controller.forward() : _controller.reverse();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);

    if (!mounted) return;

    if (offline && !_isOffline) {
      // Vient de perdre la connexion
      setState(() {
        _isOffline = true;
        _justReconnected = false;
      });
      _controller.forward();
    } else if (!offline && _isOffline) {
      // Vient de retrouver la connexion
      setState(() {
        _isOffline = false;
        _justReconnected = true;
      });
      // Garde le banner "reconnecté" visible 2.5s puis le cache
      _reconnectedTimer?.cancel();
      _reconnectedTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() => _justReconnected = false);
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _subscription?.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Contenu principal de l'app
        widget.child,

        // Banner de connectivité
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _ConnectivityBannerContent(
              isOffline: _isOffline,
              justReconnected: _justReconnected,
              topPadding: topPadding,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONTENU DU BANNER
// ═══════════════════════════════════════════════════════════════

class _ConnectivityBannerContent extends StatelessWidget {
  final bool isOffline;
  final bool justReconnected;
  final double topPadding;

  const _ConnectivityBannerContent({
    required this.isOffline,
    required this.justReconnected,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final bool showReconnected = !isOffline && justReconnected;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + 10,
          bottom: 14,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: showReconnected
              ? const Color(0xFF1A1A1A)
              : const Color(0xFF0D0D0D),
          border: Border(
            bottom: BorderSide(
              color: showReconnected
                  ? Colors.greenAccent.withOpacity(0.4)
                  : Colors.redAccent.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOffline) ...[
              // Indicateur pulsant hors-ligne
              _PulsingDot(color: Colors.redAccent),
              const SizedBox(width: 12),
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  "Connexion perdue — mode hors-ligne",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else if (showReconnected) ...[
              // Reconnecté
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.wifi_rounded,
                color: Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                "Connexion rétablie",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DOT PULSANT — animation hors-ligne
// ═══════════════════════════════════════════════════════════════

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY BANNER — version standalone (usage local dans un écran)
// Si tu veux l'utiliser dans un seul écran au lieu du wrapper global
//
// Usage :
//   Stack(
//     children: [
//       ...ton contenu...
//       const ConnectivityBanner(),
//     ],
//   )
// ═══════════════════════════════════════════════════════════════

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final bool isOffline =
            snapshot.hasData &&
            snapshot.data!.contains(ConnectivityResult.none);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          top: isOffline ? 0 : -(MediaQuery.of(context).padding.top + 70),
          left: 0,
          right: 0,
          child: _ConnectivityBannerContent(
            isOffline: isOffline,
            justReconnected: false,
            topPadding: MediaQuery.of(context).padding.top,
          ),
        );
      },
    );
  }
}
