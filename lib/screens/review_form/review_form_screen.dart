import 'dart:async';

import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/place_card.dart';
import '../../widgets/star_rating_input.dart';
import '../../widgets/chip_selector.dart';
import '../auth/auth_screen.dart';
import '../profile/profile_screen.dart' show AppLanguage;

class ReviewFormScreen extends StatefulWidget {
  final PlaceCardData? preselectedPlace; // если пришли с карточки места — шаг 1 пропускается
  final AppLanguage language;
  const ReviewFormScreen({super.key, this.preselectedPlace, required this.language});

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  static const _maxChars = 500;
  final _controller = PageController();
  final _textController = TextEditingController();
  final _searchController = TextEditingController();

  late int _step = widget.preselectedPlace != null ? 1 : 0;
  PlaceCardData? _selectedExistingPlace;
  String? _newPlaceName;
  String? _newPlaceCategory;
  int _rating = 0;
  int _photosCount = 0;
  final _prosController = TextEditingController();
  final _consController = TextEditingController();
  String? _priceChip;
  String? _withWhomChip;
  bool _isSubmitting = false;
  String? _submitError;

  Timer? _searchDebounce;
  bool _isSearchingPlaces = false;
  List<PlaceCardData> _placeResults = const [];

  static const _steps = ['Место', 'Оценка', 'Детали', 'Готово'];

  static const _newPlaceCategories = [
    ('restaurant', 'Ресторан'),
    ('cafe', 'Кафе'),
    ('park', 'Парк'),
    ('mall', 'ТЦ'),
  ];

  static const _priceLevelValues = {
    'до 50 000': 'budget',
    '50–150 тыс': 'mid',
    '150–300 тыс': 'mid_high',
    '300 тыс+': 'high',
  };

  static const _withWhomValues = {
    'Один(а)': 'alone',
    'С партнёром': 'partner',
    'С друзьями': 'friends',
    'С семьёй': 'family',
  };

  @override
  void initState() {
    super.initState();
    _selectedExistingPlace = widget.preselectedPlace;
    _searchPlaces();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _textController.dispose();
    _searchController.dispose();
    _prosController.dispose();
    _consController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _controller.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _searchPlaces);
  }

  Future<void> _searchPlaces() async {
    setState(() => _isSearchingPlaces = true);
    try {
      final results = await SupabaseService.searchPlaces(query: _searchController.text);
      if (!mounted) return;
      setState(() {
        _placeResults = results;
        _isSearchingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingPlaces = false);
    }
  }

  bool get _canProceedFromStep1 =>
      _selectedExistingPlace != null || (_newPlaceName != null && _newPlaceCategory != null);
  bool get _canProceedFromStep2 => _rating > 0 && _textController.text.trim().length >= 10;

  Future<void> _submit() async {
    if (SupabaseService.currentUser == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!mounted || SupabaseService.currentUser == null) return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final placeId = _selectedExistingPlace != null
          ? _selectedExistingPlace!.id
          : (await SupabaseService.createPlace(name: _newPlaceName!, category: _newPlaceCategory!)).id;

      await SupabaseService.submitReview(
        placeId: placeId,
        rating: _rating,
        text: _textController.text.trim(),
        pros: _prosController.text.trim().isEmpty ? null : _prosController.text.trim(),
        cons: _consController.text.trim().isEmpty ? null : _consController.text.trim(),
        priceLevel: _priceChip == null ? null : _priceLevelValues[_priceChip],
        withWhom: _withWhomChip == null ? null : _withWhomValues[_withWhomChip],
        language: widget.language == AppLanguage.uz ? 'uz' : 'ru',
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _goTo(3);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'Не удалось отправить отзыв. Проверьте подключение и попробуйте снова';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оставить отзыв'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgress(theme),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPlaceStep(theme),
                _buildRatingStep(theme),
                _buildDetailsStep(theme),
                _buildDoneStep(theme),
              ],
            ),
          ),
          if (_step < 3) _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isActive = i <= _step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary : theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Шаг 1: выбор места ---
  Widget _buildPlaceStep(ThemeData theme) {
    final query = _searchController.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('О каком месте отзыв?', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Название места…',
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (_isSearchingPlaces)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  ..._placeResults.map((p) => _PlaceOption(
                        name: p.name,
                        selected: _selectedExistingPlace?.id == p.id,
                        onTap: () => setState(() {
                          _selectedExistingPlace = p;
                          _newPlaceName = null;
                          _newPlaceCategory = null;
                        }),
                      )),
                  if (query.isNotEmpty)
                    _PlaceOption(
                      name: query,
                      isNew: true,
                      selected: _newPlaceName == query,
                      onTap: () => setState(() {
                        _newPlaceName = query;
                        _selectedExistingPlace = null;
                      }),
                    ),
                  if (_newPlaceName != null) ...[
                    const SizedBox(height: 12),
                    ChipSelector(
                      label: 'Категория места',
                      options: _newPlaceCategories.map((c) => c.$2).toList(),
                      selected: _newPlaceCategories
                          .firstWhere((c) => c.$1 == _newPlaceCategory, orElse: () => ('', ''))
                          .$2,
                      onSelected: (label) => setState(() {
                        _newPlaceCategory = _newPlaceCategories.firstWhere((c) => c.$2 == label).$1;
                      }),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Шаг 2: рейтинг + текст + фото ---
  Widget _buildRatingStep(ThemeData theme) {
    final placeName = _selectedExistingPlace?.name ?? _newPlaceName;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placeName != null)
            Text(placeName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text('Как оцените место?', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                StarRatingInput(value: _rating, onChanged: (v) => setState(() => _rating = v)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Ваш отзыв', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLength: _maxChars,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Расскажите, что понравилось или нет…',
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary)),
              counterText: '${_textController.text.length}/$_maxChars',
            ),
          ),
          const SizedBox(height: 16),
          Text('Фото (по желанию)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(
                  _photosCount,
                  (i) => Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.image_rounded, color: theme.textTheme.bodyMedium?.color),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _photosCount = (_photosCount + 1).clamp(0, 6)),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Загрузка фото появится в одном из следующих обновлений',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  // --- Шаг 3: плюсы/минусы + доп. параметры ---
  Widget _buildDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что понравилось?', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.positive)),
          const SizedBox(height: 8),
          _buildProsConsField(theme, _prosController, AppColors.positive, 'Например: вкусно, быстро, приветливо'),
          const SizedBox(height: 16),
          Text('Что не понравилось?', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.negative)),
          const SizedBox(height: 8),
          _buildProsConsField(theme, _consController, AppColors.negative, 'Например: долго ждали, шумно'),
          const SizedBox(height: 24),
          ChipSelector(
            label: 'Средний чек',
            options: const ['до 50 000', '50–150 тыс', '150–300 тыс', '300 тыс+'],
            selected: _priceChip,
            onSelected: (v) => setState(() => _priceChip = v),
          ),
          const SizedBox(height: 20),
          ChipSelector(
            label: 'С кем были',
            options: const ['Один(а)', 'С партнёром', 'С друзьями', 'С семьёй'],
            selected: _withWhomChip,
            onSelected: (v) => setState(() => _withWhomChip = v),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            Text(_submitError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildProsConsField(ThemeData theme, TextEditingController controller, Color color, String hint) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color)),
      ),
    );
  }

  // --- Шаг 4: подтверждение публикации ---
  Widget _buildDoneStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 48),
            ),
            const SizedBox(height: 20),
            Text('Отзыв отправлен!', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Он будет опубликован после проверки модератором — обычно это занимает не больше суток',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final canProceed = switch (_step) {
      0 => _canProceedFromStep1,
      1 => _canProceedFromStep2,
      2 => true,
      _ => true,
    };
    final isLastEditableStep = _step == 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          if (isLastEditableStep)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Отзыв будет проверен модератором перед публикацией',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goTo(_step - 1),
                    child: const Text('Назад'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: !canProceed || _isSubmitting
                      ? null
                      : () {
                          if (isLastEditableStep) {
                            _submit();
                          } else {
                            _goTo(_step + 1);
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isLastEditableStep ? 'Опубликовать' : 'Далее'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceOption extends StatelessWidget {
  final String name;
  final bool selected;
  final bool isNew;
  final VoidCallback onTap;
  const _PlaceOption({required this.name, required this.selected, required this.onTap, this.isNew = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(isNew ? Icons.add_location_alt_rounded : Icons.place_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNew ? 'Добавить «$name»' : name,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
