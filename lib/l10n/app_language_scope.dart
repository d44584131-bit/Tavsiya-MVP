import 'package:flutter/widgets.dart';
import '../screens/profile/profile_screen.dart' show AppLanguage;

/// Прокидывает текущий язык интерфейса вниз по дереву виджетов без ручной
/// передачи через конструкторы — оборачивает MaterialApp в main.dart.
/// Любой потомок читает его через `AppLanguageScope.of(context)`.
class AppLanguageScope extends InheritedWidget {
  final AppLanguage language;

  const AppLanguageScope(
      {super.key, required this.language, required super.child});

  static AppLanguage of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.language ?? AppLanguage.ru;
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      oldWidget.language != language;
}
