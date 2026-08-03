import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/language_select_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/root/app_shell.dart';
import 'supabase_service.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const TavsiyaApp());
}
class TavsiyaApp extends StatefulWidget {
  const TavsiyaApp({super.key});

  @override
  State<TavsiyaApp> createState() => _TavsiyaAppState();
}

enum _Flow { language, onboarding, main }

class _TavsiyaAppState extends State<TavsiyaApp> {
  AppLanguage _language = AppLanguage.ru;
  AppThemeMode _themeMode = AppThemeMode.system;
  _Flow _flow = _Flow.language;

  ThemeMode get _materialThemeMode => switch (_themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tavsiya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _materialThemeMode,
      // NB: локализация интерфейса (RU/UZ) через ARB/intl подключается отдельно;
      // здесь _language прокидывается в экраны, которые уже умеют на него реагировать.
      home: switch (_flow) {
        _Flow.language => LanguageSelectScreen(
            onSelected: (lang) => setState(() {
              _language = lang;
              _flow = _Flow.onboarding;
            }),
          ),
        _Flow.onboarding => OnboardingScreen(
            onFinish: () => setState(() => _flow = _Flow.main),
          ),
        _Flow.main => AppShell(
            language: _language,
            themeMode: _themeMode,
            onLanguageChanged: (lang) => setState(() => _language = lang),
            onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
          ),
      },
    );
  }
}
