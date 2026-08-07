import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/strings.dart';

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

  /// Перед вызовом image_picker убеждаемся, что разрешение действительно
  /// есть: после первого системного запроса (при старте приложения)
  /// image_picker сам больше не переспрашивает при отказе, поэтому здесь
  /// пробуем запросить ещё раз, а если отказано навсегда — ведём в настройки.
  static Future<bool> ensurePhotoAccess(
      BuildContext context, ImageSource source) async {
    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
    var status = await permission.status;
    if (!status.isGranted && !status.isLimited) {
      status = await permission.request();
    }
    if (status.isGranted || status.isLimited) return true;
    if (!context.mounted) return false;

    final message = source == ImageSource.camera
        ? s(context).permissionDeniedCameraMessage
        : s(context).permissionDeniedGalleryMessage;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s(dialogContext).permissionDeniedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s(dialogContext).cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: Text(s(dialogContext).openSettingsButton),
          ),
        ],
      ),
    );
    return false;
  }
}
