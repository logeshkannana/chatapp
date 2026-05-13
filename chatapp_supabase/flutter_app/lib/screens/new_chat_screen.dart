// ════════ new_chat_screen.dart ════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../models/models.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final users = await context.read<UserService>()
        .getAllUsers(auth.currentUserId ?? '');
    setState(() { _users = users; _loading = false; });
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) { _loadUsers(); return; }
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final results = await context.read<UserService>()
        .searchUsers(q, auth.currentUserId ?? '');
    setState(() { _users = results; _loading = false; });
  }

  Future<void> _startChat(UserModel user) async {
    final auth = context.read<AuthService>();
    final chatId = await context.read<ChatService>()
        .getOrCreateChat(auth.currentUserId!, user.id);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChatScreen(otherUser: user, chatId: chatId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Chat',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search by name...',
              prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? Center(child: Text('No users found',
                      style: GoogleFonts.nunito(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF00897B),
                            backgroundImage: u.profileImageUrl.isNotEmpty
                                ? NetworkImage(u.profileImageUrl) : null,
                            child: u.profileImageUrl.isEmpty
                                ? Text(u.name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(u.name,
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(u.status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          trailing: u.isOnline
                              ? Container(
                                  width: 10, height: 10,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle))
                              : null,
                          onTap: () => _startChat(u),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
