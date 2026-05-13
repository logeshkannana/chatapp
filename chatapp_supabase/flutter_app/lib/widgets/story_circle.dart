import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class StoryCircle extends StatelessWidget {
  final StoryModel? latestStory;
  final UserModel? user;
  final int storyCount;
  final bool hasUnviewedStories;
  final VoidCallback onTap;

  const StoryCircle({
    super.key,
    required this.latestStory,
    this.user,
    this.storyCount = 0,
    this.hasUnviewedStories = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profileUrl = user?.profileImageUrl ?? '';
    final hasImage = profileUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: hasUnviewedStories
                ? const Color(0xFF00897B)
                : Colors.grey[300]!,
            width: hasUnviewedStories ? 3 : 2,
          ),
        ),
        child: Stack(
          children: [
            // Profile image
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF00897B).withOpacity(0.2),
              backgroundImage: hasImage ? NetworkImage(profileUrl) : null,
              child: !hasImage
                  ? Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00897B)),
                    )
                  : null,
            ),

            // Story count badge
            if (storyCount > 1)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00897B),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$storyCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Your Story button ─────────────────────────────────────────────────
class AddStoryButton extends StatelessWidget {
  final UserModel? currentUser;
  final VoidCallback onTap;

  const AddStoryButton({
    super.key,
    this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profileUrl = currentUser?.profileImageUrl ?? '';
    final hasImage = profileUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00897B).withOpacity(0.2),
                backgroundImage: hasImage ? NetworkImage(profileUrl) : null,
                child: !hasImage
                    ? Text(
                        currentUser?.name.isNotEmpty == true
                            ? currentUser!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00897B)),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00897B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your Story',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
