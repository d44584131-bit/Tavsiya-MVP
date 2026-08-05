import 'package:permission_handler/permission_handler.dart';

/// Системные запросы разрешений (камера/галерея — фото к отзыву, геолокация —
/// определение города, уведомления — статус модерации отзыва). Запрашиваются
/// одним заходом при первом входе в приложение (см. app_shell.dart) — сами
/// разрешения не обязательны для работы приложения, отказ ничего не блокирует.
class PermissionService {
  PermissionService._();

  static Future<void> requestInitialPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
  }
}
