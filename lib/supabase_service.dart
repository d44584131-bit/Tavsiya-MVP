import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/strings.dart';
import 'screens/home/home_screen.dart';
import 'screens/place/place_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/place_card.dart';
import 'widgets/place_review_card.dart';
import 'widgets/review_list_item.dart';

/// Единая точка доступа к Supabase. Инициализируется один раз в main()
/// до runApp(): `await SupabaseService.init(url: ..., publishableKey: ...);`
/// url — базовый URL проекта (https://<project>.supabase.co), без /rest/v1.
class SupabaseService {
  SupabaseService._();

  static Future<void> init({required String url, required String publishableKey}) async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static SupabaseClient get _client => Supabase.instance.client;

  // ------------------------------------------------------------
  // Аутентификация
  // ------------------------------------------------------------

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static Future<void> signUp({required String email, required String password, required String displayName}) async {
    await _client.auth.signUp(email: email, password: password, data: {'display_name': displayName});
  }

  static Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Вход/регистрация через Google. На вебе браузер сам вернётся на текущий
  /// адрес после подтверждения; на Android/iOS — через deep link
  /// 'com.example.tavsiya://login-callback/' (см. AndroidManifest.xml /
  /// Info.plist). Требует включённого провайдера Google в Supabase Dashboard
  /// (Authentication → Providers) с Client ID/Secret из Google Cloud Console.
  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'com.example.tavsiya://login-callback/',
    );
  }

  /// Собственные отзывы текущего пользователя (вкладка "Мои отзывы" в профиле),
  /// включая ещё не прошедшие модерацию.
  static Future<List<PlaceReviewData>> fetchMyReviews({required AppLanguage language}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('reviews')
        .select('rating, text, pros, cons, status, places(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => PlaceReviewData(
              authorName: (r['places'] as Map<String, dynamic>?)?['name'] as String? ?? Strings(language).placeDeleted,
              stars: r['rating'] as int,
              text: r['text'] as String,
              pros: r['pros'] as String?,
              cons: r['cons'] as String?,
              isPending: r['status'] != 'approved',
            ))
        .toList();
  }

  /// Публичный профиль текущего пользователя (шапка экрана "Профиль").
  static Future<MyProfileData> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final row = await _client
        .from('profiles')
        .select('display_name, avatar_url, bio, reviews_count, helpful_votes_count, saved_count, followers_count, following_count')
        .eq('id', userId)
        .single();

    return MyProfileData(
      displayName: row['display_name'] as String,
      bio: row['bio'] as String?,
      reviewsCount: row['reviews_count'] as int,
      helpfulVotesCount: row['helpful_votes_count'] as int,
      savedCount: row['saved_count'] as int,
      followersCount: row['followers_count'] as int,
    );
  }

  // ------------------------------------------------------------
  // Места
  // ------------------------------------------------------------

  static const _placeCardColumns = 'id, name, category, district, rating_avg, reviews_count';

  /// "Сейчас популярно" — места с самым высоким рейтингом.
  static Future<List<PlaceCardData>> fetchTrendingPlaces({int limit = 10}) async {
    final rows = await _client
        .from('places')
        .select(_placeCardColumns)
        .order('rating_avg', ascending: false)
        .limit(limit);

    return (rows as List).map((r) => _placeFromRow(r)).toList();
  }

  /// Поиск мест по названию (ILIKE через pg_trgm) с опциональным фильтром категории.
  static Future<List<PlaceCardData>> searchPlaces({String query = '', String? category}) async {
    var builder = _client.from('places').select(_placeCardColumns);
    if (query.trim().isNotEmpty) {
      builder = builder.ilike('name', '%${query.trim()}%');
    }
    if (category != null) {
      builder = builder.eq('category', category);
    }
    final rows = await builder.order('rating_avg', ascending: false);
    return (rows as List).map((r) => _placeFromRow(r)).toList();
  }

  /// Создание нового места пользователем (шаг "Добавить «...»" в форме отзыва).
  static Future<PlaceCardData> createPlace({required String name, required String category}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final row = await _client
        .from('places')
        .insert({'name': name, 'category': category, 'created_by': userId})
        .select(_placeCardColumns)
        .single();

    return _placeFromRow(row);
  }

  /// Полная карточка места (шапка + вкладка "Информация" в PlaceDetailScreen).
  static Future<PlaceDetailData> fetchPlaceById(String id) async {
    final row = await _client
        .from('places')
        .select(
          'id, name, category, description, address, district, phone, website, price_level, '
          'is_verified, rating_avg, reviews_count, photos_count',
        )
        .eq('id', id)
        .single();

    return PlaceDetailData(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      description: row['description'] as String?,
      address: row['address'] as String?,
      district: (row['district'] as String?) ?? '',
      phone: row['phone'] as String?,
      website: row['website'] as String?,
      priceLevel: row['price_level'] as String?,
      isVerified: row['is_verified'] as bool,
      rating: (row['rating_avg'] as num).toDouble(),
      reviewsCount: row['reviews_count'] as int,
      photosCount: row['photos_count'] as int,
    );
  }

  static PlaceCardData _placeFromRow(Map<String, dynamic> r) {
    return PlaceCardData(
      id: r['id'] as String,
      name: r['name'] as String,
      category: r['category'] as String,
      rating: (r['rating_avg'] as num).toDouble(),
      reviewsCount: r['reviews_count'] as int,
      district: (r['district'] as String?) ?? '',
    );
  }

  /// "Подборки для вас" на главном экране — курируемые списки мест.
  static Future<List<CollectionData>> fetchCollections() async {
    final rows = await _client
        .from('collections')
        .select('id, title, collection_places(sort_order, places($_placeCardColumns))')
        .order('sort_order');

    return (rows as List).map((r) {
      final placeRows = (r['collection_places'] as List).toList()
        ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
      final places = placeRows
          .map((cp) => cp['places'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(_placeFromRow)
          .toList();
      return CollectionData(id: r['id'] as String, title: r['title'] as String, places: places);
    }).toList();
  }

  // ------------------------------------------------------------
  // Отзывы
  // ------------------------------------------------------------

  /// Отзывы места — только approved, независимо от языка интерфейса
  /// (см. правило многоязычности: отзывы не фильтруются по языку).
  static Future<List<PlaceReviewData>> fetchApprovedReviews(String placeId, {required AppLanguage language, int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    var builder = _client
        .from('reviews')
        .select('rating, text, pros, cons, status, profiles!reviews_user_id_fkey(display_name)')
        .eq('place_id', placeId);
    // approved-отзывы видны всем; собственный ещё не прошедший модерацию
    // отзыв — только автору (см. RLS reviews_select_approved_or_own).
    builder = userId != null ? builder.or('status.eq.approved,user_id.eq.$userId') : builder.eq('status', 'approved');

    final rows = await builder.order('created_at', ascending: false).limit(limit);

    return (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return PlaceReviewData(
        authorName: (profile?['display_name'] as String?) ?? Strings(language).guestReviewer,
        stars: r['rating'] as int,
        text: r['text'] as String,
        pros: r['pros'] as String?,
        cons: r['cons'] as String?,
        isPending: r['status'] != 'approved',
      );
    }).toList();
  }

  /// "Новые отзывы" на главном экране — последние approved-отзывы по всем местам.
  static Future<List<ReviewListItemData>> fetchRecentReviews({required AppLanguage language, int limit = 10}) async {
    final rows = await _client
        .from('reviews')
        .select('rating, text, profiles!reviews_user_id_fkey(display_name), places(name)')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      final place = r['places'] as Map<String, dynamic>?;
      return ReviewListItemData(
        authorName: (profile?['display_name'] as String?) ?? Strings(language).guestReviewer,
        placeName: (place?['name'] as String?) ?? '',
        stars: r['rating'] as int,
        text: r['text'] as String,
      );
    }).toList();
  }

  /// Публикация нового отзыва — на этапе тестирования MVP публикуется сразу
  /// со статусом 'approved' (модерация отключена, чтобы тестерам не ждать
  /// ручного одобрения). Статус 'pending'/'rejected' остаётся в схеме и
  /// поддерживается в UI — ими можно управлять вручную через Supabase.
  static Future<void> submitReview({
    required String placeId,
    required int rating,
    required String text,
    String? pros,
    String? cons,
    String? priceLevel,
    String? withWhom,
    required String language, // 'ru' | 'uz' — метаданные, не влияет на видимость
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    await _client.from('reviews').insert({
      'place_id': placeId,
      'user_id': userId,
      'rating': rating,
      'text': text,
      'pros': pros,
      'cons': cons,
      'price_level': priceLevel,
      'with_whom': withWhom,
      'language': language,
      'status': 'approved',
    });
  }

  // ------------------------------------------------------------
  // Сохранённые места
  // ------------------------------------------------------------

  static Future<bool> isPlaceSaved(String placeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _client.from('saved_places').select('place_id').match({'user_id': userId, 'place_id': placeId}).maybeSingle();
    return row != null;
  }

  static Future<List<PlaceCardData>> fetchSavedPlaces() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client.from('saved_places').select('places($_placeCardColumns)').eq('user_id', userId);

    return (rows as List)
        .map((r) => r['places'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(_placeFromRow)
        .toList();
  }

  static Future<void> toggleSavedPlace(String placeId, {required bool save}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    if (save) {
      await _client.from('saved_places').insert({'user_id': userId, 'place_id': placeId});
    } else {
      await _client.from('saved_places').delete().match({'user_id': userId, 'place_id': placeId});
    }
  }
}
