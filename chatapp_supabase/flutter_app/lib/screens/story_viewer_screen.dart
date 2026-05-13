import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../models/models.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  final UserModel storyUser;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.storyUser,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  late AnimationController _storyProgressController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _storyProgressController = AnimationController(
      duration: Duration(seconds: widget.stories[_currentIndex].duration),
      vsync: this,
    );

    // Mark story as viewed
    final storyService = context.read<StoryService>();
    final auth = context.read<AuthService>();

    storyService.recordStoryView(
      widget.stories[_currentIndex].id,
      auth.currentUserId ?? '',
    );

    _storyProgressController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storyProgressController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });

                _storyProgressController.reset();
                _storyProgressController = AnimationController(
                  duration: Duration(seconds: widget.stories[index].duration),
                  vsync: this,
                );
                _storyProgressController.forward();

                // Mark as viewed
                final storyService = context.read<StoryService>();
                final auth = context.read<AuthService>();
                storyService.recordStoryView(
                  widget.stories[index].id,
                  auth.currentUserId ?? '',
                );
              },
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                return _buildStoryContent(story);
              },
            ),

            // Header with progress and close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Progress indicators
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: List.generate(widget.stories.length, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: index < _currentIndex
                                    ? 1
                                    : index == _currentIndex
                                        ? _storyProgressController.value
                                        : 0,
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User info and close button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white30,
                          backgroundImage: widget
                                  .storyUser.profileImageUrl.isNotEmpty
                              ? NetworkImage(widget.storyUser.profileImageUrl)
                              : null,
                          child: widget.storyUser.profileImageUrl.isEmpty
                              ? Text(
                                  widget.storyUser.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.storyUser.name,
                                  style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              Text(
                                widget.stories[_currentIndex].timeRemainingText,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Caption at bottom
            if (widget.stories[_currentIndex].caption.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.stories[_currentIndex].caption,
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    if (story.contentType == StoryContentType.image) {
      return CachedNetworkImage(
        imageUrl: story.contentUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.error_outline, color: Colors.white),
        ),
      );
    } else {
      // For videos, show a placeholder with play icon
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black),
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
          Text('Video preview not available',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
        ],
      );
    }
  }
}
