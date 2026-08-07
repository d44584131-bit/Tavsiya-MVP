import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart' show AppLanguage;
import 'business_dashboard_screen.dart';
import 'business_place_form_screen.dart';

/// "Войти как заведение" — точка входа из профиля пользователя. Показывает
/// места, которыми управляет текущий аккаунт (place_owners), с возможностью
/// добавить новое. Тот же логин, что и обычный пользователь — разница
/// только в наборе экранов, открытых отсюда.
class BusinessScreen extends StatefulWidget {
  final AppLanguage language;
  const BusinessScreen({super.key, required this.language});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _places = const [];
  int _unreadNotifications = 0;

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
      final places = await SupabaseService.fetchOwnedPlaces();
      if (!mounted) return;
      setState(() {
        _places = places;
        _isLoading = false;
      });
      SupabaseService.fetchUnreadNotificationsCount().then((count) {
        if (mounted) setState(() => _unreadNotifications = count);
      }).catchError((_) {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    setState(() => _unreadNotifications = 0);
  }

  Future<void> _addPlace() async {
    final created = await Navigator.of(context).push<PlaceCardData>(
      MaterialPageRoute(builder: (_) => const BusinessPlaceFormScreen()),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s(context).businessCreatedSnackbar)),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BusinessDashboardScreen(place: created, language: widget.language),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openPlace(PlaceCardData place) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BusinessDashboardScreen(place: place, language: widget.language),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(s(context).businessListTitle),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('$_unreadNotifications'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _openNotifications,
          ),
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addPlace),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(theme)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(s(context).businessExitButton),
                ),
              ),
            ),
          ),
        ],
      ),
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
    if (_places.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: s(context).businessEmptyTitle,
        subtitle: s(context).businessEmptySubtitle,
        action: ElevatedButton(
            onPressed: _addPlace,
            child: Text(s(context).businessAddPlaceButton)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _places.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final place = _places[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPlace(place),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: theme.textTheme.titleMedium),
                      Text(s(context).categoryLabel(place.category),
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                if (place.status == 'pending' || place.status == 'rejected')
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (place.status == 'pending'
                              ? AppColors.accentOrange
                              : AppColors.negative)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      place.status == 'pending'
                          ? s(context).pendingBadge
                          : s(context).rejectedBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: place.status == 'pending'
                            ? AppColors.accentOrange
                            : AppColors.negative,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}
