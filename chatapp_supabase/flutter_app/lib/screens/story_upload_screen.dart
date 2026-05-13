import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import '../models/models.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  Uint8List? _selectedImage;
  Uint8List? _selectedVideo;
  String _caption = '';
  bool _isUploading = false;
  double _uploadProgress = 0;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() => _selectedImage = bytes);
      _selectedVideo = null;
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      final bytes = await File(video.path).readAsBytes();
      setState(() => _selectedVideo = bytes);
      _selectedImage = null;
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedImage == null && _selectedVideo == null) {
      _showError('Please select an image or video');
      return;
    }

    final auth = context.read<AuthService>();
    final storyService = context.read<StoryService>();
    final userId = auth.currentUserId;

    if (userId == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final contentType = _selectedImage != null
          ? StoryContentType.image
          : StoryContentType.video;

      final fileBytes = _selectedImage ?? _selectedVideo;

      final story = await storyService.uploadStory(
        userId: userId,
        fileBytes: fileBytes!,
        contentType: contentType,
        caption: _caption,
        duration: 5,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
      );

      if (story != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story posted successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError('Error uploading story: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = _selectedImage != null || _selectedVideo != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        title: Text('New Story',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Preview area
            if (hasMedia)
              Container(
                height: 400,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImage != null)
                      Image.memory(_selectedImage!, fit: BoxFit.cover)
                    else
                      Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.video_library,
                            color: Colors.white70, size: 48),
                      ),
                    // Change media button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null;
                            _selectedVideo = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00897B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No media selected',
                          style: GoogleFonts.nunito(
                              fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _mediaButton(Icons.image, 'Image', _pickImage),
                  _mediaButton(Icons.videocam, 'Video', _pickVideo),
                ],
              ),
            ),

            // Caption input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                maxLines: 3,
                onChanged: (value) => _caption = value,
                decoration: InputDecoration(
                  hintText: 'Add caption (optional)',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF00897B), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            // Upload progress
            if (_isUploading) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00897B)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Upload button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading || !hasMedia ? null : _uploadStory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isUploading ? 'Uploading...' : 'Post Story',
                    style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _mediaButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF00897B), size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
