import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backend_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  Future<void> _showChangeUsernameDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newUsernameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Change Username', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newUsernameCtrl,
                decoration: const InputDecoration(labelText: 'New Username'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final res = await BackendService.changeUsername(
                currentPasswordCtrl.text,
                newUsernameCtrl.text,
              );
              if (!ctx.mounted) return;
              if (res['success'] == true) {
                await context.read<AuthProvider>().loadSession();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username updated!'), backgroundColor: Colors.green),
                );
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: const Color(0xFFE53935)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Change Password', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) => v == null || v.length < 8 ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) => v != newPasswordCtrl.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final res = await BackendService.changePassword(
                currentPasswordCtrl.text,
                newPasswordCtrl.text,
              );
              if (!ctx.mounted) return;
              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated!'), backgroundColor: Colors.green),
                );
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: const Color(0xFFE53935)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
                  child: const Text('Để sau', style: TextStyle(color: Color(0xFFE53935))),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Mở cài đặt', style: TextStyle(color: Color(0xFFE53935))),
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
              backgroundColor: const Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Lỗi', style: TextStyle(color: Colors.white)),
            content: Text(
              'Không thể mở thư viện ảnh',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFFE53935))),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const _SettingsAppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _UserInfoSection(isUploadingAvatar: _isUploadingAvatar),
          const SizedBox(height: 32),
          _buildMenuItem(
            icon: Icons.camera_alt,
            title: 'Change Avatar',
            onTap: _pickAndUploadAvatar,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildMenuItem(
            icon: Icons.person,
            title: 'Change Username',
            onTap: _showChangeUsernameDialog,
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildMenuItem(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(color: Colors.white12, height: 1),
          const _ThemeModeTile(),
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
      leading: Icon(icon, color: const Color(0xFFE53935)),
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
      leading: Icon(icon, color: const Color(0xFFE53935)),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      trailing: Switch(
        value: value,
        activeColor: const Color(0xFFE53935),
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'Settings',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: themeProvider.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }
}

class _UserInfoSection extends StatelessWidget {
  final bool isUploadingAvatar;

  const _UserInfoSection({required this.isUploadingAvatar});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[800],
                backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(auth.avatarUrl!)
                    : null,
                child: auth.avatarUrl == null || auth.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white70, size: 50)
                    : null,
              ),
              if (isUploadingAvatar)
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.black54,
                  child: CircularProgressIndicator(
                    color: Color(0xFFE53935),
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
      ],
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ListTile(
      leading: const Icon(Icons.dark_mode, color: Color(0xFFE53935)),
      title: const Text('Dark Mode', style: TextStyle(fontSize: 16)),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        activeColor: const Color(0xFFE53935),
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }
}
