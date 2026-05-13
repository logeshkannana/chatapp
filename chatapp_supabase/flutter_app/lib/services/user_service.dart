import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';

class UserService extends ChangeNotifier {

  Future<List<UserModel>> searchUsers(String query, String excludeId) async {
    if (query.isEmpty) return getAllUsers(excludeId);
    final data = await supabase
        .from('users')
        .select()
        .ilike('name', '%$query%')
        .neq('id', excludeId)
        .limit(30);
    return (data as List).map((e) => UserModel.fromMap(e)).toList();
  }

  Future<List<UserModel>> getAllUsers(String excludeId) async {
    final data = await supabase
        .from('users')
        .select()
        .neq('id', excludeId)
        .order('name')
        .limit(50);
    return (data as List).map((e) => UserModel.fromMap(e)).toList();
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      return UserModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Stream<UserModel?> getUserStream(String uid) {
    return supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isNotEmpty ? UserModel.fromMap(rows.first) : null);
  }

  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final path = 'avatars/$uid.jpg';
      await supabase.storage.from('avatars').uploadBinary(
        path,
        await imageFile.readAsBytes(),
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      return supabase.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    required String uid,
    String? name,
    String? status,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null)             updates['name'] = name;
      if (status != null)           updates['status'] = status;
      if (phone != null)            updates['phone'] = phone;
      if (profileImageUrl != null)  updates['profile_image_url'] = profileImageUrl;

      await supabase.from('users').update(updates).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }
}
