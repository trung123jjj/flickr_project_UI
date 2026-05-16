import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backend_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final result = await BackendService.getReports();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          final raw = result['data'];
          if (raw is List) {
            _reports = raw;
          } else if (raw is Map && raw['data'] is List) {
            _reports = raw['data'] as List;
          }
          print('[Reports] loaded ${_reports.length} reports');
        } else {
          print('[Reports] failed: ${result['message']}');
        }
        _isLoading = false;
      });
    }
  }

  void _confirmDeleteUser(BuildContext ctx, String username, String reportId) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete User'),
        content: Text('Permanently delete @$username and all their data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final result = await BackendService.deleteUser(username);
              if (mounted) {
                await BackendService.deleteReport(reportId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success'] == true
                        ? 'User @$username deleted'
                        : result['message'] ?? 'Failed to delete user'),
                    backgroundColor: const Color(0xFFE53935),
                  ),
                );
                _loadReports();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteReport(BuildContext ctx, String reportId) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Report'),
        content: const Text('Delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final result = await BackendService.deleteReport(reportId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success'] == true
                        ? 'Report deleted'
                        : result['message'] ?? 'Failed to delete report'),
                    backgroundColor: const Color(0xFFE53935),
                  ),
                );
                _loadReports();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _ReportAppBar(),
        body: const Center(
          child: Text('You do not have access to this page.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const _ReportAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No reports yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      final username = report['username']?.toString() ?? 'Unknown';
                      final message = report['message']?.toString() ?? '';
                      final commentContent = report['commentContent']?.toString() ?? '';
                      final createdAt = report['createdAt']?.toString() ?? '';

                      DateTime? timestamp;
                      try {
                        timestamp = DateTime.parse(createdAt);
                      } catch (_) {}

                      final timeText = timestamp != null
                          ? '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                          : '';

                      final reportId = report['_id']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                              child: const Icon(Icons.flag_outlined, color: Color(0xFFE53935), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '@$username',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 15),
                                        ),
                                        const TextSpan(
                                          text: ' is reported',
                                          style: TextStyle(fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(message, style: const TextStyle(fontSize: 14)),
                                  if (commentContent.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Reported content: $commentContent',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (timeText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(timeText, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 32,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.person_remove, size: 16, color: Color(0xFFE53935)),
                                          label: const Text('Delete user', style: TextStyle(fontSize: 12, color: Color(0xFFE53935))),
                                          onPressed: () => _confirmDeleteUser(context, username, reportId),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        height: 32,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE53935)),
                                          label: const Text('Delete report', style: TextStyle(fontSize: 12, color: Color(0xFFE53935))),
                                          onPressed: () => _confirmDeleteReport(context, reportId),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        height: 32,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.notifications_outlined, size: 16, color: Color(0xFFE53935)),
                                          label: const Text('Notice', style: TextStyle(fontSize: 12, color: Color(0xFFE53935))),
                                          onPressed: () async {
                                            final result = await BackendService.sendNotice(username, commentContent: commentContent);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(result['success'] == true
                                                      ? 'Notice sent to @$username'
                                                      : result['message'] ?? 'Failed to send notice'),
                                                  backgroundColor: const Color(0xFFE53935),
                                                ),
                                              );
                                            }
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
     );
   }
}

class _ReportAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReportAppBar();
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
        'Reports',
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
