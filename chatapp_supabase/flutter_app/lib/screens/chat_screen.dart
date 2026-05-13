import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/models.dart';
import '../widgets/message_bubble.dart';
import '../widgets/status_bar.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String chatId;
  const ChatScreen({super.key, required this.otherUser, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final userId = context.read<AuthService>().currentUserId ?? '';
    context.read<ChatService>().markMessagesAsRead(widget.chatId, userId);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthService>();
    _msgCtrl.clear();
    await context.read<ChatService>().sendTextMessage(
          senderId: auth.currentUserId!,
          receiverId: widget.otherUser.id,
          content: text,
        );
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: src,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
        return;
      }

      final fileBytes = await picked.readAsBytes();

      // Generate proper filename with timestamp
      String fileName = picked.name;
      if (fileName.isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        fileName = 'image_$timestamp.jpg';
      } else if (!fileName.toLowerCase().endsWith('.jpg') &&
          !fileName.toLowerCase().endsWith('.jpeg') &&
          !fileName.toLowerCase().endsWith('.png')) {
        fileName = '$fileName.jpg';
      }

      await _upload(fileBytes, MessageType.image, fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;

        if (fileBytes != null) {
          await _upload(fileBytes, MessageType.file, fileName);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _upload(
      Uint8List fileBytes, MessageType type, String name) async {
    final auth = context.read<AuthService>();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    await context.read<ChatService>().sendFileMessage(
          senderId: auth.currentUserId!,
          receiverId: widget.otherUser.id,
          fileBytes: fileBytes,
          type: type,
          fileName: name,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
    setState(() => _isUploading = false);
  }

  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _attachBtn(Icons.photo_library, 'Gallery', const Color(0xFF9C27B0),
                () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            }),
            _attachBtn(Icons.camera_alt, 'Camera', const Color(0xFF2196F3), () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            }),
            _attachBtn(Icons.attach_file, 'File', const Color(0xFFFF9800), () {
              Navigator.pop(context);
              _pickFile();
            }),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _attachBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final currentUserId = auth.currentUserId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: StreamBuilder<UserModel?>(
          stream: context
              .read<ChatService>()
              .getUserPresence(widget.otherUser.id)
              .map((m) => m != null ? UserModel.fromMap(m) : null),
          builder: (ctx, snap) {
            final u = snap.data;
            final isOnline = u?.isOnline ?? false;
            final lastSeen = u?.lastSeen;
            return Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white30,
                backgroundImage: widget.otherUser.profileImageUrl.isNotEmpty
                    ? NetworkImage(widget.otherUser.profileImageUrl)
                    : null,
                child: widget.otherUser.profileImageUrl.isEmpty
                    ? Text(widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.otherUser.name,
                    style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(
                  isOnline
                      ? 'Online'
                      : lastSeen != null
                          ? 'Last seen ${_fmtLastSeen(lastSeen)}'
                          : '',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ]),
            ]);
          },
        ),
      ),
      body: Column(children: [
        if (_isUploading)
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
          ),
        const StatusBar(),
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: context.read<ChatService>().getMessages(widget.chatId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Messages are end-to-end encrypted',
                            style: GoogleFonts.nunito(
                                color: Colors.grey[500], fontSize: 13)),
                      ]),
                );
              }
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final msg = msgs[i];
                  final isMine = msg.senderId == currentUserId;
                  final showDate =
                      i == 0 || !_sameDay(msgs[i - 1].timestamp, msg.timestamp);
                  return Column(children: [
                    if (showDate) _dateDivider(msg.timestamp),
                    MessageBubble(
                      message: msg,
                      isMine: isMine,
                      onLongPress: () => _msgOptions(msg, isMine),
                    ),
                  ]);
                },
              );
            },
          ),
        ),
        _inputArea(),
      ]),
    );
  }

  Widget _inputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.attach_file, color: Color(0xFF00897B)),
          onPressed: _showAttachOptions,
        ),
        Expanded(
          child: TextField(
            controller: _msgCtrl,
            minLines: 1,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF00897B),
          child: IconButton(
            icon: Icon(_msgCtrl.text.trim().isEmpty ? Icons.mic : Icons.send,
                color: Colors.white, size: 20),
            onPressed: _sendMessage,
          ),
        ),
      ]),
    );
  }

  Widget _dateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_fmtDate(date),
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }

  void _msgOptions(MessageModel msg, bool isMine) {
    final isFile = msg.type != 'text';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Copy option (text messages only)
          if (!isFile)
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF00897B)),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),

          // Share option (all messages)
          ListTile(
            leading: const Icon(Icons.share, color: Color(0xFF2196F3)),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareMessage(msg);
            },
          ),

          // Download option (files & images only)
          if (isFile && msg.fileUrl != null && msg.fileUrl!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF4CAF50)),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading file...')),
                );
              },
            ),

          // Save to favorites (optional)
          ListTile(
            leading:
                const Icon(Icons.favorite_border, color: Color(0xFFFF5722)),
            title: const Text('Add to favorites'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to favorites')),
              );
            },
          ),

          // Reply option
          ListTile(
            leading: const Icon(Icons.reply, color: Color(0xFF9C27B0)),
            title: const Text('Reply'),
            onTap: () => Navigator.pop(context),
          ),

          // Delete option (sender only)
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(msg);
              },
            ),
        ]),
      ),
    );
  }

  void _shareMessage(MessageModel msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share Via'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.share_outlined, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing to WhatsApp...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail, color: Color(0xFFEA4335)),
              title: const Text('Email'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(MessageModel msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatService>().deleteMessage(msg.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Today';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(d);
  }

  String _fmtLastSeen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(t);
    return DateFormat('MMM d').format(t);
  }
}
