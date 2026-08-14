import 'package:geolocator/geolocator.dart';

/// Текущее местоположение пользователя — для расчёта расстояния до заведений
/// (шаг выбора места в форме отзыва). Разрешение на геолокацию уже
/// запрашивается один раз при первом входе в приложение (см.
/// PermissionService.requestInitialPermissions) — здесь читаем его статус, а
/// не спрашиваем заново: если отказано, просто возвращаем null и экран
/// работает без расстояний, ничего не блокируя.
class LocationService {
  LocationService._();

  static Position? _cached;

  static Future<Position?> getCurrentPosition() async {
    if (_cached != null) return _cached;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8)),
      );
      _cached = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  static double distanceMeters(
          double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}
