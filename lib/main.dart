import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_language_scope.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/language_select_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/root/app_shell.dart';
import 'services/feedback_service.dart';
import 'supabase_service.dart';

const _prefsLanguageKey = 'tavsiya.language';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  FeedbackService.init(baseUrl: _feedbackApiBaseUrl);

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(_prefsOnboardingDoneKey) ?? false;
  final savedLanguage = switch (prefs.getString(_prefsLanguageKey)) {
    'uz' => AppLanguage.uz,
    'ru' => AppLanguage.ru,
    _ => null,
  };

  runApp(TavsiyaApp(
    initialFlow: onboardingDone ? _Flow.main : _Flow.language,
    initialLanguage: savedLanguage ?? AppLanguage.ru,
  ));
}

class TavsiyaApp extends StatefulWidget {
  final _Flow initialFlow;
  final AppLanguage initialLanguage;
  const TavsiyaApp({super.key, this.initialFlow = _Flow.language, this.initialLanguage = AppLanguage.ru});

  @override
  State<TavsiyaApp> createState() => _TavsiyaAppState();
}

enum _Flow { language, onboarding, main }

class _TavsiyaAppState extends State<TavsiyaApp> {
  late AppLanguage _language = widget.initialLanguage;
  AppThemeMode _themeMode = AppThemeMode.system;
  late _Flow _flow = widget.initialFlow;

  ThemeMode get _materialThemeMode => switch (_themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  Future<void> _setLanguage(AppLanguage lang) async {
    setState(() => _language = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLanguageKey, lang == AppLanguage.uz ? 'uz' : 'ru');
  }

  Future<void> _finishOnboarding() async {
    setState(() => _flow = _Flow.main);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsOnboardingDoneKey, true);
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
        home: switch (_flow) {
          _Flow.language => LanguageSelectScreen(
              onSelected: (lang) {
                _setLanguage(lang);
                setState(() => _flow = _Flow.onboarding);
              },
            ),
          _Flow.onboarding => OnboardingScreen(
              onFinish: _finishOnboarding,
            ),
          _Flow.main => AppShell(
              language: _language,
              themeMode: _themeMode,
              onLanguageChanged: _setLanguage,
              onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
            ),
        },
      ),
    );
  }
}
