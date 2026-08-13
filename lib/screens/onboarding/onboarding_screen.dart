import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/strings.dart';
import '../../supabase_service.dart';
import '../../theme/app_colors.dart';
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
  final int? count; // реальное число мест, подгружается асинхронно
  const _CategoryChip(this.categoryKey, {this.count});
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
  Map<String, int>? _categoryCounts;

  @override
  void initState() {
    super.initState();
    // Реальные числа мест по категориям для карточек 2-го экрана — не
    // критично для онбординга, поэтому без спиннеров: пока не пришло,
    // карточки просто показываются без подписи "N мест".
    SupabaseService.fetchCategoryCounts().then((counts) {
      if (mounted) setState(() => _categoryCounts = counts);
    }).catchError((_) {});
  }

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
          categories: [
            _CategoryChip('restaurant', count: _categoryCounts?['restaurant']),
            _CategoryChip('cafe', count: _categoryCounts?['cafe']),
            _CategoryChip('park', count: _categoryCounts?['park']),
            _CategoryChip('mall', count: _categoryCounts?['mall']),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s(context).stepLabel(_index + 1, pages.length),
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1,
                        color: Theme.of(context).textTheme.labelSmall?.color,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        s(context).skip,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                    ),
                  ],
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

  /// Равномерно распределённые по высоте "холста" координаты Y (от -0.88
  /// до 0.88) — чтобы N пузырей заполняли всю зону, а не жались к низу.
  static List<double> _scatterYs(int n) {
    if (n <= 1) return const [0.0];
    const span = 1.76;
    return List.generate(n, (i) => -0.88 + i * (span / (n - 1)));
  }

  Widget _bubbleWall(BuildContext context, double wallHeight) {
    final d = widget.data;
    if (d.highlights != null) {
      final ys = _scatterYs(d.highlights!.length);
      return SizedBox(
        width: double.infinity,
        height: wallHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final entry in d.highlights!.asMap().entries)
              Align(
                alignment:
                    Alignment(entry.key.isEven ? -0.92 : 0.92, ys[entry.key]),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ReviewBubble(
                      hero: true,
                      tilt: entry.key.isEven
                          ? BubbleTilt.leftSoft
                          : BubbleTilt.rightSoft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(entry.value),
                      ),
                    ),
                    if (entry.key == 1)
                      const Positioned(
                          top: -16, left: -14, child: Doodle(size: 22)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (d.categories != null) {
      // Разброс по разным точкам "холста" фиксированной высоты — карточки
      // в стиле референса (белая плашка, цветная иконка-аватар, число мест).
      return SizedBox(
        width: double.infinity,
        height: wallHeight,
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
                alignment: Alignment(0.4, -0.15), child: Doodle(size: 22)),
            const Align(
                alignment: Alignment(-0.4, 0.65),
                child: Doodle(glyph: '~', size: 20, rotateDeg: 0)),
          ],
        ),
      );
    }
    if (d.reviews != null) {
      final ys = _scatterYs(d.reviews!.length);
      return SizedBox(
        width: double.infinity,
        height: wallHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final entry in d.reviews!.asMap().entries)
              Align(
                alignment:
                    Alignment(entry.key.isEven ? -0.92 : 0.92, ys[entry.key]),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ReviewBubble(
                      hero: entry.key == 0,
                      tilt: entry.key.isEven
                          ? BubbleTilt.left
                          : BubbleTilt.right,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 230),
                        child: Text('«${entry.value.quote}»'),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -6,
                      child: BubbleRatingBadge(stars: entry.value.stars),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
    // длиннее или пузыри не влезли — страница просто скроллится, а не
    // вылезает за границы (было падение "overflowed by …"). Высота "холста"
    // считается от доступного места, чтобы пузыри/карточки заполняли экран,
    // а не жались друг к другу внизу.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wallHeight = d.categories != null
            ? 330.0
            : (constraints.maxHeight * 0.56).clamp(360.0, 620.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(_bubbleWall(context, wallHeight), startAt: 0.0),
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

/// Карточка категории в стиле референса: белая плашка с коралловой
/// обводкой (как ReviewBubble), сверху — цветной квадрат-аватар с первой
/// буквой категории, ниже — название и (если уже подгрузилось) число мест.
class _CategoryTagBubble extends StatelessWidget {
  final _CategoryChip chip;
  const _CategoryTagBubble({required this.chip});

  @override
  Widget build(BuildContext context) {
    final label = s(context).categoryPlural(chip.categoryKey);
    final color = AppColors.categoryColor(chip.categoryKey);
    return ReviewBubble(
      hero: true,
      tilt: BubbleTilt.none,
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: GoogleFonts.unbounded(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            if (chip.count != null) ...[
              const SizedBox(height: 2),
              Text(s(context).placesCount(chip.count!),
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.labelSmall?.color)),
            ],
          ],
        ),
      ),
    );
  }
}
