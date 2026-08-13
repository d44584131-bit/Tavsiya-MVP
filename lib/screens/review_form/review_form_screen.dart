import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../l10n/strings.dart';
import '../../services/permission_service.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/place_card.dart';
import '../../widgets/star_rating_input.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/chip_selector.dart';
import '../profile/profile_screen.dart' show AppLanguage;

/// Черновик отзыва (таблица review_drafts) — сохраняется при выходе из формы
/// с незаконченным отзывом, показывается во вкладке "Черновики" в профиле.
class ReviewDraftData {
  final String id;
  final String? placeId;
  final String? placeName; // название существующего места или ещё не созданного
  final int? rating;
  final String? text;
  final String? pros;
  final String? cons;
  final String? priceLevel;
  final DateTime updatedAt;

  const ReviewDraftData({
    required this.id,
    this.placeId,
    this.placeName,
    this.rating,
    this.text,
    this.pros,
    this.cons,
    this.priceLevel,
    required this.updatedAt,
  });
}

class ReviewFormScreen extends StatefulWidget {
  final PlaceCardData?
      preselectedPlace; // если пришли с карточки места — шаг 1 пропускается
  final ReviewDraftData?
      initialDraft; // если продолжаем черновик — тоже пропускается
  final AppLanguage language;
  const ReviewFormScreen(
      {super.key,
      this.preselectedPlace,
      this.initialDraft,
      required this.language});

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  static const _maxChars = 500;
  bool get _hasPreselection =>
      widget.preselectedPlace != null || widget.initialDraft != null;
  late final _controller =
      PageController(initialPage: _hasPreselection ? 1 : 0);
  final _textController = TextEditingController();
  final _searchController = TextEditingController();

  late int _step = _hasPreselection ? 1 : 0;
  PlaceCardData? _selectedExistingPlace;
  String? _selectedBranch; // выбранный филиал — только для сетей заведений
  String? _newPlaceName;
  String? _newPlaceCategory;
  int _rating = 0;
  final _picker = ImagePicker();
  final List<Uint8List> _photoBytes = [];
  final _prosController = TextEditingController();
  final _consController = TextEditingController();
  String? _priceChip;
  bool _isSubmitting = false;
  String? _submitError;
  String?
      _draftId; // если продолжаем черновик — обновляем его вместо создания нового
  bool _reviewPublished = false; // возвращаем true при pop, чтобы вызывающий
  // экран знал, что нужно перезагрузить списки (например, "Мои отзывы" в профиле)

  Timer? _searchDebounce;
  bool _isSearchingPlaces = false;
  List<PlaceCardData> _placeResults = const [];

  static const _stepCount = 4;

  static const _newPlaceCategoryKeys = ['restaurant', 'cafe', 'park', 'mall'];
  static const _priceLevelKeys = ['budget', 'mid', 'mid_high', 'high'];

  String _priceLabel(String key) => s(context).priceLevelLabel(key);

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _draftId = draft.id;
      if (draft.placeId != null) {
        _selectedExistingPlace = PlaceCardData(
          id: draft.placeId!,
          name: draft.placeName ?? '',
          category: 'restaurant',
          rating: 0,
          reviewsCount: 0,
          district: '',
        );
      } else {
        _newPlaceName = draft.placeName;
      }
      _rating = draft.rating ?? 0;
      _textController.text = draft.text ?? '';
      _prosController.text = draft.pros ?? '';
      _consController.text = draft.cons ?? '';
      _priceChip = draft.priceLevel;
    } else {
      _selectedExistingPlace = widget.preselectedPlace;
    }
    _searchPlaces();
  }

  bool get _hasDraftableContent =>
      _selectedExistingPlace != null ||
      (_newPlaceName != null && _newPlaceName!.isNotEmpty) ||
      _rating > 0 ||
      _textController.text.trim().isNotEmpty ||
      _prosController.text.trim().isNotEmpty ||
      _consController.text.trim().isNotEmpty;

  Future<void> _maybeSaveDraft() async {
    if (_step == 3) {
      return; // отзыв уже опубликован, черновик уже удалён в _submit()
    }
    if (!_hasDraftableContent) {
      if (_draftId != null) {
        try {
          await SupabaseService.deleteDraft(_draftId!);
        } catch (_) {
          // не блокируем закрытие формы из-за ошибки сети
        }
      }
      return;
    }
    if (SupabaseService.currentUser == null) {
      return; // без входа черновики не сохраняем
    }
    try {
      _draftId = await SupabaseService.saveDraft(
        draftId: _draftId,
        placeId: _selectedExistingPlace?.id,
        placeNameDraft: _selectedExistingPlace == null ? _newPlaceName : null,
        rating: _rating,
        text: _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
        pros: _prosController.text.trim().isEmpty
            ? null
            : _prosController.text.trim(),
        cons: _consController.text.trim().isEmpty
            ? null
            : _consController.text.trim(),
        priceLevel: _priceChip,
      );
    } catch (_) {
      // не удалось сохранить черновик — не блокируем закрытие формы
    }
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
    _controller.animateToPage(step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _searchPlaces);
  }

  Future<void> _searchPlaces() async {
    setState(() => _isSearchingPlaces = true);
    try {
      final results =
          await SupabaseService.searchPlaces(query: _searchController.text);
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
      _selectedExistingPlace != null ||
      (_newPlaceName != null && _newPlaceCategory != null);
  bool get _canProceedFromStep2 =>
      _rating > 0 && _textController.text.trim().length >= 10;

  /// Для сети заведений отзыв обязательно привязывается к конкретному
  /// филиалу — показываем выбор перед тем, как пустить дальше по форме.
  /// Возвращает false, если пользователь закрыл выбор ничего не выбрав.
  Future<bool> _ensureBranchSelected() async {
    final place = _selectedExistingPlace;
    if (place == null || !place.isChain || place.branches.isEmpty) {
      return true;
    }
    if (_selectedBranch != null && place.branches.contains(_selectedBranch)) {
      return true;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(s(context).chooseBranchTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...place.branches.map((b) => ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(b),
                  onTap: () => Navigator.pop(context, b),
                )),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return false;
    setState(() => _selectedBranch = chosen);
    return true;
  }

  Future<void> _addPhoto() async {
    if (_photoBytes.length >= 6) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s(context).choosePhotoGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s(context).choosePhotoCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (!await PermissionService.ensurePhotoAccess(context, source)) return;
    if (!mounted) return;
    final file = await _picker.pickImage(
        source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes.add(bytes));
  }

  void _removePhoto(int index) => setState(() => _photoBytes.removeAt(index));

  Future<void> _submit() async {
    if (!await ensureAuthenticated(
        context, s(context).authRequiredActionReview)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final placeId = _selectedExistingPlace != null
          ? _selectedExistingPlace!.id
          : (await SupabaseService.createPlace(
                  name: _newPlaceName!, category: _newPlaceCategory!))
              .id;

      await SupabaseService.submitReview(
        placeId: placeId,
        rating: _rating,
        text: _textController.text.trim(),
        pros: _prosController.text.trim().isEmpty
            ? null
            : _prosController.text.trim(),
        cons: _consController.text.trim().isEmpty
            ? null
            : _consController.text.trim(),
        priceLevel: _priceChip,
        language: widget.language == AppLanguage.uz ? 'uz' : 'ru',
        photos: _photoBytes,
        branchAddress: _selectedBranch,
      );
      if (_draftId != null) {
        try {
          await SupabaseService.deleteDraft(_draftId!);
        } catch (_) {
          // отзыв уже опубликован — не блокируем успех из-за черновика
        }
      }
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _reviewPublished = true;
      });
      _goTo(3);
    } catch (e) {
      if (!mounted) return;
      // unique(place_id, user_id) — второй отзыв на то же место от того же
      // пользователя запрещён в БД; показываем понятную причину вместо общей ошибки.
      final isDuplicate = e is PostgrestException && e.code == '23505';
      setState(() {
        _isSubmitting = false;
        _submitError = isDuplicate
            ? s(context).reviewDuplicateError
            : s(context).reviewSubmitError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _maybeSaveDraft();
        if (!mounted) return;
        navigator.pop(_reviewPublished);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s(context).leaveReview),
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
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: List.generate(_stepCount, (i) {
          final isActive = i <= _step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == _stepCount - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color:
                    isActive ? theme.colorScheme.primary : theme.dividerColor,
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
          Text(s(context).placeStepTitle,
              style: theme.textTheme.headlineMedium),
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
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: s(context).placeSearchHint,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                          _selectedBranch = null;
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
                        _selectedBranch = null;
                      }),
                    ),
                  if (_newPlaceName != null) ...[
                    const SizedBox(height: 12),
                    ChipSelector(
                      label: s(context).placeCategoryLabel,
                      options: _newPlaceCategoryKeys
                          .map((k) => s(context).categoryLabel(k))
                          .toList(),
                      selected: _newPlaceCategory == null
                          ? null
                          : s(context).categoryLabel(_newPlaceCategory!),
                      onSelected: (label) => setState(() {
                        _newPlaceCategory = _newPlaceCategoryKeys.firstWhere(
                            (k) => s(context).categoryLabel(k) == label);
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
                Text(s(context).rateQuestion,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                StarRatingInput(
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(s(context).yourReviewLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLength: _maxChars,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s(context).reviewHint,
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary)),
              counterText: '${_textController.text.length}/$_maxChars',
            ),
          ),
          const SizedBox(height: 16),
          Text(s(context).photosOptionalLabel,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(
                  _photoBytes.length,
                  (i) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          image: DecorationImage(
                              image: MemoryImage(_photoBytes[i]),
                              fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removePhoto(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_photoBytes.length < 6)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _addPhoto,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 72,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: theme.dividerColor, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.add_rounded,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s(context).photosMaxHint,
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
          Text(s(context).prosQuestion,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.positive)),
          const SizedBox(height: 8),
          _buildProsConsField(
              theme, _prosController, AppColors.positive, s(context).prosHint),
          const SizedBox(height: 16),
          Text(s(context).consQuestion,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.negative)),
          const SizedBox(height: 8),
          _buildProsConsField(
              theme, _consController, AppColors.negative, s(context).consHint),
          const SizedBox(height: 24),
          ChipSelector(
            label: s(context).avgCheckLabel,
            options: _priceLevelKeys.map(_priceLabel).toList(),
            selected: _priceChip == null ? null : _priceLabel(_priceChip!),
            onSelected: (label) => setState(() => _priceChip =
                _priceLevelKeys.firstWhere((k) => _priceLabel(k) == label)),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            Text(_submitError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildProsConsField(ThemeData theme, TextEditingController controller,
      Color color, String hint) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: color)),
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
              child: Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary, size: 48),
            ),
            const SizedBox(height: 20),
            Text(s(context).reviewPublishedTitle,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              s(context).reviewPublishedSubtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                child: Text(s(context).stepDone),
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

    // Кнопка "Далее" молча отключается, пока шаг не заполнен — без этой
    // подсказки это выглядит как "кнопка не работает", хотя на самом деле
    // просто не хватает обязательных полей.
    final disabledHint = switch (_step) {
      0 when !_canProceedFromStep1 => s(context).placeStepHint,
      1 when _rating == 0 => s(context).rateStepHintNoRating,
      1 when _textController.text.trim().length < 10 =>
        s(context).rateStepHintShortText,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          if (disabledHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                disabledHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goTo(_step - 1),
                    child: Text(s(context).backButton),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: !canProceed || _isSubmitting
                      ? null
                      : () async {
                          if (isLastEditableStep) {
                            _submit();
                          } else {
                            if (_step == 0 && !await _ensureBranchSelected()) {
                              return;
                            }
                            _goTo(_step + 1);
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isLastEditableStep
                          ? s(context).publishButton
                          : s(context).nextButton),
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
  const _PlaceOption(
      {required this.name,
      required this.selected,
      required this.onTap,
      this.isNew = false});

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
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    selected ? theme.colorScheme.primary : theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(isNew ? Icons.add_location_alt_rounded : Icons.place_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNew ? s(context).addPlaceLabel(name) : name,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
