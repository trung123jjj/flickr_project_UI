import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backend_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    try {
      Permission permission = Platform.isAndroid
          ? Permission.mediaLibrary
          : Permission.photos;

      PermissionStatus status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text('Cần cấp quyền', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              content: Text(
                'Ứng dụng cần quyền truy cập thư viện ảnh để đổi avatar.\n\n'
                'Vui lòng vào Cài đặt > Ứng dụng > Flickr Project > Quyền hạn để cấp quyền.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Để sau', style: TextStyle(color: Color(0xFF87CEEB))),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Mở cài đặt', style: TextStyle(color: Color(0xFF87CEEB))),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (!status.isGranted) {
        throw Exception('permission_denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final result = await BackendService.updateAvatar(File(image.path));

      if (mounted) {
        if (result['success'] == true) {
          context.read<AuthProvider>().loadUserProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update avatar'),
              backgroundColor: const Color(0xFFFF6B00),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B263B),
            title: const Text('Lỗi', style: TextStyle(color: Colors.white)),
            content: Text(
              'Không thể mở thư viện ảnh',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFF87CEEB))),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(auth.avatarUrl!)
                      : const AssetImage('assets/images/profile_pic.png') as ImageProvider,
                  child: auth.avatarUrl == null || auth.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white70, size: 50)
                      : null,
                ),
                if (_isUploadingAvatar)
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.black54,
                    child: CircularProgressIndicator(
                      color: Color(0xFF87CEEB),
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              auth.currentUser ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          _buildMenuItem(
            icon: Icons.camera_alt,
            title: 'Change Avatar',
            onTap: _pickAndUploadAvatar,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildSwitchItem(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            textColor: const Color(0xFFFF6B00),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF87CEEB)),
      title: Text(title, style: TextStyle(color: textColor ?? Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF87CEEB)),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      trailing: Switch(
        value: value,
        activeColor: const Color(0xFF87CEEB),
        onChanged: onChanged,
      ),
    );
  }
}
