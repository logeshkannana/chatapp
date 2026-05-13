// ─── User Model ───────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;
  final String status;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.profileImageUrl = '',
    this.status = 'Hey there! I am using ChatApp',
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profileImageUrl: map['profile_image_url'] ?? '',
      status: map['status'] ?? 'Hey there! I am using ChatApp',
      isOnline: map['is_online'] ?? false,
      lastSeen:
          map['last_seen'] != null ? DateTime.parse(map['last_seen']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'status': status,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}

// ─── Message Type & Status ────────────────────────────────────────────────────
enum MessageType { text, image, video, audio, file, document }

enum MessageStatus { sending, sent, delivered, read }

// ─── Message Model ────────────────────────────────────────────────────────────
class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String chatId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isDeleted;
  final String? replyToMessageId;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.chatId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isDeleted = false,
    this.replyToMessageId,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      receiverId: map['receiver_id'] ?? '',
      chatId: map['chat_id'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      fileUrl: map['file_url'],
      fileName: map['file_name'],
      fileSize: map['file_size'],
      isDeleted: map['is_deleted'] ?? false,
      replyToMessageId: map['reply_to_message_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'chat_id': chatId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_deleted': isDeleted,
      'reply_to_message_id': replyToMessageId,
    };
  }

  String get formattedFileSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─── Chat Model ───────────────────────────────────────────────────────────────
class ChatModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final String? lastMessageType;
  final int unreadCount;
  final DateTime updatedAt;
  UserModel? otherUser;

  ChatModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    this.lastMessageType,
    this.unreadCount = 0,
    required this.updatedAt,
    this.otherUser,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    return ChatModel(
      id: map['id'] ?? '',
      user1Id: map['user1_id'] ?? '',
      user2Id: map['user2_id'] ?? '',
      lastMessage: map['last_message'],
      lastMessageType: map['last_message_type'],
      unreadCount: map['user1_id'] == currentUserId
          ? (map['unread_count_user1'] ?? 0)
          : (map['unread_count_user2'] ?? 0),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }
}

// ─── Story Type ───────────────────────────────────────────────────────────────
enum StoryContentType { image, video }

// ─── Story Model ───────────────────────────────────────────────────────────────
class StoryModel {
  final String id;
  final String userId;
  final String contentUrl;
  final StoryContentType contentType;
  final String caption;
  final int duration; // display duration in seconds
  final int viewCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isDeleted;
  UserModel? user;
  bool? hasViewed;

  StoryModel({
    required this.id,
    required this.userId,
    required this.contentUrl,
    required this.contentType,
    this.caption = '',
    this.duration = 5,
    this.viewCount = 0,
    required this.createdAt,
    required this.expiresAt,
    this.isDeleted = false,
    this.user,
    this.hasViewed = false,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      contentUrl: map['content_url'] ?? '',
      contentType: (map['content_type'] ?? 'image') == 'video'
          ? StoryContentType.video
          : StoryContentType.image,
      caption: map['caption'] ?? '',
      duration: map['duration'] ?? 5,
      viewCount: map['view_count'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'])
          : DateTime.now().add(const Duration(hours: 24)),
      isDeleted: map['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content_url': contentUrl,
      'content_type': contentType.name,
      'caption': caption,
      'duration': duration,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  String get timeRemainingText {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h remaining';
    }
    return '${remaining.inMinutes}m remaining';
  }
}
