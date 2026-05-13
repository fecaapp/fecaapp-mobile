import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onReact;

  const MessageBubble({
    super.key,
    required this.data,
    required this.isMe,
    this.onReply,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = data['created_at'] != null
        ? DateTime.parse(data['created_at']).toLocal()
        : DateTime.now();
    final String time = DateFormat('HH:mm').format(createdAt);
    final bool isRead = data['is_read'] ?? false;
    final bool isEdited = data['is_edited'] ?? false;
    final String? reaction = data['my_reaction'];
    final Map<String, dynamic>? replyTo = data['reply_to'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: reaction != null ? 20 : 10,
          left: isMe ? 60 : 14,
          right: isMe ? 14 : 60,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 270),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMe
                          ? [
                              const Color(0xFF3CFF7E).withOpacity(0.22),
                              const Color(0xFF3CFF7E).withOpacity(0.07),
                            ]
                          : [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.03),
                            ],
                    ),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF3CFF7E).withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge rôle expéditeur
                      if (!isMe && data['sender_badge'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                data['sender_badge'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message cité (réponse)
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: isMe
                                    ? const Color(0xFF3CFF7E)
                                    : Colors.white38,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyTo['author'] ?? 'Lion',
                                style: const TextStyle(
                                  color: Color(0xFF3CFF7E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyTo['content'] ?? '...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                      // Contenu texte
                      _buildRichText(data['content'] ?? ''),

                      // Footer
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEdited)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                "modifié",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.28),
                              fontSize: 9,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 12,
                              color: isRead
                                  ? const Color(0xFF3CFF7E)
                                  : Colors.white24,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Badge réaction
            if (reaction != null)
              Positioned(
                bottom: -14,
                right: isMe ? 8 : null,
                left: isMe ? null : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(reaction, style: const TextStyle(fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichText(String content) {
    final words = content.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final isLast = i == words.length - 1;
      if (w.startsWith('@')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (w.startsWith('#')) {
        spans.add(
          TextSpan(
            text: w + (isLast ? '' : ' '),
            style: const TextStyle(
              color: Color(0xFF3CFF7E),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w + (isLast ? '' : ' ')));
      }
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.45,
          letterSpacing: 0.1,
        ),
        children: spans,
      ),
    );
  }
}
