import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data; // On passe l'objet complet de la DB
  final bool isMe;

  const MessageBubble({super.key, required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Formatage de l'heure réelle
    final DateTime createdAt = data['createdAt'] != null
        ? DateTime.parse(data['createdAt'])
        : DateTime.now();
    final String formattedTime = DateFormat('HH:mm').format(createdAt);

    // Statuts de lecture (Triple Check)
    final String status = data['status'] ?? 'SENT';
    final bool isEdited = data['isEdited'] ?? false;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isMe ? 60 : 15,
          right: isMe ? 15 : 60,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Bulle Glassmorphism
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMe
                          ? [
                              Colors.greenAccent.withOpacity(0.18),
                              Colors.greenAccent.withOpacity(0.06),
                            ]
                          : [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.04),
                            ],
                    ),
                    border: Border.all(
                      color: isMe
                          ? Colors.greenAccent.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge du Lion pour les autres participants
                      if (!isMe && data['senderBadge'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            data['senderBadge'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      Text(
                        data['content'] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Footer : Heure + Édition + Checkmarks
            _buildFooter(formattedTime, status, isEdited),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(String time, String status, bool isEdited) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEdited) ...[
            const Text(
              "modifié",
              style: TextStyle(
                color: Colors.white12,
                fontSize: 8,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            time,
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9),
          ),
          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(status)],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'DELIVERED':
        icon = Icons.done_all_rounded;
        color = Colors.white38;
        break;
      case 'READ':
        icon = Icons.done_all_rounded;
        color = Colors.greenAccent;
        break;
      default: // SENT
        icon = Icons.done_rounded;
        color = Colors.white24;
    }

    return Icon(icon, size: 12, color: color);
  }
}
