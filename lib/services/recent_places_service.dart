import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальная история "недавно открытых" мест (шаг выбора места в форме
/// отзыва, секция "Недавно были рядом") — хранится только на устройстве, без
/// отдельной таблицы в Supabase: это просто подсказка, не критичные данные.
class RecentPlacesService {
  RecentPlacesService._();

  static const _key = 'recent_place_ids';
  static const _maxEntries = 15;

  static Future<void> recordView(String placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _read(prefs)..remove(placeId);
    ids.insert(0, placeId);
    if (ids.length > _maxEntries) ids.removeRange(_maxEntries, ids.length);
    await prefs.setString(_key, jsonEncode(ids));
  }

  /// Последние просмотренные места, самые свежие первыми.
  static Future<List<String>> recentPlaceIds({int limit = 6}) async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).take(limit).toList();
  }

  static List<String> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }
}
