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

  /// Уведомляет администратора в Telegram о новом отзыве на модерации
  /// (`api/notify-review.js`) — сообщение с кнопками "Одобрить"/"Отклонить",
  /// нажатия обрабатывает `api/telegram-webhook.js`.
  static Future<void> notifyNewReview(String reviewId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/notify-review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reviewId': reviewId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось отправить уведомление о модерации');
    }
  }

  /// Уведомляет администратора в Telegram о новом заведении на модерации
  /// (`api/notify-place.js`) — вся информация для проверки (название,
  /// категория, описание, адрес, телефон, сайт) с кнопками
  /// "Одобрить"/"Отклонить"; появляется в приложении только после одобрения.
  static Future<void> notifyNewPlace(String placeId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/notify-place'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'placeId': placeId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось отправить уведомление о модерации');
    }
  }

  /// Уведомляет администратора в Telegram о новом/изменённом ответе
  /// заведения на отзыв, ожидающем модерации (`api/notify-review-reply.js`).
  /// Вызывается только для ответов от лица заведения (business-режим) —
  /// обычные ответы пользователей друг другу модерацию не проходят.
  static Future<void> notifyNewOwnerReply(String replyId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/notify-review-reply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'replyId': replyId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось отправить уведомление о модерации');
    }
  }
}
