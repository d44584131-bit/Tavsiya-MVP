import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/strings.dart';
import '../../services/permission_service.dart';
import '../../supabase_service.dart';
import '../../widgets/chip_selector.dart';
import '../../widgets/place_card.dart';

/// Форма создания/редактирования заведения (аккаунт заведения). placeId ==
/// null — создание нового места; иначе подгружает текущие данные и
/// сохраняет изменения через updateOwnedPlace (RLS пускает только владельца).
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

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
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

  // Фото добавляются только при создании — при редактировании ими управляет
  // вкладка "Фото" в BusinessDashboardScreen (там же можно и удалить).
  final _picker = ImagePicker();
  final List<Uint8List> _photoBytes = [];

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
        _isChain = place.isChain;
        _branchControllers
          ..clear()
          ..addAll(place.branches.map((b) => TextEditingController(text: b)));
        _category = place.category;
        _priceLevel = place.priceLevel;
        _rating = place.rating;
        _reviewsCount = place.reviewsCount;
        _district = place.district;
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
    for (final c in _phoneControllers) {
      c.dispose();
    }
    _websiteController.dispose();
    _instagramController.dispose();
    for (final c in _branchControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _category != null;

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
    if (!_canSave) return;
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? s(context).businessEditPlaceTitle
            : s(context).businessAddPlaceTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(s(context).businessNameLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _nameController, maxLines: 1),
                const SizedBox(height: 20),
                ChipSelector(
                  label: s(context).placeCategoryLabel,
                  options: _categoryKeys
                      .map((k) => s(context).categoryLabel(k))
                      .toList(),
                  selected: _category == null
                      ? null
                      : s(context).categoryLabel(_category!),
                  onSelected: (label) => setState(() {
                    _category = _categoryKeys.firstWhere(
                        (k) => s(context).categoryLabel(k) == label);
                  }),
                ),
                const SizedBox(height: 20),
                Text(s(context).businessDescriptionLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _descriptionController, maxLines: 3),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(s(context).businessAddressLabel,
                          style: theme.textTheme.titleMedium),
                    ),
                    Text(s(context).businessChainToggleLabel,
                        style: theme.textTheme.labelSmall),
                    Switch(value: _isChain, onChanged: _toggleChain),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_isChain)
                  _buildField(theme, _addressController, maxLines: 1)
                else ...[
                  for (var i = 0; i < _branchControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildField(theme, _branchControllers[i],
                                maxLines: 1,
                                hintText: s(context).branchAddressHint),
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
                Text(s(context).businessPhoneLabel,
                    style: theme.textTheme.titleMedium),
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
                Text(s(context).businessWebsiteLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _websiteController,
                    maxLines: 1, keyboardType: TextInputType.url),
                const SizedBox(height: 20),
                Text(s(context).businessInstagramLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _instagramController, maxLines: 1),
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
                if (!_isEditing) ...[
                  const SizedBox(height: 20),
                  Text(s(context).businessPhotosTab,
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
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
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
                                  border: Border.all(
                                      color: theme.dividerColor, width: 1.5),
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
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !_canSave || _isSaving ? null : _save,
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
            ),
    );
  }

  Widget _buildField(ThemeData theme, TextEditingController controller,
      {required int maxLines, TextInputType? keyboardType, String? hintText}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hintText,
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
