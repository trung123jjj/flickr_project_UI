import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/backend_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final result = await BackendService.getNotifications();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          final raw = result['data'];
          if (raw is List) {
            _notifications = raw;
          } else if (raw is Map && raw['data'] is List) {
            _notifications = raw['data'] as List;
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(String id) async {
    await BackendService.deleteNotification(id);
    _loadNotifications();
  }

  void _onTapNotification(Map<String, dynamic> notif) {
    final id = notif['_id']?.toString() ?? '';
    final type = notif['type']?.toString();
    final movieId = notif['movieId'];

    if (id.isNotEmpty) {
      BackendService.markNotificationRead(id);
      final index = _notifications.indexWhere((n) => (n as Map)['_id']?.toString() == id);
      if (index != -1) {
        setState(() => _notifications[index]['read'] = true);
      }
    }

    if ((type == 'reply' || type == 'like') && movieId != null) {
      Navigator.pushNamed(context, '/comments', arguments: {
        'movieId': movieId is int ? movieId : int.tryParse(movieId.toString()) ?? 0,
        'movieTitle': notif['movieTitle']?.toString() ?? '',
        'commentId': notif['commentId']?.toString(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Notifications',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No notifications yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index] as Map<String, dynamic>;
                    final id = notif['_id']?.toString() ?? '';
                    final message = notif['message']?.toString() ?? '';
                    final readVal = notif['read'];
                    final isRead = readVal == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _onTapNotification(notif),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Theme.of(context).cardColor
                                : const Color(0xFFE57373),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                notif['type'] == 'reply'
                                    ? Icons.edit_outlined
                                    : notif['type'] == 'like'
                                        ? Icons.favorite
                                        : Icons.settings_outlined,
                                size: 16,
                                color: notif['type'] == 'like'
                                    ? const Color(0xFFE53935)
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _deleteNotification(id),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close, size: 18, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
