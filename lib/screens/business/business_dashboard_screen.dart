import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/strings.dart';
import '../../services/permission_service.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/place_review_card.dart';
import '../place/place_detail_screen.dart' show PlaceDetailData;
import '../profile/profile_screen.dart' show AppLanguage;
import 'business_place_form_screen.dart';

class PlaceOwnerPhotoData {
  final String id;
  final String storagePath;
  final String url;

  const PlaceOwnerPhotoData(
      {required this.id, required this.storagePath, required this.url});
}

/// Управление одним заведением: информация, официальные фото, отзывы.
/// Открывается из BusinessScreen после выбора места ("Войти как заведение").
class BusinessDashboardScreen extends StatefulWidget {
  final PlaceCardData place;
  final AppLanguage language;
  const BusinessDashboardScreen(
      {super.key, required this.place, required this.language});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);
  late PlaceCardData _place = widget.place;
  final _picker = ImagePicker();

  bool _isLoadingDetail = true;
  PlaceDetailData? _detail;

  bool _isLoadingPhotos = true;
  List<PlaceOwnerPhotoData> _photos = const [];
  bool _isUploadingPhoto = false;
  final Set<String> _deletingPhotoIds = {};

  bool _isLoadingReviews = true;
  List<PlaceReviewData> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadPhotos();
    _loadReviews();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await SupabaseService.fetchPlaceById(_place.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDetail = false);
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoadingPhotos = true);
    try {
      final photos = await SupabaseService.fetchOwnedPlacePhotos(_place.id);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _isLoadingPhotos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPhotos = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final reviews = await SupabaseService.fetchApprovedReviews(_place.id,
          language: widget.language);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _editInfo() async {
    final updated = await Navigator.of(context).push<PlaceCardData>(
      MaterialPageRoute(
          builder: (_) => BusinessPlaceFormScreen(placeId: _place.id)),
    );
    if (updated != null && mounted) {
      setState(() => _place = updated);
      _loadDetail();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).businessSavedSnackbar)),
      );
    }
  }

  Future<void> _addPhoto() async {
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
    setState(() => _isUploadingPhoto = true);
    try {
      await SupabaseService.addOwnedPlacePhoto(_place.id, bytes);
      await _loadPhotos();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s(context).businessPhotoAddError)),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto(PlaceOwnerPhotoData photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s(context).deletePhotoConfirmTitle),
        content: Text(s(context).deletePhotoConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s(context).cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s(context).deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingPhotoIds.add(photo.id));
    try {
      await SupabaseService.deleteOwnedPlacePhoto(photo);
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((p) => p.id != photo.id).toList();
        _deletingPhotoIds.remove(photo.id);
      });
    } catch (_) {
      if (mounted) setState(() => _deletingPhotoIds.remove(photo.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_place.name),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined), onPressed: _editInfo),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(text: s(context).businessInfoTab),
            Tab(text: s(context).businessPhotosTab),
            Tab(text: s(context).businessReviewsTab),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_detail?.status == 'pending' || _detail?.status == 'rejected')
            _buildStatusBanner(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(theme),
                _buildPhotosTab(theme),
                _buildReviewsTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    final isPending = _detail?.status == 'pending';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: (isPending ? AppColors.accentOrange : AppColors.negative)
          .withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(isPending ? Icons.hourglass_top_rounded : Icons.block_rounded,
              size: 18,
              color: isPending ? AppColors.accentOrange : AppColors.negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPending
                  ? s(context).businessPendingBanner
                  : s(context).businessRejectedBanner,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(ThemeData theme) {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = _detail;
    final rows = [
      (
        s(context).businessDescriptionLabel,
        detail?.description ?? s(context).notSpecified
      ),
      (
        s(context).businessAddressLabel,
        detail?.address ?? s(context).notSpecified
      ),
      (s(context).businessPhoneLabel, detail?.phone ?? s(context).notSpecified),
      (
        s(context).businessWebsiteLabel,
        detail?.website ?? s(context).notSpecified
      ),
      (s(context).avgCheckLabel, detail?.priceLevelLabel ?? '—'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(_place.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(s(context).categoryLabel(_place.category),
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _editInfo,
          icon: const Icon(Icons.edit_outlined),
          label: Text(s(context).businessEditPlaceTitle),
        ),
        const SizedBox(height: 20),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotosTab(ThemeData theme) {
    if (_isLoadingPhotos) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        _photos.isEmpty
            ? EmptyState(
                icon: Icons.photo_camera_outlined,
                title: s(context).businessNoPhotos,
                subtitle: s(context).businessNoPhotosSubtitle,
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, i) {
                  final photo = _photos[i];
                  final isDeleting = _deletingPhotoIds.contains(photo.id);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photo.url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stack) => Container(
                            color: theme.dividerColor,
                            child: const Icon(Icons.broken_image_rounded),
                          ),
                        ),
                      ),
                      if (isDeleting)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.black45,
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: InkWell(
                          onTap:
                              isDeleting ? null : () => _deletePhoto(photo),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _isUploadingPhoto ? null : _addPhoto,
            child: _isUploadingPhoto
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_a_photo_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(ThemeData theme) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Text(s(context).noReviewsYet, style: theme.textTheme.bodyMedium),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _reviews.length,
      itemBuilder: (context, i) => PlaceReviewCard(data: _reviews[i]),
    );
  }
}
