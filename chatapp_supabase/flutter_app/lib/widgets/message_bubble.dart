import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMine ? 60 : 0,
            right: isMine ? 0 : 60,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildBubble(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _statusIcon(),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    if (message.isDeleted) return _deleted();
    switch (message.type) {
      case MessageType.image:
        return _image(context);
      case MessageType.document:
      case MessageType.file:
        return _file(context);
      case MessageType.audio:
        return _audio();
      case MessageType.video:
        return _video();
      default:
        return _text();
    }
  }

  BoxDecoration _bubbleDeco() => BoxDecoration(
        color: isMine ? const Color(0xFFDCF8C6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      );

  Widget _text() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _bubbleDeco(),
        child: Text(message.content,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E))),
      );

  Widget _image(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: message.fileUrl != null
            ? GestureDetector(
                onTap: () => _openImage(context),
                child: CachedNetworkImage(
                  imageUrl: message.fileUrl!,
                  width: 220,
                  height: 200,
                  fit: BoxFit.cover,
                  memCacheHeight: 400,
                  memCacheWidth: 400,
                  placeholder: (_, __) => Container(
                      width: 220,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(
                    width: 220,
                    height: 200,
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text('Image failed to load',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ))
            : Container(
                width: 220,
                height: 200,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image)),
      );

  Widget _file(BuildContext context) => GestureDetector(
        onTap: () => _openFile(context, message.fileUrl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insert_drive_file,
                  color: Color(0xFF00897B), size: 28),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message.fileName ?? 'File',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (message.fileSize != null)
                Text(message.formattedFileSize,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(width: 8),
            Icon(Icons.download, color: Colors.grey[600], size: 20),
          ]),
        ),
      );

  Widget _audio() => Container(
        padding: const EdgeInsets.all(12),
        width: 200,
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.play_circle_filled,
              color: Color(0xFF00897B), size: 36),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              Text('Audio',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          )),
        ]),
      );

  Widget _video() => Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
            color: Colors.black87, borderRadius: BorderRadius.circular(12)),
        child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
      );

  Widget _deleted() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('This message was deleted',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic)),
        ]),
      );

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 14, color: Colors.grey[400]);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: Colors.grey[400]);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: Colors.grey[400]);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF00897B));
    }
  }

  void _openImage(BuildContext context) {
    if (message.fileUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
              child: CachedNetworkImage(imageUrl: message.fileUrl!)),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File URL not available')),
      );
      return;
    }

    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cannot open file. Try downloading it.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }
}
