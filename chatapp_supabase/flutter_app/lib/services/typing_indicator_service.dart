import 'dart:async';
import 'package:flutter/foundation.dart';
import '../main.dart';

class TypingIndicatorService extends ChangeNotifier {
  final Map<String, bool> _typingUsers = {};
  final Map<String, Timer?> _typingTimers = {};

  bool isUserTyping(String userId) => _typingUsers[userId] ?? false;

  Future<void> setTyping(String userId, String chatId, bool isTyping) async {
    try {
      // Cancel previous timer if exists
      _typingTimers[userId]?.cancel();

      if (isTyping) {
        _typingUsers[userId] = true;
        notifyListeners();

        // Upsert typing status in Supabase
        await supabase.from('typing_status').upsert({
          'user_id': userId,
          'chat_id': chatId,
          'is_typing': true,
          'last_activity': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,chat_id');

        // Auto-stop typing after 5 seconds of inactivity
        _typingTimers[userId] = Timer(const Duration(seconds: 5), () {
          setTyping(userId, chatId, false);
        });
      } else {
        _typingUsers.remove(userId);
        _typingTimers[userId]?.cancel();
        _typingTimers.remove(userId);
        notifyListeners();

        // Update typing status in Supabase
        await supabase
            .from('typing_status')
            .update({
              'is_typing': false,
              'last_activity': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('chat_id', chatId);
      }
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return supabase.from('typing_status').stream(primaryKey: ['id']).map(
        (rows) => rows
            .where((r) => r['chat_id'] == chatId && r['is_typing'] == true)
            .map((r) => r['user_id'] as String)
            .toList());
  }

  Future<void> stopTyping(String userId, String chatId) async {
    await setTyping(userId, chatId, false);
  }

  @override
  void dispose() {
    for (var timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
    super.dispose();
  }
}
