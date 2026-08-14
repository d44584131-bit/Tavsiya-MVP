import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_review_card.dart';
import '../profile/profile_screen.dart' show AppLanguage;

/// "Все" у "Новых отзывов" на главном экране — полный список последних
/// отзывов по всем местам, подгружается страницами по 10 при прокрутке вниз.
class AllReviewsScreen extends StatefulWidget {
  final AppLanguage language;
  const AllReviewsScreen({super.key, required this.language});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  static const _pageSize = 10;
  final _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  List<PlaceReviewData> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final reviews = await SupabaseService.fetchRecentReviews(
          language: widget.language, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _hasMore = reviews.length == _pageSize;
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final more = await SupabaseService.fetchRecentReviews(
          language: widget.language, limit: _pageSize, offset: _reviews.length);
      if (!mounted) return;
      setState(() {
        _reviews = [..._reviews, ...more];
        _hasMore = more.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleReviewHelpful(PlaceReviewData review, bool like) async {
    if (!await ensureAuthenticated(context, s(context).authRequiredActionLike)) {
      return;
    }
    if (!mounted) return;
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index == -1) return;
    setState(() {
      _reviews[index] = review.copyWith(
        isHelpfulByMe: like,
        helpfulCount: review.helpfulCount + (like ? 1 : -1),
      );
    });
    try {
      await SupabaseService.toggleReviewHelpful(review.id, like: like);
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviews[index] = review);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).likeError)));
    }
  }

  Future<bool> _submitReviewReply(PlaceReviewData review, String text) async {
    if (!await ensureAuthenticated(context, s(context).authRequiredActionReply)) {
      return false;
    }
    if (!mounted) return false;
    try {
      await SupabaseService.submitReviewReply(reviewId: review.id, text: text);
      if (mounted) _load();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s(context).replySubmitError)));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s(context).recentReviewsTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              Text(s(context).loadErrorGeneric, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(s(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return EmptyState(
        icon: Icons.rate_review_outlined,
        title: s(context).noReviewsYet,
        subtitle: '',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _reviews.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _reviews.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return PlaceReviewCard(
          data: _reviews[i],
          onToggleHelpful: (like) => _toggleReviewHelpful(_reviews[i], like),
          onSubmitReply: (text) => _submitReviewReply(_reviews[i], text),
        );
      },
    );
  }
}
