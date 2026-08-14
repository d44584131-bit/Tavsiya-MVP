import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/strings.dart';
import '../../services/location_service.dart';
import '../../services/permission_service.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/chip_selector.dart';
import '../../widgets/place_card.dart';

/// Форма создания/редактирования заведения (аккаунт заведения). placeId ==
/// null — создание нового места; иначе подгружает текущие данные и
/// сохраняет изменения через updateOwnedPlace (RLS пускает только владельца).
/// Двухшаговый визард: 1 — основное (название/категория/описание/контакты),
/// 2 — фото (только при создании) и часы работы.
class BusinessPlaceFormScreen extends StatefulWidget {
  final String? placeId;
  const BusinessPlaceFormScreen({super.key, this.placeId});

  @override
  State<BusinessPlaceFormScreen> createState() =>
      _BusinessPlaceFormScreenState();
}

class _BusinessPlaceFormScreenState extends State<BusinessPlaceFormScreen> {
  static const _categoryKeys = ['restaurant', 'cafe', 'park', 'mall'];
  static const _priceLevelKeys = ['budget', 'mid', 'mid_high', 'high'];
  static const _stepCount = 2;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  // Несколько номеров телефона хранятся в одной текстовой колонке `phone`
  // через запятую — без отдельной таблицы/миграции.
  static const _phoneCountryCode = '+998 ';
  final List<TextEditingController> _phoneControllers = [
    _newPhoneController()
  ];

  static TextEditingController _newPhoneController([String? text]) =>
      TextEditingController(text: text ?? _phoneCountryCode)
        ..selection = TextSelection.collapsed(
            offset: (text ?? _phoneCountryCode).length);
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  // Сеть заведений — один профиль, несколько адресов филиалов; хранится
  // массивом на places.branches, без отдельной таблицы (см. schema.sql).
  bool _isChain = false;
  final List<TextEditingController> _branchControllers = [];
  String? _category;
  String? _priceLevel;
  double _rating = 0;
  int _reviewsCount = 0;
  String _district = '';
  double? _latitude;
  double? _longitude;
  bool _isCapturingLocation = false;

  // Фото добавляются только при создании — при редактировании ими управляет
  // вкладка "Фото" в BusinessDashboardScreen (там же можно и удалить).
  final _picker = ImagePicker();
  final List<Uint8List> _photoBytes = [];

  final _pageController = PageController();
  int _step = 0;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.placeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final place = await SupabaseService.fetchPlaceById(widget.placeId!);
      if (!mounted) return;
      setState(() {
        _nameController.text = place.name;
        _descriptionController.text = place.description ?? '';
        _addressController.text = place.address ?? '';
        final phones = (place.phone ?? '')
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        _phoneControllers
          ..clear()
          ..addAll(phones.isEmpty
              ? [_newPhoneController()]
              : phones.map((p) => _newPhoneController(p)));
        _websiteController.text = place.website ?? '';
        _instagramController.text = place.instagram ?? '';
        _hoursController.text = place.hours ?? '';
        _isChain = place.isChain;
        _branchControllers
          ..clear()
          ..addAll(place.branches.map((b) => TextEditingController(text: b)));
        _category = place.category;
        _priceLevel = place.priceLevel;
        _rating = place.rating;
        _reviewsCount = place.reviewsCount;
        _district = place.district;
        _latitude = place.latitude;
        _longitude = place.longitude;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = s(context).loadErrorGeneric;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    for (final c in _phoneControllers) {
      c.dispose();
    }
    _websiteController.dispose();
    _instagramController.dispose();
    for (final c in _branchControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  bool get _canProceedStep1 =>
      _nameController.text.trim().isNotEmpty && _category != null;

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  void _addPhoneField() =>
      setState(() => _phoneControllers.add(_newPhoneController()));

  void _removePhoneField(int index) => setState(() {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
      });

  void _toggleChain(bool value) => setState(() {
        _isChain = value;
        // При переходе "одиночная точка" -> "сеть" не теряем уже введённый
        // адрес — подставляем его первым филиалом вместо пустого поля.
        if (value && _branchControllers.isEmpty) {
          _branchControllers.add(
              TextEditingController(text: _addressController.text.trim()));
        }
      });

  void _addBranchField() =>
      setState(() => _branchControllers.add(TextEditingController()));

  void _removeBranchField(int index) => setState(() {
        _branchControllers[index].dispose();
        _branchControllers.removeAt(index);
      });

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isCapturingLocation = false);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s(context).locationCaptureError)));
      return;
    }
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).locationCapturedSnackbar)));
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

  Future<void> _save() async {
    if (!_canProceedStep1) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final name = _nameController.text.trim();
    final category = _category!;
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneControllers
        .map((c) => c.text.trim())
        .where((p) => p.isNotEmpty && p != _phoneCountryCode.trim())
        .join(', ');
    final website = _websiteController.text.trim();
    final instagram = _instagramController.text.trim();
    final hours = _hoursController.text.trim();
    final branches = _isChain
        ? _branchControllers
            .map((c) => c.text.trim())
            .where((b) => b.isNotEmpty)
            .toList()
        : const <String>[];
    try {
      if (_isEditing) {
        await SupabaseService.updateOwnedPlace(
          widget.placeId!,
          name: name,
          category: category,
          description: description.isEmpty ? null : description,
          address: address.isEmpty ? null : address,
          phone: phone.isEmpty ? null : phone,
          website: website.isEmpty ? null : website,
          instagram: instagram.isEmpty ? null : instagram,
          priceLevel: _priceLevel,
          hours: hours.isEmpty ? null : hours,
          latitude: _latitude,
          longitude: _longitude,
          isChain: _isChain,
          branches: branches,
        );
        if (!mounted) return;
        Navigator.pop(
          context,
          PlaceCardData(
            id: widget.placeId!,
            name: name,
            category: category,
            rating: _rating,
            reviewsCount: _reviewsCount,
            district: _district,
            isChain: _isChain,
            branches: branches,
            latitude: _latitude,
            longitude: _longitude,
          ),
        );
      } else {
        final created = await SupabaseService.createOwnedPlace(
          name: name,
          category: category,
          description: description.isEmpty ? null : description,
          address: address.isEmpty ? null : address,
          phone: phone.isEmpty ? null : phone,
          website: website.isEmpty ? null : website,
          instagram: instagram.isEmpty ? null : instagram,
          priceLevel: _priceLevel,
          hours: hours.isEmpty ? null : hours,
          latitude: _latitude,
          longitude: _longitude,
          isChain: _isChain,
          branches: branches,
        );
        for (final bytes in _photoBytes) {
          try {
            await SupabaseService.addOwnedPlacePhoto(created.id, bytes);
          } catch (_) {
            // место уже создано — не блокируем успех из-за ошибки загрузки фото
          }
        }
        if (!mounted) return;
        Navigator.pop(context, created);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = s(context).businessSaveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(context),
                        _buildStep2(context),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  if (_step > 0) {
                    _goToStep(_step - 1);
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${s(context).stepLabel(_step + 1, _stepCount)} · ${_step == 0 ? s(context).businessStepBasicLabel : s(context).businessStepPhotosLabel}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: theme.textTheme.labelSmall?.color),
          ),
          const SizedBox(height: 4),
          Text(
            _isEditing
                ? s(context).businessEditPlaceTitle
                : s(context).businessAddPlaceTitle,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_stepCount, (i) {
              final isActive = i <= _step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == _stepCount - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: theme.textTheme.labelSmall?.color));
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.tintedShadow(
                isDark: isDark, opacity: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _card(context, children: [
          _fieldLabel(context, s(context).businessNameLabel),
          const SizedBox(height: 8),
          _buildField(theme, _nameController, maxLines: 1),
          const SizedBox(height: 20),
          _fieldLabel(context, s(context).placeCategoryLabel),
          const SizedBox(height: 8),
          _CategoryChipRow(
            categoryKeys: _categoryKeys,
            selected: _category,
            onSelected: (key) => setState(() => _category = key),
          ),
          const SizedBox(height: 20),
          _fieldLabel(context, s(context).businessDescriptionLabel),
          const SizedBox(height: 8),
          _buildField(theme, _descriptionController, maxLines: 3),
        ]),
        _card(context, children: [
          Row(
            children: [
              Expanded(
                child: _fieldLabel(context, s(context).businessAddressLabel),
              ),
              Text(s(context).businessChainToggleLabel,
                  style: theme.textTheme.labelSmall),
              Switch(value: _isChain, onChanged: _toggleChain),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isChain)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                    child: _buildField(theme, _addressController,
                        maxLines: 1, prefixIcon: Icons.place_outlined)),
                const SizedBox(width: 8),
                _LocationCaptureButton(
                  isCaptured: _latitude != null,
                  isLoading: _isCapturingLocation,
                  onTap: _captureLocation,
                ),
              ],
            )
          else ...[
            for (var i = 0; i < _branchControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildField(theme, _branchControllers[i],
                          maxLines: 1, hintText: s(context).branchAddressHint),
                    ),
                    if (_branchControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _removeBranchField(i),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _addBranchField,
              icon: const Icon(Icons.add_rounded),
              label: Text(s(context).addBranchButton),
            ),
          ],
          const SizedBox(height: 20),
          _fieldLabel(context, s(context).businessPhoneLabel),
          const SizedBox(height: 8),
          for (var i = 0; i < _phoneControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildField(theme, _phoneControllers[i],
                        maxLines: 1, keyboardType: TextInputType.phone),
                  ),
                  if (_phoneControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removePhoneField(i),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: _addPhoneField,
            icon: const Icon(Icons.add_rounded),
            label: Text(s(context).addPhoneNumberButton),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, s(context).businessWebsiteLabel),
                    const SizedBox(height: 8),
                    _buildField(theme, _websiteController,
                        maxLines: 1, keyboardType: TextInputType.url),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, s(context).businessInstagramLabel),
                    const SizedBox(height: 8),
                    _buildField(theme, _instagramController, maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ChipSelector(
            label: s(context).avgCheckLabel,
            options: _priceLevelKeys
                .map((k) => s(context).priceLevelLabel(k))
                .toList(),
            selected: _priceLevel == null
                ? null
                : s(context).priceLevelLabel(_priceLevel!),
            onSelected: (label) => setState(() {
              _priceLevel = _priceLevelKeys.firstWhere(
                  (k) => s(context).priceLevelLabel(k) == label);
            }),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: !_canProceedStep1 ? null : () => _goToStep(1),
            child: Text(s(context).businessNextPhotosButton),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (!_isEditing)
          _card(context, children: [
            _fieldLabel(context, s(context).businessPhotosTab),
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
              child: Text(s(context).photosMaxHint,
                  style: theme.textTheme.labelSmall),
            ),
          ]),
        _card(context, children: [
          _fieldLabel(context, s(context).businessHoursLabel),
          const SizedBox(height: 8),
          _buildField(theme, _hoursController,
              maxLines: 1, hintText: s(context).businessHoursHint),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(s(context).saveButton),
          ),
        ),
      ],
    );
  }

  Widget _buildField(ThemeData theme, TextEditingController controller,
      {required int maxLines,
      TextInputType? keyboardType,
      String? hintText,
      IconData? prefixIcon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary)),
      ),
    );
  }
}

/// Круглая кнопка-иконка в духе шапки профиля/бизнес-экрана — используется
/// здесь только для "назад", но стиль тот же самый (обводка вместо заливки).
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      shape: CircleBorder(side: BorderSide(color: theme.dividerColor)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: theme.textTheme.bodyLarge?.color),
        ),
      ),
    );
  }
}

/// Кнопка "определить координаты по GPS" рядом с полем адреса — заполняет
/// latitude/longitude места текущим местоположением устройства (используется
/// потом для расчёта расстояния в шаге выбора места формы отзыва).
class _LocationCaptureButton extends StatelessWidget {
  final bool isCaptured;
  final bool isLoading;
  final VoidCallback onTap;
  const _LocationCaptureButton(
      {required this.isCaptured,
      required this.isLoading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isCaptured ? AppColors.positive : theme.colorScheme.primary;
    return Tooltip(
      message: s(context).useCurrentLocationTooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(
                    isCaptured
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    size: 20,
                    color: color,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Цветные плашки категории (заливка тем же фирменным цветом, что и на
/// карточках мест) — активная категория сплошная, остальные приглушённые.
class _CategoryChipRow extends StatelessWidget {
  final List<String> categoryKeys;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _CategoryChipRow(
      {required this.categoryKeys,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoryKeys.map((key) {
        final isActive = key == selected;
        final color = AppColors.categoryColor(key);
        final onDark = AppColors.categoryOnDark(key);
        final activeTextColor = onDark ? Colors.white : const Color(0xFF111111);
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.tag),
          child: InkWell(
            onTap: () => onSelected(key),
            borderRadius: BorderRadius.circular(AppRadius.tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? color : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.tag),
                border: Border.all(
                    color: isActive ? color : color.withValues(alpha: 0.3)),
              ),
              child: Text(
                s(context).categoryLabel(key),
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isActive
                      ? activeTextColor
                      : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
