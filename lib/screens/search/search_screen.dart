import 'dart:async';

import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../widgets/place_card.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  final void Function(PlaceCardData place)? onPlaceTap;
  const SearchScreen({super.key, this.onPlaceTap});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String? _categoryFilter; // null = все категории

  Timer? _debounce;
  bool _isLoading = true;
  bool _hasError = false;
  List<PlaceCardData> _results = const [];

  static const _categories = [
    (null, 'Все'),
    ('restaurant', 'Рестораны'),
    ('cafe', 'Кафе'),
    ('park', 'Парки'),
    ('mall', 'ТЦ'),
  ];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
    setState(() {}); // обновить очищаемую иконку и т.п. без ожидания дебаунса
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await SupabaseService.searchPlaces(
        query: _controller.text,
        category: _categoryFilter,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
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
      appBar: AppBar(title: const Text('Поиск')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TextField(
                controller: _controller,
                onChanged: (_) => _onQueryChanged(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Найти место…',
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (key, label) = _categories[i];
                final isActive = _categoryFilter == key;
                return GestureDetector(
                  onTap: () => setState(() {
                    _categoryFilter = key;
                    _search();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? theme.colorScheme.primary : theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? theme.colorScheme.primary : theme.dividerColor),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
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
              Text('Не удалось загрузить результаты', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _search, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить запрос или выбрать другую категорию',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final p = _results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SearchResultTile(data: p, onTap: () => widget.onPlaceTap?.call(p)),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final PlaceCardData data;
  final VoidCallback onTap;
  const _SearchResultTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
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
                  Text(data.name, style: theme.textTheme.titleMedium),
                  Text('${data.categoryLabel} · ${data.district}', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Colors.orange),
                Text(data.rating.toStringAsFixed(1), style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
