import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<NotificationData> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await SupabaseService.fetchNotifications();
      // Помечаем всё прочитанным при открытии экрана — бейдж на профиле
      // сбросится сразу, до того как пользователь дочитает список.
      await SupabaseService.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s(context).notificationsTitle)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s(context).loadErrorGeneric,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_none_rounded,
        title: s(context).noNotificationsTitle,
        subtitle: s(context).noNotificationsSubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _items.length,
        itemBuilder: (context, i) => NotificationTile(data: _items[i]),
      ),
    );
  }
}
