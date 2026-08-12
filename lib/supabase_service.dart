import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/strings.dart';
import 'services/feedback_service.dart';
import 'screens/business/business_dashboard_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/place/place_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/review_form/review_form_screen.dart';
import 'widgets/notification_tile.dart';
import 'widgets/place_card.dart';
import 'widgets/place_review_card.dart';

/// Единая точка доступа к Supabase. Инициализируется один раз в main()
/// до runApp(): `await SupabaseService.init(url: ..., publishableKey: ...);`
/// url — базовый URL проекта (https://<project>.supabase.co), без /rest/v1.
class SupabaseService {
  SupabaseService._();

  static Future<void> init(
      {required String url, required String publishableKey}) async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static SupabaseClient get _client => Supabase.instance.client;

  // ------------------------------------------------------------
  // Аутентификация
  // ------------------------------------------------------------

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> signUp(
      {required String email,
      required String password,
      required String displayName}) async {
    await _client.auth.signUp(
        email: email, password: password, data: {'display_name': displayName});
  }

  static Future<void> signIn(
      {required String email, required String password}) async {
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
  static Future<List<PlaceReviewData>> fetchMyReviews(
      {required AppLanguage language}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('reviews')
        .select(
            'id, rating, text, pros, cons, price_level, status, created_at, helpful_count, '
            'places(name), review_photos(storage_path), review_helpful_votes(user_id)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => PlaceReviewData(
              id: r['id'] as String,
              authorName:
                  (r['places'] as Map<String, dynamic>?)?['name'] as String? ??
                      Strings(language).placeDeleted,
              stars: r['rating'] as int,
              text: r['text'] as String,
              pros: r['pros'] as String?,
              cons: r['cons'] as String?,
              priceLevel: r['price_level'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
              photoUrls: _photoUrlsFromRow(r),
              moderationStatus:
                  r['status'] == 'approved' ? null : r['status'] as String?,
              helpfulCount: r['helpful_count'] as int? ?? 0,
              isHelpfulByMe: _isHelpfulByMe(r, userId),
            ))
        .toList();
  }

  static bool _isHelpfulByMe(Map<String, dynamic> r, String? userId) {
    if (userId == null) return false;
    final votes = r['review_helpful_votes'] as List?;
    if (votes == null) return false;
    return votes.any((v) => (v as Map<String, dynamic>)['user_id'] == userId);
  }

  /// Сохраняет выбранный язык интерфейса в профиль — читается сервером
  /// (api/telegram-webhook.js), чтобы отправлять push-уведомления на языке
  /// пользователя, а не только хранить его локально на устройстве.
  static Future<void> updatePreferredLanguage(AppLanguage language) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // не авторизован — синхронизировать нечего
    await _client.from('profiles').update({
      'preferred_language': language == AppLanguage.uz ? 'uz' : 'ru'
    }).eq('id', userId);
  }

  /// Публичный профиль текущего пользователя (шапка экрана "Профиль").
  static Future<MyProfileData> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final row = await _client
        .from('profiles')
        .select(
            'display_name, avatar_url, bio, reviews_count, helpful_votes_count, saved_count, followers_count, following_count')
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

  static const _placeCardColumns =
      'id, name, category, district, rating_avg, reviews_count, status';

  /// Выбранный пользователем город — фильтрует "Сейчас популярно" и поиск.
  /// Загружается из SharedPreferences при старте (см. main.dart) и меняется
  /// через setCity() из шапки главного экрана/онбординга.
  static String cityKey = kDefaultCity;

  /// "Сейчас популярно" — места с самым высоким рейтингом в выбранном городе.
  static Future<List<PlaceCardData>> fetchTrendingPlaces(
      {int limit = 10, int offset = 0}) async {
    final rows = await _client
        .from('places')
        .select(_placeCardColumns)
        .eq('city', cityKey)
        .eq('status', 'approved')
        .order('rating_avg', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List).map((r) => _placeFromRow(r)).toList();
  }

  /// Поиск мест по названию (ILIKE через pg_trgm) в выбранном городе,
  /// с опциональным фильтром категории и постраничной подгрузкой.
  static Future<List<PlaceCardData>> searchPlaces({
    String query = '',
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    var builder = _client
        .from('places')
        .select(_placeCardColumns)
        .eq('city', cityKey)
        .eq('status', 'approved');
    if (query.trim().isNotEmpty) {
      builder = builder.ilike('name', '%${query.trim()}%');
    }
    if (category != null) {
      builder = builder.eq('category', category);
    }
    final rows = await builder
        .order('rating_avg', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List).map((r) => _placeFromRow(r)).toList();
  }

  /// Создание нового места пользователем (шаг "Добавить «...»" в форме
  /// отзыва) — как и полное создание владельцем (createOwnedPlace), новое
  /// место сразу уходит на модерацию в Telegram (status='pending' по
  /// умолчанию) и не видно другим, пока админ не одобрит.
  static Future<PlaceCardData> createPlace(
      {required String name, required String category}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final row = await _client
        .from('places')
        .insert({
          'name': name,
          'category': category,
          'city': cityKey,
          'created_by': userId
        })
        .select(_placeCardColumns)
        .single();

    try {
      await FeedbackService.notifyNewPlace(row['id'] as String);
    } catch (_) {
      // уведомление в Telegram не критично для успешного создания места
    }

    return _placeFromRow(row);
  }

  // ------------------------------------------------------------
  // Аккаунт заведения ("Войти как заведение" в профиле пользователя) —
  // управление профилем/официальными фото своих мест, просмотр отзывов.
  // Владение проставляется автоматически триггером на places (created_by),
  // см. schema.sql → МИГРАЦИЯ: аккаунт заведения (place_owners).
  // ------------------------------------------------------------

  static Future<List<PlaceCardData>> fetchOwnedPlaces() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('place_owners')
        .select('places($_placeCardColumns)')
        .eq('user_id', userId);

    return (rows as List)
        .map((r) => r['places'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(_placeFromRow)
        .toList();
  }

  /// Полная форма создания места владельцем ("Заведение" → "Добавить
  /// заведение") — в отличие от createPlace() (быстрое добавление из формы
  /// отзыва: только имя+категория), сразу собирает бизнес-детали.
  static Future<PlaceCardData> createOwnedPlace({
    required String name,
    required String category,
    String? description,
    String? address,
    String? phone,
    String? website,
    String? instagram,
    String? priceLevel,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final row = await _client
        .from('places')
        .insert({
          'name': name,
          'category': category,
          'city': cityKey,
          'description': description,
          'address': address,
          'phone': phone,
          'website': website,
          'instagram': instagram,
          'price_level': priceLevel,
          'created_by': userId,
        })
        .select(_placeCardColumns)
        .single();

    try {
      await FeedbackService.notifyNewPlace(row['id'] as String);
    } catch (_) {
      // уведомление в Telegram не критично для успешного создания места
    }

    return _placeFromRow(row);
  }

  /// Редактирование данных места владельцем — доступ ограничен RLS-политикой
  /// places_update_own (только владелец через place_owners).
  static Future<void> updateOwnedPlace(
    String placeId, {
    required String name,
    required String category,
    String? description,
    String? address,
    String? phone,
    String? website,
    String? instagram,
    String? priceLevel,
  }) async {
    await _client.from('places').update({
      'name': name,
      'category': category,
      'description': description,
      'address': address,
      'phone': phone,
      'website': website,
      'instagram': instagram,
      'price_level': priceLevel,
    }).eq('id', placeId);
  }

  /// Официальные фото места для управления (с id — чтобы можно было
  /// удалить), в отличие от fetchPlacePhotos() (только URL, для публичной
  /// карусели в профиле места).
  static Future<List<PlaceOwnerPhotoData>> fetchOwnedPlacePhotos(
      String placeId) async {
    final rows = await _client
        .from('place_photos')
        .select('id, storage_path')
        .eq('place_id', placeId)
        .order('created_at');

    return (rows as List)
        .map((r) => PlaceOwnerPhotoData(
              id: r['id'] as String,
              storagePath: r['storage_path'] as String,
              url: _client.storage
                  .from('place-photos')
                  .getPublicUrl(r['storage_path'] as String),
            ))
        .toList();
  }

  static Future<void> addOwnedPlacePhoto(
      String placeId, Uint8List bytes) async {
    final path = '$placeId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('place-photos').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    await _client.from('place_photos').insert({
      'place_id': placeId,
      'storage_path': path,
      'uploaded_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> deleteOwnedPlacePhoto(PlaceOwnerPhotoData photo) async {
    await _client.from('place_photos').delete().eq('id', photo.id);
    try {
      await _client.storage.from('place-photos').remove([photo.storagePath]);
    } catch (_) {
      // строка уже удалена из БД — не блокируем UI из-за ошибки чистки файла
    }
  }

  /// Официальные фото места для карусели в шапке профиля — отдельная
  /// таблица/бакет от фото, которые посетители прикладывают к отзывам
  /// (те остаются только в отзывах и во вкладке "Фото", см. review_photos).
  static Future<List<String>> fetchPlacePhotos(String placeId) async {
    final rows = await _client
        .from('place_photos')
        .select('storage_path')
        .eq('place_id', placeId)
        .order('created_at');

    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['storage_path'] as String)
        .map((path) => _client.storage.from('place-photos').getPublicUrl(path))
        .toList();
  }

  /// Полная карточка места (шапка + вкладка "Информация" в PlaceDetailScreen).
  static Future<PlaceDetailData> fetchPlaceById(String id) async {
    final row = await _client
        .from('places')
        .select(
          'id, name, category, description, address, district, phone, website, instagram, price_level, '
          'is_verified, rating_avg, reviews_count, status',
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
      instagram: row['instagram'] as String?,
      priceLevel: row['price_level'] as String?,
      isVerified: row['is_verified'] as bool,
      rating: (row['rating_avg'] as num).toDouble(),
      reviewsCount: row['reviews_count'] as int,
      status: row['status'] == 'approved' ? null : row['status'] as String?,
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
      status: r['status'] == 'approved' ? null : r['status'] as String?,
    );
  }

  /// "Подборки для вас" на главном экране — курируемые списки мест.
  /// title_uz заполняется вручную через дашборд; при отсутствии — русский.
  static Future<List<CollectionData>> fetchCollections(
      {required AppLanguage language}) async {
    final rows = await _client
        .from('collections')
        .select(
            'id, title, title_uz, collection_places(sort_order, places($_placeCardColumns))')
        .order('sort_order');

    return (rows as List).map((r) {
      final placeRows = (r['collection_places'] as List).toList()
        ..sort((a, b) =>
            (a['sort_order'] as int).compareTo(b['sort_order'] as int));
      final places = placeRows
          .map((cp) => cp['places'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(_placeFromRow)
          .toList();
      final titleUz = r['title_uz'] as String?;
      final title =
          language == AppLanguage.uz && titleUz != null && titleUz.isNotEmpty
              ? titleUz
              : r['title'] as String;
      return CollectionData(
          id: r['id'] as String, title: title, places: places);
    }).toList();
  }

  // ------------------------------------------------------------
  // Отзывы
  // ------------------------------------------------------------

  /// Отзывы места — approved и pending видны всем сразу (с пометкой "на
  /// модерации"), независимо от языка интерфейса (см. правило многоязычности:
  /// отзывы не фильтруются по языку). rejected виден только автору — это
  /// обеспечивает RLS-политика reviews_select_approved_or_own.
  static Future<List<PlaceReviewData>> fetchApprovedReviews(String placeId,
      {required AppLanguage language, int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('reviews')
        .select(
            'id, rating, text, pros, cons, price_level, status, created_at, helpful_count, '
            'profiles!reviews_user_id_fkey(display_name, reviews_count), '
            'review_photos(storage_path), review_helpful_votes(user_id), '
            'review_replies(id, text, is_owner_reply, created_at, profiles!review_replies_user_id_fkey(display_name))')
        .eq('place_id', placeId)
        .order('helpful_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return PlaceReviewData(
        id: r['id'] as String,
        authorName: (profile?['display_name'] as String?) ??
            Strings(language).guestReviewer,
        stars: r['rating'] as int,
        text: r['text'] as String,
        pros: r['pros'] as String?,
        cons: r['cons'] as String?,
        priceLevel: r['price_level'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        photoUrls: _photoUrlsFromRow(r),
        moderationStatus:
            r['status'] == 'approved' ? null : r['status'] as String?,
        authorReviewsCount: profile?['reviews_count'] as int?,
        helpfulCount: r['helpful_count'] as int? ?? 0,
        isHelpfulByMe: _isHelpfulByMe(r, userId),
        replies: _repliesFromRow(r, language),
      );
    }).toList();
  }

  static List<ReviewReplyData> _repliesFromRow(
      Map<String, dynamic> r, AppLanguage language) {
    final raw = r['review_replies'] as List?;
    if (raw == null || raw.isEmpty) return const [];
    final replies = raw.map((rr) {
      final map = rr as Map<String, dynamic>;
      final replyProfile = map['profiles'] as Map<String, dynamic>?;
      return ReviewReplyData(
        id: map['id'] as String,
        authorName: (replyProfile?['display_name'] as String?) ??
            Strings(language).guestReviewer,
        text: map['text'] as String,
        isOwnerReply: map['is_owner_reply'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return replies;
  }

  static List<String> _photoUrlsFromRow(Map<String, dynamic> r) {
    final photos = r['review_photos'] as List?;
    if (photos == null || photos.isEmpty) return const [];
    return photos
        .map((p) => (p as Map<String, dynamic>)['storage_path'] as String)
        .map((path) => _client.storage.from('review-photos').getPublicUrl(path))
        .toList();
  }

  /// "Новые отзывы" на главном экране (и полный список с пагинацией на
  /// отдельной странице) — последние approved-отзывы по всем местам,
  /// отображаются той же карточкой, что и в профиле места.
  static Future<List<PlaceReviewData>> fetchRecentReviews(
      {required AppLanguage language, int limit = 10, int offset = 0}) async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('reviews')
        .select(
            'id, rating, text, pros, cons, price_level, created_at, helpful_count, '
            'profiles!reviews_user_id_fkey(display_name, reviews_count), places(name), '
            'review_photos(storage_path), review_helpful_votes(user_id)')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      final place = r['places'] as Map<String, dynamic>?;
      return PlaceReviewData(
        id: r['id'] as String,
        authorName: (profile?['display_name'] as String?) ??
            Strings(language).guestReviewer,
        placeName: (place?['name'] as String?) ?? '',
        stars: r['rating'] as int,
        text: r['text'] as String,
        pros: r['pros'] as String?,
        cons: r['cons'] as String?,
        priceLevel: r['price_level'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        photoUrls: _photoUrlsFromRow(r),
        authorReviewsCount: profile?['reviews_count'] as int?,
        helpfulCount: r['helpful_count'] as int? ?? 0,
        isHelpfulByMe: _isHelpfulByMe(r, userId),
      );
    }).toList();
  }

  /// Публикация нового отзыва — создаётся со статусом 'pending' и сразу
  /// виден всем в списке отзывов места (с пометкой "на модерации"), пока
  /// администратор не одобрит/отклонит его в Telegram-боте (см.
  /// api/notify-review.js и api/telegram-webhook.js).
  static Future<void> submitReview({
    required String placeId,
    required int rating,
    required String text,
    String? pros,
    String? cons,
    String? priceLevel,
    required String
        language, // 'ru' | 'uz' — метаданные, не влияет на видимость
    List<Uint8List> photos = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    // unique(place_id, user_id) в БД не даёт оставить второй отзыв на одно и то
    // же место — эту ошибку отдельно ловит вызывающий код (review_form_screen),
    // чтобы показать понятное сообщение вместо общего "не удалось отправить".
    final row = await _client
        .from('reviews')
        .insert({
          'place_id': placeId,
          'user_id': userId,
          'rating': rating,
          'text': text,
          'pros': pros,
          'cons': cons,
          'price_level': priceLevel,
          'language': language,
          'status': 'pending',
        })
        .select('id')
        .single();
    final reviewId = row['id'] as String;

    if (photos.isNotEmpty) {
      try {
        for (var i = 0; i < photos.length; i++) {
          final path = '$userId/$reviewId/$i.jpg';
          await _client.storage.from('review-photos').uploadBinary(
                path,
                photos[i],
                fileOptions:
                    const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          await _client
              .from('review_photos')
              .insert({'review_id': reviewId, 'storage_path': path});
        }
      } catch (_) {
        // отзыв уже опубликован — не блокируем успех из-за ошибки загрузки фото
      }
    }

    try {
      await FeedbackService.notifyNewReview(reviewId);
    } catch (_) {
      // уведомление в Telegram не критично для успешной публикации отзыва
    }
  }

  /// "Лайк" отзыва — переиспользует таблицу review_helpful_votes (была в
  /// базовой схеме под смыслом "отметить полезным", но нигде не была
  /// подключена в интерфейсе); helpful_count и уведомление автору обновляются
  /// триггерами на сервере (см. schema.sql).
  static Future<void> toggleReviewHelpful(String reviewId,
      {required bool like}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');
    if (like) {
      await _client
          .from('review_helpful_votes')
          .insert({'review_id': reviewId, 'user_id': userId});
    } else {
      await _client
          .from('review_helpful_votes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', userId);
    }
  }

  /// Ответ на отзыв — от обычного пользователя или от владельца места
  /// (флаг is_owner_reply и уведомление автору отзыва проставляются
  /// триггерами на сервере, см. schema.sql — клиент их не передаёт).
  static Future<void> submitReviewReply(
      {required String reviewId, required String text}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');
    await _client.from('review_replies').insert({
      'review_id': reviewId,
      'user_id': userId,
      'text': text,
    });
  }

  // ------------------------------------------------------------
  // Сохранённые места
  // ------------------------------------------------------------

  static Future<bool> isPlaceSaved(String placeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _client
        .from('saved_places')
        .select('place_id')
        .match({'user_id': userId, 'place_id': placeId}).maybeSingle();
    return row != null;
  }

  static Future<List<PlaceCardData>> fetchSavedPlaces() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('saved_places')
        .select('places($_placeCardColumns)')
        .eq('user_id', userId);

    return (rows as List)
        .map((r) => r['places'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(_placeFromRow)
        .toList();
  }

  static Future<void> toggleSavedPlace(String placeId,
      {required bool save}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    if (save) {
      await _client
          .from('saved_places')
          .insert({'user_id': userId, 'place_id': placeId});
    } else {
      await _client
          .from('saved_places')
          .delete()
          .match({'user_id': userId, 'place_id': placeId});
    }
  }

  // ------------------------------------------------------------
  // Черновики отзывов
  // ------------------------------------------------------------

  static Future<List<ReviewDraftData>> fetchMyDrafts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('review_drafts')
        .select(
            'id, place_id, place_name_draft, rating, text, pros, cons, price_level, updated_at, places(name)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (rows as List).map((r) {
      final place = r['places'] as Map<String, dynamic>?;
      return ReviewDraftData(
        id: r['id'] as String,
        placeId: r['place_id'] as String?,
        placeName:
            (place?['name'] as String?) ?? r['place_name_draft'] as String?,
        rating: r['rating'] as int?,
        text: r['text'] as String?,
        pros: r['pros'] as String?,
        cons: r['cons'] as String?,
        priceLevel: r['price_level'] as String?,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
    }).toList();
  }

  /// Сохраняет черновик отзыва: создаёт новый или обновляет существующий,
  /// если передан [draftId]. Возвращает id сохранённого черновика.
  static Future<String> saveDraft({
    String? draftId,
    String? placeId,
    String? placeNameDraft,
    int? rating,
    String? text,
    String? pros,
    String? cons,
    String? priceLevel,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final payload = {
      'user_id': userId,
      'place_id': placeId,
      'place_name_draft': placeId == null ? placeNameDraft : null,
      'rating': rating,
      'text': text,
      'pros': pros,
      'cons': cons,
      'price_level': priceLevel,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (draftId != null) {
      await _client.from('review_drafts').update(payload).eq('id', draftId);
      return draftId;
    }
    final row = await _client
        .from('review_drafts')
        .insert(payload)
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<void> deleteDraft(String id) async {
    await _client.from('review_drafts').delete().eq('id', id);
  }

  // ------------------------------------------------------------
  // Уведомления (in-app; пишутся сервером — см. api/telegram-webhook.js)
  // ------------------------------------------------------------

  static Future<List<NotificationData>> fetchNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Пользователь не авторизован');

    final rows = await _client
        .from('notifications')
        .select('id, title, body, is_read, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => NotificationData(
              id: r['id'] as String,
              title: r['title'] as String,
              body: r['body'] as String,
              isRead: r['is_read'] as bool,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  static Future<int> fetchUnreadNotificationsCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (rows as List).length;
  }

  static Future<void> markAllNotificationsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
