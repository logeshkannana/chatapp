// ─── Add these imports to home_screen.dart ────────────────────────────────
import '../services/story_service.dart';
import '../widgets/story_circle.dart';
import 'story_upload_screen.dart';
import 'story_viewer_screen.dart';

// ─── Replace the body of HomeScreen with this code ────────────────────────
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
                  stream: context.read<StoryService>().getGroupedStories(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    
                    final groupedStories = snapshot.data ?? [];
                    
                    return Row(
                      children: groupedStories.map((group) {
                        final storyUser = group['latestStory'] != null
                            ? (group['latestStory'] as StoryModel).user
                            : null;
                        final stories = group['stories'] as List<StoryModel>;
                        
                        if (storyUser == null) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: StoryCircle(
                            latestStory: stories.first,
                            user: storyUser,
                            storyCount: stories.length,
                            hasUnviewedStories: stories.first.hasViewed != true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(
                                  stories: stories,
                                  storyUser: storyUser,
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
    
    // Divider
    const Divider(height: 1),
    
    // Chats list (existing code)
    Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chatService.getUserChats(userId),
        // ... rest of existing chat list code
