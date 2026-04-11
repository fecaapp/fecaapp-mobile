import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String currentUserId;
  const MessagesScreen({super.key, required this.currentUserId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<dynamic> privateConvs = [];
  List<dynamic> myGroups = [];
  List<dynamic> discoverGroups = [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchPrivateConvs(), _fetchMyGroups()]);
      await _fetchDiscoverGroups();
    } catch (e) {
      debugPrint("Erreur de chargement : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RÉCUPÉRATION DES DONNÉES ---

  Future<void> _fetchPrivateConvs() async {
    final response = await supabase
        .from('messages')
        .select(
          '*, sender:sender_id(full_name, img_url, is_certified), receiver:receiver_id(full_name, img_url, is_certified)',
        )
        .or(
          'sender_id.eq.${widget.currentUserId},receiver_id.eq.${widget.currentUserId}',
        )
        .isFilter('group_id', null)
        .order('created_at', ascending: false);

    final Map<String, dynamic> unique = {};
    for (var m in response) {
      final partnerId = m['sender_id'] == widget.currentUserId
          ? m['receiver_id']
          : m['sender_id'];
      if (partnerId != null && !unique.containsKey(partnerId)) {
        unique[partnerId] = m;
      }
    }
    setState(() => privateConvs = unique.values.toList());
  }

  Future<void> _fetchMyGroups() async {
    final response = await supabase
        .from('group_members')
        .select('role, group_id, groups(*)')
        .eq('user_id', widget.currentUserId)
        .inFilter('role', ['MEMBER', 'ADMIN']);

    setState(() => myGroups = response);
  }

  Future<void> _fetchDiscoverGroups() async {
    final response = await supabase.from('groups').select('*').limit(20);
    final myGroupIds = myGroups.map((g) => g['group_id']).toList();

    setState(() {
      discoverGroups = response
          .where((g) => !myGroupIds.contains(g['id']))
          .toList();
    });
  }

  // --- ACTIONS ---

  void _shareInvite(String? inviteCode) {
    if (inviteCode == null) return;
    final link = "lionapp://join/$inviteCode";
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Lien de la Tribu copié ! 🦁",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF00FF85),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _joinRequest(String groupId) async {
    try {
      await supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': widget.currentUserId,
        'role': 'PENDING',
      });
      _refreshAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Demande envoyée au chef !"),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tu as déjà postulé !")));
    }
  }

  // --- CONSTRUCTION UI ---

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            "RUGISSEMENTS",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF00FF85),
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.group_add_rounded,
                color: Color(0xFF00FF85),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              ).then((_) => _refreshAll()),
            ),
            const SizedBox(width: 10),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00FF85),
            labelColor: Color(0xFF00FF85),
            unselectedLabelColor: Colors.white24,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "MESSAGES"),
              Tab(text: "TRIBUS"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF85)),
              )
            : TabBarView(
                children: [_buildMessagesList(), _buildTribesSection()],
              ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (privateConvs.isEmpty) return _emptyState("Aucune discussion privée.");
    return ListView.builder(
      itemCount: privateConvs.length,
      itemBuilder: (context, index) {
        final conv = privateConvs[index];
        final partner = conv['sender_id'] == widget.currentUserId
            ? conv['receiver']
            : conv['sender'];
        if (partner == null) return const SizedBox.shrink();

        return ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatName: partner['full_name'] ?? "Lion",
                targetId: (conv['sender_id'] == widget.currentUserId
                    ? conv['receiver_id']
                    : conv['sender_id']),
                currentUserId: widget.currentUserId,
                isGroup: false,
              ),
            ),
          ),
          leading: _avatar(
            partner['img_url'],
            partner['is_certified'] ?? false,
            false,
          ),
          title: Text(
            partner['full_name'] ?? "Lion",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            conv['content'] ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white24),
          ),
          trailing: Text(
            DateFormat(
              'HH:mm',
            ).format(DateTime.parse(conv['created_at']).toLocal()),
            style: const TextStyle(color: Colors.white10, fontSize: 10),
          ),
        );
      },
    );
  }

  Widget _buildTribesSection() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _sectionHeader("Mes Tribus Suivies"),
        if (myGroups.isEmpty)
          const _EmptyHint("Rejoins une tribu pour commencer."),
        ...myGroups.map((g) => _tribeTile(g['groups'], true)),
        const Divider(
          color: Colors.white10,
          height: 40,
          indent: 20,
          endIndent: 20,
        ),
        _sectionHeader("Découvrir de nouvelles Tribus"),
        if (discoverGroups.isEmpty)
          const _EmptyHint("Aucune tribu disponible."),
        ...discoverGroups.map((g) => _tribeTile(g, false)),
      ],
    );
  }

  Widget _tribeTile(dynamic group, bool isMember) {
    if (group == null) return const SizedBox.shrink();

    // LOGIQUE DE COMPTAGE : Si on est membre et que Supabase dit 0, on affiche au moins 1
    int count = group['members_count'] ?? 0;
    if (isMember && count == 0) count = 1;

    return ListTile(
      leading: _avatar(group['image_url'], false, true),
      title: Text(
        group['name'] ?? "Tribu sans nom",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        "$count membre${count > 1 ? 's' : ''}",
        style: const TextStyle(color: Colors.white24, fontSize: 11),
      ),
      trailing: isMember
          ? IconButton(
              icon: const Icon(
                Icons.share_rounded,
                color: Color(0xFF00FF85),
                size: 18,
              ),
              onPressed: () => _shareInvite(group['invite_code']),
            )
          : ElevatedButton(
              onPressed: () => _joinRequest(group['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF85).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "SUIVRE",
                style: TextStyle(
                  color: Color(0xFF00FF85),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      onTap: isMember
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatName: group['name'],
                  targetId: group['id'],
                  currentUserId: widget.currentUserId,
                  isGroup: true,
                ),
              ),
            )
          : null,
    );
  }

  Widget _avatar(String? url, bool isCertified, bool isGroup) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(isGroup ? 14 : 26),
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url.isEmpty
          ? Icon(
              isGroup ? Icons.groups_rounded : Icons.person,
              color: Colors.white10,
            )
          : null,
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF00FF85),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _emptyState(String t) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Text(t, style: const TextStyle(color: Colors.white10)),
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white10, fontSize: 12),
    ),
  );
}
