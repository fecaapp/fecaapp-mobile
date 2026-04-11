import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final connectivity = snapshot.data;

        // On vérifie si l'utilisateur est hors-ligne
        // (La liste contient ConnectivityResult.none si aucune connexion n'est active)
        bool isOffline =
            connectivity != null &&
            connectivity.contains(ConnectivityResult.none);

        // AnimatedPositioned permet de faire glisser le widget
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500), // Vitesse de l'animation
          curve: Curves.fastOutSlowIn, // Courbe d'animation fluide
          top: isOffline
              ? 0
              : -110, // Si hors-ligne -> 0 (visible), sinon -> -110 (caché en haut)
          left: 0,
          right: 0,
          child: Material(
            elevation: 10,
            color:
                Colors.transparent, // On garde le transparent pour le Material
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                // On s'assure que le texte ne soit pas caché par l'encoche (notch) du téléphone
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
