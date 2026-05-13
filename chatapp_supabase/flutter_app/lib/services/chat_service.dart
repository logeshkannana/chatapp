import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../main.dart';
import '../models/models.dart';

class ChatService extends ChangeNotifier {
  final _uuid = const Uuid();

  // ─── Get or create chat between two users ────────────────────────────────
  Future<String> getOrCreateChat(String userId1, String userId2) async {
    // Check if chat already exists
    final existing = await supabase
        .from('chats')
        .select('id')
        .or('and(user1_id.eq.$userId1,user2_id.eq.$userId2),and(user1_id.eq.$userId2,user2_id.eq.$userId1)')
        .maybeSingle();

    if (existing != null) return existing['id'];

    // Create new chat
    final newChat = await supabase
        .from('chats')
        .insert({
          'user1_id': userId1,
          'user2_id': userId2,
          'unread_count_user1': 0,
          'unread_count_user2': 0,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return newChat['id'];
  }

  // ─── Stream messages for a chat (Realtime) ───────────────────────────────
  Stream<List<MessageModel>> getMessages(String chatId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => MessageModel.fromMap(r)).toList());
  }

  // ─── Stream all chats for a user (Realtime) ──────────────────────────────
  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((rows) => rows
            .where((r) => r['user1_id'] == userId || r['user2_id'] == userId)
            .toList());
  }

  // ─── Send text message ───────────────────────────────────────────────────
  Future<void> sendTextMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? replyToMessageId,
  }) async {
    final chatId = await getOrCreateChat(senderId, receiverId);

    await supabase.from('messages').insert({
      'id': _uuid.v4(),
      'sender_id': senderId,
      'receiver_id': receiverId,
      'chat_id': chatId,
      'content': content,
      'type': 'text',
      'status': 'sent',
      'is_deleted': false,
      'reply_to_message_id': replyToMessageId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _updateChatMeta(chatId, receiverId, content, 'text');
  }

  // ─── Send file/media message ─────────────────────────────────────────────
  Future<void> sendFileMessage({
    required String senderId,
    required String receiverId,
    required Uint8List fileBytes,
    required MessageType type,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final chatId = await getOrCreateChat(senderId, receiverId);
    final messageId = _uuid.v4();

    // Ensure proper file extension based on type
    String fileExt = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : _getExtensionForType(type);

    final storagePath = 'chats/$chatId/$messageId.$fileExt';

    // Better MIME type detection
    String mimeType = _getMimeTypeForExtension(fileExt);

    try {
      // Upload to Supabase Storage
      await supabase.storage.from('chat-files').uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      // Create signed URL (expires in 7 days) - only recipient can access
      final fileUrl = await supabase.storage
          .from('chat-files')
          .createSignedUrl(storagePath, 604800); // 7 days in seconds

      final fileSize = fileBytes.length;

      String content;
      switch (type) {
        case MessageType.image:
          content = '📷 Photo';
          break;
        case MessageType.video:
          content = '🎥 Video';
          break;
        case MessageType.audio:
          content = '🎵 Audio';
          break;
        case MessageType.document:
          content = '📄 $fileName';
          break;
        default:
          content = '📎 $fileName';
      }

      await supabase.from('messages').insert({
        'id': messageId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'chat_id': chatId,
        'content': content,
        'type': type.name,
        'status': 'sent',
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _updateChatMeta(chatId, receiverId, content, type.name);
    } catch (e) {
      throw Exception('Failed to send file: ${e.toString()}');
    }
  }

  // Helper method to get file extension based on message type
  String _getExtensionForType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'jpg';
      case MessageType.video:
        return 'mp4';
      case MessageType.audio:
        return 'mp3';
      case MessageType.document:
        return 'pdf';
      default:
        return 'bin';
    }
  }

  // Helper method to get proper MIME type
  String _getMimeTypeForExtension(String ext) {
    final mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
    };
    return mimeMap[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  // ─── Mark messages as read ───────────────────────────────────────────────
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    await supabase
        .from('messages')
        .update({'status': 'read'})
        .eq('chat_id', chatId)
        .eq('receiver_id', userId)
        .neq('status', 'read');

    // Reset unread count
    final chat = await supabase
        .from('chats')
        .select('user1_id')
        .eq('id', chatId)
        .single();

    final isUser1 = chat['user1_id'] == userId;
    await supabase.from('chats').update({
      isUser1 ? 'unread_count_user1' : 'unread_count_user2': 0,
    }).eq('id', chatId);
  }

  // ─── Delete message (soft delete) ────────────────────────────────────────
  Future<void> deleteMessage(String messageId) async {
    await supabase.from('messages').update({
      'is_deleted': true,
      'content': 'This message was deleted',
    }).eq('id', messageId);
  }

  // ─── Get user presence stream ─────────────────────────────────────────────
  Stream<Map<String, dynamic>?> getUserPresence(String userId) {
    return supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  // ─── Update chat metadata ─────────────────────────────────────────────────
  Future<void> _updateChatMeta(
      String chatId, String receiverId, String content, String type) async {
    final chat = await supabase
        .from('chats')
        .select('user1_id, unread_count_user1, unread_count_user2')
        .eq('id', chatId)
        .single();

    final isReceiverUser1 = chat['user1_id'] == receiverId;
    final currentUnread = isReceiverUser1
        ? (chat['unread_count_user1'] ?? 0)
        : (chat['unread_count_user2'] ?? 0);

    await supabase.from('chats').update({
      'last_message': content,
      'last_message_type': type,
      'updated_at': DateTime.now().toIso8601String(),
      isReceiverUser1 ? 'unread_count_user1' : 'unread_count_user2':
          currentUnread + 1,
    }).eq('id', chatId);
  }
}
