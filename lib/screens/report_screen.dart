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
                      final createdAt = report['createdAt']?.toString() ?? '';

                      DateTime? timestamp;
                      try {
                        timestamp = DateTime.parse(createdAt);
                      } catch (_) {}

                      final timeText = timestamp != null
                          ? '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                          : '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                          child: const Icon(Icons.flag_outlined, color: Color(0xFFE53935), size: 20),
                        ),
                        title: Text.rich(
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(message, style: const TextStyle(fontSize: 14)),
                            if (timeText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(timeText, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
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
