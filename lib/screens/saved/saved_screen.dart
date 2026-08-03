import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../auth/auth_screen.dart';

class SavedScreen extends StatefulWidget {
  final void Function(PlaceCardData place)? onPlaceTap;
  const SavedScreen({super.key, this.onPlaceTap});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _tab = 0; // 0 = места, 1 = отзывы

  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _savedPlaces = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _savedPlaces = const [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final places = await SupabaseService.fetchSavedPlaces();
      if (!mounted) return;
      setState(() {
        _savedPlaces = places;
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

  Future<void> _openAuth() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Сохранённое')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentToggle(
                    label: 'Места',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentToggle(
                    label: 'Отзывы',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _buildPlacesList(theme) : _buildReviewsEmpty(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(ThemeData theme) {
    if (SupabaseService.currentUser == null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Войдите, чтобы сохранять места',
        subtitle: 'Сохранённые места привязаны к вашему аккаунту',
        action: ElevatedButton(onPressed: _openAuth, child: const Text('Войти')),
      );
    }
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
              Text('Не удалось загрузить сохранённые места', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_savedPlaces.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Пока нет сохранённых мест',
        subtitle: 'Нажмите на иконку закладки на карточке места, чтобы сохранить его сюда',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
        itemCount: _savedPlaces.length,
        itemBuilder: (context, i) {
          final p = _savedPlaces[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => widget.onPlaceTap?.call(p),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.place_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: theme.textTheme.titleMedium),
                          Text('${p.categoryLabel} · ${p.district}', style: theme.textTheme.labelSmall),
                        ],
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

  Widget _buildReviewsEmpty() {
    return const EmptyState(
      icon: Icons.rate_review_outlined,
      title: 'Пока нет сохранённых отзывов',
      subtitle: 'Отмечайте полезные отзывы — они соберутся здесь',
    );
  }
}

class _SegmentToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
