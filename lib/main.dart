import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_language_scope.dart';
import 'l10n/strings.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/onboarding/language_select_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/region_select_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/root/app_shell.dart';
import 'services/feedback_service.dart';
import 'supabase_service.dart';

const _prefsLanguageKey = 'tavsiya.language';
const _prefsCityKey = 'tavsiya.city';
const _prefsOnboardingDoneKey = 'tavsiya.onboarding_done';

// Значения по умолчанию — тестовый проект Supabase; для другого окружения
// переопределяются через --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ktdffwoogvyjbfzteaev.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_OQFxO-6n7SumrvtLvG3wTA_npglNvgn',
);
// Домен веб-сборки на Vercel — туда же ведёт api/feedback.js (жалобы/предложения).
const _feedbackApiBaseUrl = String.fromEnvironment(
  'FEEDBACK_API_BASE_URL',
  defaultValue: 'https://tavsiya-mvp.vercel.app',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Инициализация (Supabase + SharedPreferences) идёт уже внутри runApp, за
  // индикатором загрузки — иначе на медленном старте видна пустая белая
  // страница между нативным сплэшем и первым кадром Flutter.
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  _Flow? _initialFlow;
  AppLanguage _initialLanguage = AppLanguage.ru;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await SupabaseService.init(
        url: _supabaseUrl, publishableKey: _supabasePublishableKey);
    FeedbackService.init(baseUrl: _feedbackApiBaseUrl);

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_prefsOnboardingDoneKey) ?? false;
    final savedLanguage = switch (prefs.getString(_prefsLanguageKey)) {
      'uz' => AppLanguage.uz,
      'ru' => AppLanguage.ru,
      _ => null,
    };
    SupabaseService.cityKey = prefs.getString(_prefsCityKey) ?? kDefaultCity;

    // Первый запуск: онбординг → язык → город → (обязательная) регистрация.
    // onboardingDone проставляется один раз, в конце этой цепочки (см.
    // _finishFirstRun). Если флаг уже стоит, но сессии нет — при каждом
    // холодном старте (в том числе после выхода из аккаунта) пользователь
    // попадает на экран входа/регистрации, а не сразу в приложение.
    final hasSession = SupabaseService.currentUser != null;
    final initialFlow = !onboardingDone
        ? _Flow.onboarding
        : (hasSession ? _Flow.main : _Flow.auth);

    if (!mounted) return;
    setState(() {
      _initialFlow = initialFlow;
      _initialLanguage = savedLanguage ?? AppLanguage.ru;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialFlow == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return TavsiyaApp(
        initialFlow: _initialFlow!, initialLanguage: _initialLanguage);
  }
}

class TavsiyaApp extends StatefulWidget {
  final _Flow initialFlow;
  final AppLanguage initialLanguage;
  const TavsiyaApp(
      {super.key,
      this.initialFlow = _Flow.language,
      this.initialLanguage = AppLanguage.ru});

  @override
  State<TavsiyaApp> createState() => _TavsiyaAppState();
}

enum _Flow { onboarding, language, city, auth, main }

class _TavsiyaAppState extends State<TavsiyaApp> {
  late AppLanguage _language = widget.initialLanguage;
  AppThemeMode _themeMode = AppThemeMode.system;
  late _Flow _flow = widget.initialFlow;
  String _city = SupabaseService.cityKey;

  ThemeMode get _materialThemeMode => switch (_themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  Future<void> _setLanguage(AppLanguage lang) async {
    setState(() => _language = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsLanguageKey, lang == AppLanguage.uz ? 'uz' : 'ru');
    try {
      await SupabaseService.updatePreferredLanguage(lang);
    } catch (_) {
      // не блокируем смену языка в интерфейсе из-за сетевой ошибки
    }
  }

  Future<void> _setCity(String city) async {
    setState(() {
      _city = city;
      SupabaseService.cityKey = city;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCityKey, city);
  }

  /// Финал первой запуск-цепочки (онбординг → язык → город) — вызывается
  /// после выбора города, дальше либо обязательный вход, либо сразу в
  /// приложение, если уже вошли (например через "У меня уже есть аккаунт"
  /// внутри онбординга).
  Future<void> _finishFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsOnboardingDoneKey, true);
    if (!mounted) return;
    setState(() =>
        _flow = SupabaseService.currentUser != null ? _Flow.main : _Flow.auth);
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      language: _language,
      child: MaterialApp(
        title: 'Tavsiya',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _materialThemeMode,
        // На широких экранах (веб-сборка в браузере на десктопе) мобильный
        // макет не растягивается на всю ширину, а держится в колонке шириной
        // с телефон — без этого интерфейс выглядит рассыпавшимся на wide-viewport.
        builder: (context, child) => _WideScreenFrame(child: child),
        home: switch (_flow) {
          _Flow.onboarding => OnboardingScreen(
              onFinish: () => setState(() => _flow = _Flow.language),
            ),
          _Flow.language => LanguageSelectScreen(
              onSelected: (lang) {
                _setLanguage(lang);
                setState(() => _flow = _Flow.city);
              },
            ),
          _Flow.city => RegionSelectScreen(
              initialCity: _city,
              onSelected: (city) {
                _setCity(city);
                _finishFirstRun();
              },
            ),
          _Flow.auth => AuthScreen(
              dismissible: false,
              onAuthenticated: () {
                // язык мог быть выбран в онбординге до входа/регистрации —
                // profiles.preferred_language синхронизируем только теперь,
                // когда появилась сессия.
                SupabaseService.updatePreferredLanguage(_language);
                setState(() => _flow = _Flow.main);
              },
            ),
          _Flow.main => AppShell(
              key: ValueKey(_city),
              language: _language,
              themeMode: _themeMode,
              selectedCity: _city,
              onLanguageChanged: _setLanguage,
              onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
              onCityChanged: _setCity,
            ),
        },
      ),
    );
  }
}

/// Держит контент в колонке шириной с телефон на широких экранах (веб в
/// браузере на десктопе), с нейтральным фоном по бокам и тонированной тенью
/// вместо растянутого на весь viewport мобильного макета.
class _WideScreenFrame extends StatelessWidget {
  final Widget? child;
  const _WideScreenFrame({required this.child});

  static const _maxContentWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (content == null) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    if (width <= _maxContentWidth) return content;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF0A0908) : const Color(0xFFEAE7E1),
      child: Center(
        child: Container(
          width: _maxContentWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: AppColors.tintedShadow(isDark: isDark, opacity: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}
