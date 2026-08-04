import 'dart:convert';
import 'package:http/http.dart' as http;

/// Отправка "Жалобы и предложения" из профиля на серверless-эндпоинт
/// (`api/feedback.js` на Vercel), который пересылает сообщение
/// администратору в Telegram. Токен бота хранится только на сервере.
class FeedbackService {
  FeedbackService._();

  static String _baseUrl = '';

  static void init({required String baseUrl}) {
    _baseUrl = baseUrl;
  }

  static Future<void> submit({
    required String message,
    required String category, // 'complaint' | 'suggestion'
    String? userEmail,
    String? userName,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'category': category,
        'userEmail': userEmail,
        'userName': userName,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось отправить сообщение');
    }
  }
}
