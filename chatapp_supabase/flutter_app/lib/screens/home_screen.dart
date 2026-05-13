import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/story_service.dart';
import '../models/models.dart';
import '../widgets/status_bar.dart';
import '../widgets/story_circle.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'profile_screen.dart';
import 'story_upload_screen.dart';
import 'story_viewer_screen.dart';
import 'auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chatService = context.read<ChatService>();
    final userId = auth.currentUserId ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('ChatApp',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.white)),
        backgroundColor: const Color(0xFF00897B),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewChatScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) async {
              if (v == 'profile') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()));
              } else if (v == 'logout') {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const StatusBar(),
          // Stories section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: FutureBuilder<UserModel?>(
              future: context.read<UserService>().getUserById(userId),
              builder: (context, userSnap) {
                final currentUser = userSnap.data;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Add your story button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AddStoryButton(
                          currentUser: currentUser,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StoryUploadScreen(),
                            ),
                          ),
                        ),
                      ),
                      // Stories from contacts
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: context
                            .read<StoryService>()
                            .getGroupedStories(userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }

                          final groupedStories = snapshot.data ?? [];

                          return Row(
                            children: groupedStories.map((group) {
                              final latestStory =
                                  group['latestStory'] as StoryModel?;
                              final stories =
                                  group['stories'] as List<StoryModel>;

                              if (latestStory?.user == null)
                                return const SizedBox.shrink();

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: StoryCircle(
                                  latestStory: latestStory,
                                  user: latestStory?.user,
                                  storyCount: stories.length,
                                  hasUnviewedStories:
                                      latestStory?.hasViewed != true,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StoryViewerScreen(
                                        stories: stories,
                                        storyUser: latestStory!.user!,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Chats list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getUserChats(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chats = snapshot.data ?? [];
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No conversations yet',
                              style: GoogleFonts.nunito(
                                  fontSize: 18, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Tap + to start chatting!',
                              style: GoogleFonts.nunito(
                                  fontSize: 14, color: Colors.grey[400])),
                        ]),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final otherId = chat['user1_id'] == userId
                        ? chat['user2_id'] as String
                        : chat['user1_id'] as String;
                    final unread = chat['user1_id'] == userId
                        ? (chat['unread_count_user1'] ?? 0)
                        : (chat['unread_count_user2'] ?? 0);
                    final lastMsg = chat['last_message'] ?? '';
                    final updatedAt = chat['updated_at'] != null
                        ? DateTime.parse(chat['updated_at'])
                        : null;

                    return FutureBuilder<UserModel?>(
                      future: context.read<UserService>().getUserById(otherId),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF00897B),
                            backgroundImage:
                                user?.profileImageUrl.isNotEmpty == true
                                    ? NetworkImage(user!.profileImageUrl)
                                    : null,
                            child: user?.profileImageUrl.isEmpty != false
                                ? Text((user?.name ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(user?.name ?? '...',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          subtitle: Text(lastMsg,
                              style: GoogleFonts.nunito(
                                  color: Colors.grey[600], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (updatedAt != null)
                                Text(_fmtTime(updatedAt),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: unread > 0
                                            ? const Color(0xFF00897B)
                                            : Colors.grey[500])),
                              const SizedBox(height: 4),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF00897B),
                                      shape: BoxShape.circle),
                                  child: Text('$unread',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (user != null) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                            otherUser: user,
                                            chatId: chat['id'],
                                          )));
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00897B),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NewChatScreen())),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(t);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(t);
    return DateFormat('dd/MM/yy').format(t);
  }
}
