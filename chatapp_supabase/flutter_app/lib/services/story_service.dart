import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../main.dart';
import '../models/models.dart';

class StoryService extends ChangeNotifier {
  final _uuid = const Uuid();

  // ─── Upload story (image/video) ──────────────────────────────────────────
  Future<StoryModel?> uploadStory({
    required String userId,
    required Uint8List fileBytes,
    required StoryContentType contentType,
    String caption = '',
    int duration = 5,
    required Function(double) onProgress,
  }) async {
    try {
      final storyId = _uuid.v4();
      final fileName =
          '${contentType.name}_${storyId}_${DateTime.now().millisecondsSinceEpoch}';

      final fileExtension =
          contentType == StoryContentType.image ? '.jpg' : '.mp4';
      final filePath = '$userId/stories/$fileName$fileExtension';

      // Upload file to storage
      await supabase.storage.from('stories').uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );
      onProgress(0.5);

      // Get public URL
      final publicUrl = supabase.storage.from('stories').getPublicUrl(filePath);

      // Create story record in database
      final story = await supabase
          .from('stories')
          .insert({
            'id': storyId,
            'user_id': userId,
            'content_url': publicUrl,
            'content_type': contentType.name,
            'caption': caption,
            'duration': duration,
            'view_count': 0,
            'is_deleted': false,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at':
                DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          })
          .select()
          .single();

      onProgress(1.0);
      return StoryModel.fromMap(story);
    } catch (e) {
      debugPrint('Error uploading story: $e');
      return null;
    }
  }

  // ─── Get stories for contacts (people you have chats with) ──────────────
  Stream<List<StoryModel>> getContactStories(String userId) {
    return supabase
        .from('stories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) =>
                !r['is_deleted'] &&
                DateTime.parse(r['expires_at']).isAfter(DateTime.now()))
            .map((r) => StoryModel.fromMap(r))
            .toList());
  }

  // ─── Get user's own stories ────────────────────────────────────────────
  Stream<List<StoryModel>> getUserStories(String userId) {
    return supabase
        .from('stories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) =>
                r['user_id'] == userId &&
                !r['is_deleted'] &&
                DateTime.parse(r['expires_at']).isAfter(DateTime.now()))
            .map((r) => StoryModel.fromMap(r))
            .toList());
  }

  // ─── Get grouped stories (by user, latest first) ────────────────────────
  Stream<List<Map<String, dynamic>>> getGroupedStories(String userId) {
    return supabase
        .from('stories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => _groupStoriesByUser(rows, userId));
  }

  List<Map<String, dynamic>> _groupStoriesByUser(
    List<Map<String, dynamic>> rows,
    String currentUserId,
  ) {
    final now = DateTime.now();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var row in rows) {
      if (row['is_deleted']) continue;

      final expiresAt = DateTime.parse(row['expires_at']);
      if (expiresAt.isBefore(now)) continue;

      final userId = row['user_id'];
      grouped.putIfAbsent(userId, () => []).add(row);
    }

    // Convert to list with user info
    return grouped.entries.map((e) {
      final stories = e.value.map((r) => StoryModel.fromMap(r)).toList();
      return {
        'userId': e.key,
        'stories': stories,
        'latestStory': stories.first,
        'storyCount': stories.length,
      };
    }).toList();
  }

  // ─── Record story view ─────────────────────────────────────────────────
  Future<void> recordStoryView(String storyId, String viewerId) async {
    try {
      await supabase.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': viewerId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording story view: $e');
    }
  }

  // ─── Get story views ──────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getStoryViews(String storyId) {
    return supabase
        .from('story_views')
        .stream(primaryKey: ['id'])
        .order('viewed_at', ascending: false)
        .map((rows) => rows.where((r) => r['story_id'] == storyId).toList());
  }

  // ─── Delete story ─────────────────────────────────────────────────────
  Future<bool> deleteStory(String storyId) async {
    try {
      await supabase
          .from('stories')
          .update({'is_deleted': true}).eq('id', storyId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting story: $e');
      return false;
    }
  }

  // ─── Check if user has viewed a story ─────────────────────────────────
  Future<bool> hasUserViewedStory(String storyId, String userId) async {
    try {
      final result = await supabase
          .from('story_views')
          .select()
          .eq('story_id', storyId)
          .eq('viewer_id', userId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('Error checking story view: $e');
      return false;
    }
  }

  // ─── Get stories created in last 24 hours for a user ──────────────────
  Stream<List<StoryModel>> getRecentUserStories(String userId) {
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));

    return supabase
        .from('stories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) {
              final createdAt = DateTime.parse(r['created_at']);
              final expiresAt = DateTime.parse(r['expires_at']);
              return r['user_id'] == userId &&
                  !r['is_deleted'] &&
                  createdAt.isAfter(oneDayAgo) &&
                  expiresAt.isAfter(DateTime.now());
            })
            .map((r) => StoryModel.fromMap(r))
            .toList());
  }
}
