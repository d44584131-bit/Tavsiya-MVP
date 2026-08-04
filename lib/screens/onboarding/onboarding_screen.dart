import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dot_indicator.dart';
import '../auth/auth_screen.dart';

class OnboardingPageData {
  final String titlePrefix; // обычный текст
  final String titleAccent; // акцентное слово (фиолетовым)
  final String subtitle;
  final IconData illustrationIcon; // заглушка под полноэкранную иллюстрацию
  final List<_CategoryChip>? categories; // только для 2-го экрана (сетка 4x2)
  final List<_ReviewSnippet>? reviews; // короткие цитаты отзывов

  const OnboardingPageData({
    required this.titlePrefix,
    required this.titleAccent,
    required this.subtitle,
    required this.illustrationIcon,
    this.categories,
    this.reviews,
  });
}

class _CategoryChip {
  final String categoryKey; // 'restaurant' | 'cafe' | 'park' | 'mall' — метка переводится на месте
  final IconData icon;
  const _CategoryChip(this.categoryKey, this.icon);
}

class _ReviewSnippet {
  final String quote;
  final int stars;
  const _ReviewSnippet(this.quote, this.stars);
}

/// Экран онбординга: язык уже выбран на предыдущем шаге (см. LanguageSelectScreen).
/// Здесь — ценностное предложение в 3 разворотах + переход в приложение.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  List<OnboardingPageData> _pages(BuildContext context) => [
        OnboardingPageData(
          titlePrefix: s(context).onboard1TitlePrefix,
          titleAccent: s(context).onboard1TitleAccent,
          subtitle: s(context).onboard1Subtitle,
          illustrationIcon: Icons.explore_outlined,
        ),
        OnboardingPageData(
          titlePrefix: s(context).onboard2TitlePrefix,
          titleAccent: s(context).onboard2TitleAccent,
          subtitle: s(context).onboard2Subtitle,
          illustrationIcon: Icons.grid_view_rounded,
          categories: const [
            _CategoryChip('restaurant', Icons.restaurant_rounded),
            _CategoryChip('cafe', Icons.coffee_rounded),
            _CategoryChip('park', Icons.park_rounded),
            _CategoryChip('mall', Icons.storefront_rounded),
          ],
        ),
        OnboardingPageData(
          titlePrefix: s(context).onboard3TitlePrefix,
          titleAccent: s(context).onboard3TitleAccent,
          subtitle: s(context).onboard3Subtitle,
          illustrationIcon: Icons.rate_review_rounded,
          reviews: [
            _ReviewSnippet(s(context).onboardReview1, 5),
            _ReviewSnippet(s(context).onboardReview2, 4),
          ],
        ),
      ];

  bool get _isLast => _index == _pages(context).length - 1;

  Future<void> _openLogin() async {
    // "У меня уже есть аккаунт" — открываем настоящий экран входа, а не
    // просто пропускаем онбординг: до этого кнопка ничего не проверяла.
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!mounted) return;
    widget.onFinish();
  }

  void _next() {
    if (_isLast) {
      widget.onFinish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _pages(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        s(context).skip,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _OnboardingPage(data: pages[i], isDark: isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DotIndicator(count: pages.length, activeIndex: _index),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(_isLast ? s(context).startButton : s(context).nextButton),
                    ),
                  ),
                ),
                if (!_isLast)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: TextButton(
                      onPressed: _openLogin,
                      child: Text(s(context).alreadyHaveAccount),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Одна страница онбординга со stagger-анимацией появления элементов.
class _OnboardingPage extends StatefulWidget {
  final OnboardingPageData data;
  final bool isDark;
  const _OnboardingPage({required this.data, required this.isDark});

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Каждый элемент появляется со своей задержкой (fade + slide вверх) — stagger-эффект.
  Widget _staggered(Widget child, {required double startAt}) {
    final curved = CurvedAnimation(
      parent: _anim,
      curve: Interval(startAt, (startAt + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 24),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final primary = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _staggered(
            Container(
              height: 220,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.headerGradient('cafe', isDark: widget.isDark),
                ),
              ),
              child: Icon(d.illustrationIcon, size: 96, color: Colors.white.withValues(alpha: 0.95)),
            ),
            startAt: 0.0,
          ),
          _staggered(
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: textTheme.headlineLarge,
                children: [
                  TextSpan(text: d.titlePrefix),
                  TextSpan(text: d.titleAccent, style: TextStyle(color: primary)),
                ],
              ),
            ),
            startAt: 0.15,
          ),
          const SizedBox(height: 12),
          _staggered(
            Text(d.subtitle, textAlign: TextAlign.center, style: textTheme.bodyMedium),
            startAt: 0.25,
          ),
          const SizedBox(height: 24),
          if (d.categories != null)
            _staggered(
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: d.categories!
                    .map((c) => _CategoryCell(chip: c))
                    .toList(),
              ),
              startAt: 0.35,
            ),
          if (d.reviews != null)
            _staggered(
              Column(
                children: d.reviews!.map((r) => _ReviewCard(review: r)).toList(),
              ),
              startAt: 0.35,
            ),
        ],
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  final _CategoryChip chip;
  const _CategoryCell({required this.chip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Icon(chip.icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 6),
        Text(s(context).categoryPlural(chip.categoryKey), style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ReviewSnippet review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
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
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star_rounded,
                size: 16,
                color: i < review.stars ? AppColors.accentOrange : theme.dividerColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('«${review.quote}»', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
