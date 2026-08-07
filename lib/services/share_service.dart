import 'package:share_plus/share_plus.dart';
import '../screens/profile/profile_screen.dart' show AppLanguage;

/// "Поделиться заведением" — если у получателя установлено приложение и
/// настроены App Links/Universal Links на _webBaseUrl, ссылка на заведение
/// откроется прямо в приложении; иначе браузер покажет обычную веб-страницу
/// со ссылкой на скачивание. Домен и ссылка на скачивание — заглушки,
/// заменить на реальные после публикации сайта/сторов.
class ShareService {
  ShareService._();

  static const String _webBaseUrl = 'https://tavsiya.app';
  static const String _downloadUrl = 'https://tavsiya.app/download';

  static Future<void> sharePlace({
    required String placeId,
    required String placeName,
    required AppLanguage language,
  }) async {
    final link = '$_webBaseUrl/place/$placeId';
    final text = language == AppLanguage.uz
        ? '$placeName — Tavsiya ilovasida koʻring:\n$link\n\nIlova hali oʻrnatilmagan boʻlsa, yuklab oling:\n$_downloadUrl'
        : '$placeName — смотри в приложении Tavsiya:\n$link\n\nЕсли приложения ещё нет — скачать:\n$_downloadUrl';
    await SharePlus.instance.share(ShareParams(text: text, subject: placeName));
  }
}
