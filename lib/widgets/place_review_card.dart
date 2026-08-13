import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'photo_viewer_screen.dart';
import 'reviewer_level_badge.dart';

class ReviewReplyData {
  final String id;
  final String authorName;
  final String text;
  final bool isOwnerReply;
  final DateTime createdAt;

  const ReviewReplyData({
    required this.id,
    required this.authorName,
    required this.text,
    required this.isOwnerReply,
    required this.createdAt,
  });
}

class PlaceReviewData {
  final String id;
  final String authorName;
  final int stars;
  final String text;
  final List<String> photoUrls; // публичные URL фото, приложенных к отзыву
  final String? pros;
  final String? cons;
  final String? priceLevel; // 'budget' | 'mid' | 'mid_high' | 'high'
  final DateTime? createdAt;
  final String? moderationStatus; // 'pending' | 'rejected' | null (= approved)
  final int?
      authorReviewsCount; // null там, где автор — не другой пользователь (напр. "Мои отзывы")
  final String?
      placeName; // видно там, где отзывы разных мест показаны вместе (лента на главной)
  final int helpfulCount; // лайки — переиспользует review_helpful_votes
  final bool isHelpfulByMe;
  final List<ReviewReplyData> replies;
  final String? branchAddress; // выбранный филиал — только у сетей заведений

  const PlaceReviewData({
    required this.id,
    required this.authorName,
    required this.stars,
    required this.text,
    this.photoUrls = const [],
    this.pros,
    this.cons,
    this.priceLevel,
    this.createdAt,
    this.moderationStatus,
    this.authorReviewsCount,
    this.placeName,
    this.helpfulCount = 0,
    this.isHelpfulByMe = false,
    this.replies = const [],
    this.branchAddress,
  });

  PlaceReviewData copyWith({
    int? helpfulCount,
    bool? isHelpfulByMe,
    List<ReviewReplyData>? replies,
  }) {
    return PlaceReviewData(
      id: id,
      authorName: authorName,
      stars: stars,
      text: text,
      photoUrls: photoUrls,
      pros: pros,
      cons: cons,
      priceLevel: priceLevel,
      createdAt: createdAt,
      moderationStatus: moderationStatus,
      authorReviewsCount: authorReviewsCount,
      placeName: placeName,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isHelpfulByMe: isHelpfulByMe ?? this.isHelpfulByMe,
      replies: replies ?? this.replies,
      branchAddress: branchAddress,
    );
  }
}

class PlaceReviewCard extends StatefulWidget {
  final PlaceReviewData data;
  // null — лайк/ответ недоступны в этом контексте (например, лента "Новые
  // отзывы" на главной): кнопки скрываются, счётчик лайков просто виден.
  final ValueChanged<bool>? onToggleHelpful;
  final Future<bool> Function(String text)? onSubmitReply;
  const PlaceReviewCard(
      {super.key, required this.data, this.onToggleHelpful, this.onSubmitReply});

  @override
  State<PlaceReviewCard> createState() => _PlaceReviewCardState();
}

class _PlaceReviewCardState extends State<PlaceReviewCard> {
  bool _showReplyBox = false;
  bool _isSubmittingReply = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || widget.onSubmitReply == null || _isSubmittingReply) {
      return;
    }
    setState(() => _isSubmittingReply = true);
    final ok = await widget.onSubmitReply!(text);
    if (!mounted) return;
    setState(() => _isSubmittingReply = false);
    if (ok) {
      _replyController.clear();
      setState(() => _showReplyBox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  data.authorName.isNotEmpty
                      ? data.authorName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              // Expanded — чтобы имя всегда занимало ровно место до звёзд,
              // а не только свою фактическую ширину (иначе звёзды сдвигались
              // бы в зависимости от длины имени).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(data.authorName,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (data.authorReviewsCount != null) ...[
                          const SizedBox(width: 6),
                          ReviewerLevelBadge(
                              reviewsCount: data.authorReviewsCount!),
                        ],
                      ],
                    ),
                    if (data.placeName != null) ...[
                      const SizedBox(height: 2),
                      Text(data.placeName!,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (data.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(_formatDate(data.createdAt!),
                          style: theme.textTheme.labelSmall),
                    ],
                    if (data.branchAddress != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 12,
                                color: theme.textTheme.bodyMedium?.color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${s(context).branchBadgePrefix}: ${data.branchAddress}',
                                style: theme.textTheme.labelSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Звёзды закреплены на правой стороне карточки, отдельной
              // колонкой — не "плавают" вслед за именем автора.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: i < data.stars
                            ? AppColors.accentOrange
                            : theme.dividerColor,
                      ),
                    ),
                  ),
                  if (data.moderationStatus == 'pending') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(s(context).pendingBadge.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: AppColors.accentOrange,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (data.moderationStatus == 'rejected') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(s(context).rejectedBadge.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: AppColors.negative,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(data.text, style: theme.textTheme.bodyMedium),
          if (data.pros != null || data.cons != null) ...[
            const SizedBox(height: 10),
            if (data.pros != null)
              _ProsConsLine(
                  icon: Icons.add_circle_outline,
                  color: AppColors.positive,
                  text: data.pros!),
            if (data.cons != null)
              _ProsConsLine(
                  icon: Icons.remove_circle_outline,
                  color: AppColors.negative,
                  text: data.cons!),
          ],
          if (data.priceLevel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(width: 6),
                Text(
                    '${s(context).avgCheckLabel}: ${s(context).priceLevelLabel(data.priceLevel!)}',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
          if (data.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => PhotoViewerScreen(
                        photos: data.photoUrls, initialIndex: i),
                  )),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data.photoUrls[i],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: theme.dividerColor),
                      errorBuilder: (context, error, stack) => Container(
                        width: 64,
                        height: 64,
                        color: theme.dividerColor,
                        child: Icon(Icons.broken_image_rounded,
                            color: theme.textTheme.bodyMedium?.color,
                            size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onToggleHelpful == null
                    ? null
                    : () => widget.onToggleHelpful!(!data.isHelpfulByMe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.isHelpfulByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: data.isHelpfulByMe
                            ? AppColors.negative
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      if (data.helpfulCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('${data.helpfulCount}',
                            style: theme.textTheme.labelMedium),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.onSubmitReply != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () =>
                      setState(() => _showReplyBox = !_showReplyBox),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Text(s(context).replyButton,
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
          if (data.replies.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...data.replies.map((reply) => _ReplyTile(reply: reply)),
          ],
          if (_showReplyBox) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: s(context).replyHint,
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmittingReply
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child:
                            Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        onPressed: _submitReply,
                        icon: Icon(Icons.send_rounded,
                            color: theme.colorScheme.primary),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final ReviewReplyData reply;
  const _ReplyTile({required this.reply});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(reply.authorName,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (reply.isOwnerReply) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.tag),
                  ),
                  child: Text(s(context).ownerReplyBadge.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(reply.text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProsConsLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ProsConsLine(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
