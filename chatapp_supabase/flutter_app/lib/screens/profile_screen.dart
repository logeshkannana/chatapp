import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _statusCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _nameCtrl = TextEditingController(text: auth.currentUser?.name ?? '');
    _statusCtrl = TextEditingController(text: auth.currentUser?.status ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final auth = context.read<AuthService>();
    final userSvc = context.read<UserService>();
    final url = await userSvc.uploadProfileImage(
        auth.currentUserId!, File(picked.path));
    if (url != null) {
      await userSvc.updateProfile(
          uid: auth.currentUserId!, profileImageUrl: url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    await context.read<UserService>().updateProfile(
      uid: auth.currentUserId!,
      name: _nameCtrl.text.trim(),
      status: _statusCtrl.text.trim(),
    );
    setState(() { _saving = false; _editing = false; });
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text('Save',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(child: Column(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF00897B),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white30,
                  backgroundImage: user?.profileImageUrl.isNotEmpty == true
                      ? NetworkImage(user!.profileImageUrl) : null,
                  child: user?.profileImageUrl.isEmpty != false
                      ? Text((user?.name ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 40, color: Colors.white,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                Positioned(bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        size: 18, color: Color(0xFF00897B)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text(user?.name ?? '',
                style: GoogleFonts.nunito(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(user?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _infoCard('Name', _nameCtrl, Icons.person_outline, _editing),
            const SizedBox(height: 16),
            _infoCard('Status', _statusCtrl, Icons.info_outline, _editing),
            const SizedBox(height: 16),
            _staticCard('Phone',
                user?.phone.isEmpty == true ? 'Not set' : (user?.phone ?? ''),
                Icons.phone_outlined),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      ])),
    );
  }

  Widget _infoCard(String title, TextEditingController ctrl,
      IconData icon, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF00897B)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            TextField(
              controller: ctrl, enabled: enabled,
              decoration: const InputDecoration(
                  border: InputBorder.none, isDense: true,
                  contentPadding: EdgeInsets.zero),
              style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        )),
      ]),
    );
  }

  Widget _staticCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF00897B)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}
