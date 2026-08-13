import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../widgets/dot_indicator.dart';
import '../../widgets/pattern_dots_background.dart';
import '../../widgets/review_bubble.dart';
import '../auth/auth_screen.dart';

class OnboardingPageData {
  final String titlePrefix; // обычный текст
  final String titleAccent; // акцентное слово (коралловым)
  final String subtitle;
  final List<String>? highlights; // короткие акценты-пузыри (1-й экран)
  final List<_CategoryChip>? categories; // только для 2-го экрана
  final List<_ReviewSnippet>? reviews; // короткие цитаты отзывов (3-й экран)

  const OnboardingPageData({
    required this.titlePrefix,
    required this.titleAccent,
    required this.subtitle,
    this.highlights,
    this.categories,
    this.reviews,
  });
}

class _CategoryChip {
  final String
      categoryKey; // 'restaurant' | 'cafe' | 'park' | 'mall' — метка переводится на месте
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
          highlights: [
            s(context).onboard1Bubble1,
            s(context).onboard1Bubble2,
            s(context).onboard1Bubble3,
          ],
        ),
        OnboardingPageData(
          titlePrefix: s(context).onboard2TitlePrefix,
          titleAccent: s(context).onboard2TitleAccent,
          subtitle: s(context).onboard2Subtitle,
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
          reviews: [
            _ReviewSnippet(s(context).onboardReview1, 5),
            _ReviewSnippet(s(context).onboardReview2, 4),
            _ReviewSnippet(s(context).onboardReview3, 5),
            _ReviewSnippet(s(context).onboardReview4, 5),
          ],
        ),
      ];

  bool get _isLast => _index == _pages(context).length - 1;

  Future<void> _openLogin() async {
    // "У меня уже есть аккаунт" — открываем настоящий экран входа, а не
    // просто пропускаем онбординг: до этого кнопка ничего не проверяла.
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!mounted) return;
    widget.onFinish();
  }

  void _next() {
    if (_isLast) {
      widget.onFinish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);
    return Scaffold(
      body: PatternDotsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: TextButton(
                    onPressed: widget.onFinish,
                    child: Text(
                      s(context).skip,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _OnboardingPage(data: pages[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DotIndicator(count: pages.length, activeIndex: _index),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(
                        _isLast ? s(context).startButton : s(context).nextButton),
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

/// Одна страница онбординга: стена наклонённых пузырей сверху, заголовок
/// прижат к низу — со stagger-анимацией появления элементов.
class _OnboardingPage extends StatefulWidget {
  final OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
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
      curve: Interval(startAt, (startAt + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
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

  Widget _bubbleWall(BuildContext context) {
    final d = widget.data;
    if (d.highlights != null) {
      // Колонка, а не Stack с абсолютным позиционированием — иначе высота
      // "стены" не учитывает второй пузырь, и он наезжает на заголовок ниже
      // (был баг с наложением элементов друг на друга).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ReviewBubble(
              tilt: BubbleTilt.leftSoft,
              child: Text(d.highlights![0]),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ReviewBubble(
                  tilt: BubbleTilt.rightSoft,
                  child: Text(d.highlights![1]),
                ),
                const Positioned(top: -16, left: -14, child: Doodle(size: 22)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ReviewBubble(
              tilt: BubbleTilt.left,
              child: Text(d.highlights![2]),
            ),
          ),
        ],
      );
    }
    if (d.categories != null) {
      // Разброс по разным точкам "холста" фиксированной высоты — карточки
      // покрупнее плюс декоративные эмодзи в промежутках, как в референсе.
      return SizedBox(
        width: double.infinity,
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: const Alignment(-0.95, -0.95),
              child: Transform.rotate(
                angle: -6 * 3.1415926535 / 180,
                child: _CategoryTagBubble(chip: d.categories![0]),
              ),
            ),
            Align(
              alignment: const Alignment(0.95, -0.5),
              child: Transform.rotate(
                angle: 5 * 3.1415926535 / 180,
                child: _CategoryTagBubble(chip: d.categories![1]),
              ),
            ),
            Align(
              alignment: const Alignment(-0.85, 0.35),
              child: Transform.rotate(
                angle: -5 * 3.1415926535 / 180,
                child: _CategoryTagBubble(chip: d.categories![2]),
              ),
            ),
            Align(
              alignment: const Alignment(0.9, 0.95),
              child: Transform.rotate(
                angle: 6 * 3.1415926535 / 180,
                child: _CategoryTagBubble(chip: d.categories![3]),
              ),
            ),
            const Align(
                alignment: Alignment(0.2, -0.95), child: _EmojiDoodle('☕')),
            const Align(
                alignment: Alignment(-0.15, 0.1), child: _EmojiDoodle('🎡')),
            const Align(
                alignment: Alignment(0.25, 0.6), child: _EmojiDoodle('🍽️')),
          ],
        ),
      );
    }
    if (d.reviews != null) {
      return Column(
        children: d.reviews!.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ReviewBubble(
                    hero: i == 0,
                    tilt: i.isEven ? BubbleTilt.left : BubbleTilt.right,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text('«${r.quote}»'),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -6,
                    child: BubbleRatingBadge(stars: r.stars),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final primary = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    // LayoutBuilder + minHeight (вместо Spacer/фиксированной высоты пузырей) —
    // заголовок прижимается к низу, когда контент короткий, но если перевод
    // длиннее или пузыри с отзывами не влезли в 210px, страница просто
    // скроллится, а не вылезает за границы (было падение "overflowed by …").
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(_bubbleWall(context), startAt: 0.0),
                const SizedBox(height: 28),
                _staggered(
                  RichText(
                    text: TextSpan(
                      style: textTheme.headlineLarge,
                      children: [
                        TextSpan(text: d.titlePrefix),
                        TextSpan(
                            text: d.titleAccent,
                            style: TextStyle(color: primary)),
                      ],
                    ),
                  ),
                  startAt: 0.15,
                ),
                const SizedBox(height: 12),
                _staggered(
                  Text(d.subtitle, style: textTheme.bodyMedium),
                  startAt: 0.25,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTagBubble extends StatelessWidget {
  final _CategoryChip chip;
  const _CategoryTagBubble({required this.chip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1817) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, color: theme.colorScheme.primary, size: 34),
          const SizedBox(height: 8),
          Text(s(context).categoryPlural(chip.categoryKey),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Декоративный эмодзи, разбросанный по "холсту" 2-го экрана — чисто
/// орнамент, как рукописные завитки в референсе, никакого смысла не несёт.
class _EmojiDoodle extends StatelessWidget {
  final String emoji;
  const _EmojiDoodle(this.emoji);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.8,
        child: Text(emoji, style: const TextStyle(fontSize: 30)),
      ),
    );
  }
}
