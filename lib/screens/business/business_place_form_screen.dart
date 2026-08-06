import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
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
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  String? _category;
  String? _priceLevel;
  double _rating = 0;
  int _reviewsCount = 0;
  String _district = '';

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
        _phoneController.text = place.phone ?? '';
        _websiteController.text = place.website ?? '';
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
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _category != null;

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
    final phone = _phoneController.text.trim();
    final website = _websiteController.text.trim();
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
          priceLevel: _priceLevel,
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
          priceLevel: _priceLevel,
        );
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
                Text(s(context).businessAddressLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _addressController, maxLines: 1),
                const SizedBox(height: 20),
                Text(s(context).businessPhoneLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _phoneController,
                    maxLines: 1, keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                Text(s(context).businessWebsiteLabel,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildField(theme, _websiteController,
                    maxLines: 1, keyboardType: TextInputType.url),
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
      {required int maxLines, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
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
