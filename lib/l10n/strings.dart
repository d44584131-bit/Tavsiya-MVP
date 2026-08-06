import 'package:flutter/widgets.dart';
import '../screens/profile/profile_screen.dart' show AppLanguage;
import 'app_language_scope.dart';

/// Короткий доступ к переводам из build(): `s(context).trendingTitle`.
Strings s(BuildContext context) => Strings(AppLanguageScope.of(context));

/// Города, доступные для выбора (онбординг + шапка главного экрана).
/// Полноценные данные о местах пока есть только для Ташкента.
const kCityKeys = [
  'tashkent',
  'samarkand',
  'bukhara',
  'andijan',
  'fergana',
  'namangan',
  'nukus'
];
const kDefaultCity = 'tashkent';

/// Все тексты интерфейса на русском/узбекском в одном месте. Никакой
/// системы ARB/intl не подключаем — приложение маленькое, а так строки
/// видно рядом друг с другом и легко сверять переводы.
class Strings {
  final AppLanguage lang;
  const Strings(this.lang);

  bool get _uz => lang == AppLanguage.uz;
  String _t(String ru, String uz) => _uz ? uz : ru;

  // ---------------------------------------------------------------
  // Общее
  // ---------------------------------------------------------------
  String get retry => _t('Повторить', 'Qayta urinish');
  String get seeAll => _t('Все', 'Barchasi');
  String get loadErrorGeneric =>
      _t('Не удалось загрузить данные', 'Maʼlumotlarni yuklab boʻlmadi');
  String get notSpecified => _t('Не указан', 'Koʻrsatilmagan');
  String get cityName => _t('Ташкент', 'Toshkent');

  // ---------------------------------------------------------------
  // Города/регионы (выбор в онбординге и на главном экране)
  // ---------------------------------------------------------------
  static const _cityLabelRu = {
    'tashkent': 'Ташкент',
    'samarkand': 'Самарканд',
    'bukhara': 'Бухара',
    'andijan': 'Андижан',
    'fergana': 'Фергана',
    'namangan': 'Наманган',
    'nukus': 'Нукус',
  };
  static const _cityLabelUz = {
    'tashkent': 'Toshkent',
    'samarkand': 'Samarqand',
    'bukhara': 'Buxoro',
    'andijan': 'Andijon',
    'fergana': "Farg'ona",
    'namangan': 'Namangan',
    'nukus': 'Nukus',
  };
  String cityLabel(String city) =>
      (_uz ? _cityLabelUz : _cityLabelRu)[city] ?? city;
  String get chooseCityTitle => _t('Выберите город', 'Shahringizni tanlang');
  String get chooseCitySubtitle => _t(
      'Пока полноценно работает только Ташкент — остальные города появятся позже',
      'Hozircha faqat Toshkent uchun toʻliq maʼlumot bor — boshqa shaharlar keyinroq qoʻshiladi');

  // ---------------------------------------------------------------
  // Категории мест (badge — единственное число / фильтр — множественное)
  // ---------------------------------------------------------------
  static const _categoryLabelRu = {
    'restaurant': 'Ресторан',
    'cafe': 'Кафе',
    'park': 'Парк',
    'mall': 'ТЦ'
  };
  static const _categoryLabelUz = {
    'restaurant': 'Restoran',
    'cafe': 'Kafe',
    'park': 'Park',
    'mall': 'SM'
  };
  static const _categoryPluralRu = {
    'restaurant': 'Рестораны',
    'cafe': 'Кафе',
    'park': 'Парки',
    'mall': 'ТЦ'
  };
  static const _categoryPluralUz = {
    'restaurant': 'Restoranlar',
    'cafe': 'Kafelar',
    'park': 'Parklar',
    'mall': 'SMlar'
  };

  String categoryLabel(String category) =>
      (_uz ? _categoryLabelUz : _categoryLabelRu)[category] ?? category;
  String categoryPlural(String category) =>
      (_uz ? _categoryPluralUz : _categoryPluralRu)[category] ?? category;

  // ---------------------------------------------------------------
  // Нижнее меню
  // ---------------------------------------------------------------
  String get navHome => _t('Главная', 'Bosh sahifa');
  String get navSearch => _t('Поиск', 'Qidiruv');
  String get navReview => _t('Отзыв', 'Sharh');
  String get navProfile => _t('Профиль', 'Profil');

  // ---------------------------------------------------------------
  // Главная (home_screen.dart)
  // ---------------------------------------------------------------
  String get searchHint => _t('Найти место…', 'Joy qidirish…');
  String get trendingTitle => _t('Сейчас популярно', 'Hozir mashhur');
  String get categoriesTitle => _t('Категории', 'Kategoriyalar');
  String get categoryEmpty =>
      _t('В этой категории пока пусто', 'Bu toifada hozircha boʻsh');
  String get recentReviewsTitle => _t('Новые отзывы', 'Yangi sharhlar');
  String get collectionsTitle => _t('Подборки для вас', 'Siz uchun tanlovlar');
  String get noPlacesYet => _t('Пока нет мест', 'Hozircha joylar yoʻq');

  // ---------------------------------------------------------------
  // Поиск (search_screen.dart)
  // ---------------------------------------------------------------
  String get searchTitle => _t('Поиск', 'Qidiruv');
  String get allCategories => _t('Все', 'Barchasi');
  String get searchLoadError =>
      _t('Не удалось загрузить результаты', 'Natijalarni yuklab boʻlmadi');
  String get nothingFound => _t('Ничего не найдено', 'Hech narsa topilmadi');
  String get nothingFoundHint => _t(
      'Попробуйте изменить запрос или выбрать другую категорию',
      'Soʻrovni oʻzgartiring yoki boshqa toifani tanlang');

  // ---------------------------------------------------------------
  // Карточка места (place_detail_screen.dart)
  // ---------------------------------------------------------------
  String get tabOverview => _t('Обзор', 'Umumiy');
  String get tabReviews => _t('Отзывы', 'Sharhlar');
  String get tabPhotos => _t('Фото', 'Fotolar');
  String get tabInfo => _t('Информация', 'Maʼlumot');
  String get placeLoadError => _t(
      'Не удалось загрузить место. Проверьте подключение и попробуйте снова.',
      'Joyni yuklab boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring.');
  String get placeNotFound => _t('Место не найдено', 'Joy topilmadi');
  String get verifiedBadge => _t('Подтверждено', 'Tasdiqlangan');
  String get callAction => _t('Позвонить', 'Qoʻngʻiroq');
  String get routeAction => _t('Маршрут', 'Yoʻnalish');
  String get websiteAction => _t('Сайт', 'Sayt');
  String get saveAction => _t('Сохранить', 'Saqlash');
  String get statRating => _t('Рейтинг', 'Reyting');
  String get statReviews => _t('Отзывов', 'Sharhlar');
  String get statPhotos => _t('Фото', 'Fotolar');
  String get statPrice => _t('Цена', 'Narx');
  String get aboutTitle => _t('О месте', 'Joy haqida');
  String get noDescription =>
      _t('Описание места пока не добавлено.', 'Joy tavsifi hali qoʻshilmagan.');
  String get readMore => _t('Читать далее', 'Davomini oʻqish');
  String get collapse => _t('Свернуть', 'Yigʻish');
  String get recentReviewsShort => _t('Последние отзывы', 'Soʻnggi sharhlar');
  String get noReviewsYet => _t('Пока нет отзывов — станьте первым',
      'Hozircha sharhlar yoʻq — birinchi boʻling');
  String get noPhotosYet =>
      _t('Фото пока не добавлены', 'Fotolar hali qoʻshilmagan');
  String get infoAddress => _t('Адрес', 'Manzil');
  String get infoPhone => _t('Телефон', 'Telefon');
  String get infoWebsite => _t('Сайт', 'Sayt');
  String get infoAvgCheck => _t('Средний чек', 'Oʻrtacha chek');
  String get leaveReview => _t('Оставить отзыв', 'Sharh qoldirish');
  String get pendingBadge => _t('На модерации', 'Moderatsiyada');
  String get rejectedBadge => _t('Отклонён', 'Rad etilgan');
  String get saveError => _t('Не удалось сохранить место, попробуйте ещё раз',
      'Joyni saqlab boʻlmadi, qayta urinib koʻring');
  String get guestReviewer => _t('Гость', 'Mehmon');
  String get placeDeleted => _t('Место удалено', 'Joy oʻchirilgan');

  // ---------------------------------------------------------------
  // Список мест / подборки (place_list_screen.dart, collections_list_screen.dart)
  // ---------------------------------------------------------------
  String get placesLoadError =>
      _t('Не удалось загрузить места', 'Joylarni yuklab boʻlmadi');
  String get emptyListTitle => _t('Пока пусто', 'Hozircha boʻsh');
  String get emptyListSubtitle =>
      _t('Здесь пока нет мест', 'Bu yerda hali joylar yoʻq');

  String placesCount(int count) => _uz
      ? '$count ta joy'
      : '$count ${_ruPlural(count, 'место', 'места', 'мест')}';
  String reviewsCount(int count) => _uz
      ? '$count ta sharh'
      : '$count ${_ruPlural(count, 'отзыв', 'отзыва', 'отзывов')}';

  /// Русское склонение по числу: 1 — one, 2–4 — few, 5+/11–14 — many.
  static String _ruPlural(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  // ---------------------------------------------------------------
  // Форма отзыва (review_form_screen.dart)
  // ---------------------------------------------------------------
  String get stepDone => _t('Готово', 'Tayyor');
  String get placeStepTitle =>
      _t('О каком месте отзыв?', 'Qaysi joy haqida sharh?');
  String get placeStepHint => _t(
      'Выберите место из списка или добавьте новое, чтобы продолжить',
      'Davom etish uchun roʻyxatdan joy tanlang yoki yangisini qoʻshing');
  String get rateStepHintNoRating => _t(
      'Поставьте оценку (звёзды), чтобы продолжить',
      'Davom etish uchun baho qoʻying (yulduzcha)');
  String get rateStepHintShortText => _t(
      'Напишите ещё немного — минимум 10 символов',
      'Yana biroz yozing — kamida 10 ta belgi');
  String get placeSearchHint => _t('Название места…', 'Joy nomi…');
  String addPlaceLabel(String name) =>
      _t('Добавить «$name»', '«$name» ni qoʻshish');
  String get placeCategoryLabel => _t('Категория места', 'Joy toifasi');
  String get rateQuestion =>
      _t('Как оцените место?', 'Joyni qanday baholaysiz?');
  String get yourReviewLabel => _t('Ваш отзыв', 'Sizning sharhingiz');
  String get reviewHint => _t('Расскажите, что понравилось или нет…',
      'Nima yoqdi yoki yoqmadi — yozing…');
  String get photosOptionalLabel =>
      _t('Фото (по желанию)', 'Fotolar (ixtiyoriy)');
  String get photosMaxHint => _t('До 6 фото', 'Maksimum 6 ta foto');
  String get choosePhotoGallery =>
      _t('Выбрать из галереи', 'Galereyadan tanlash');
  String get choosePhotoCamera => _t('Сделать фото', 'Suratga olish');
  String get prosQuestion => _t('Что понравилось?', 'Nima yoqdi?');
  String get prosHint => _t(
      'Например: вкусно, быстро, приветливо', 'Masalan: mazali, tez, doʻstona');
  String get consQuestion => _t('Что не понравилось?', 'Nima yoqmadi?');
  String get consHint =>
      _t('Например: долго ждали, шумно', 'Masalan: uzoq kutdik, shovqinli');
  String get avgCheckLabel => _t('Средний чек', 'Oʻrtacha chek');
  String get priceChip0 => _t('до 50 000', '50 000 gacha');
  String get priceChip1 => _t('50–150 тыс', '50–150 ming');
  String get priceChip2 => _t('150–300 тыс', '150–300 ming');
  String get priceChip3 => _t('300 тыс+', '300 ming+');
  String priceLevelLabel(String key) => switch (key) {
        'budget' => priceChip0,
        'mid' => priceChip1,
        'mid_high' => priceChip2,
        'high' => priceChip3,
        _ => key,
      };
  String get reviewSubmitError => _t(
      'Не удалось отправить отзыв. Проверьте подключение и попробуйте снова',
      'Sharhni yuborib boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring');
  String get reviewDuplicateError => _t(
      'Вы уже оставили отзыв на это место — второй раз оставить нельзя',
      'Siz bu joyga sharh allaqachon qoldirgansiz — ikkinchi marta qoldirib boʻlmaydi');
  String get reviewPublishedTitle =>
      _t('Отзыв опубликован!', 'Sharh eʼlon qilindi!');
  String get reviewPublishedSubtitle => _t(
      'Спасибо! Он уже виден на странице места',
      'Rahmat! U joy sahifasida allaqachon koʻrinadi');
  String get backButton => _t('Назад', 'Orqaga');
  String get nextButton => _t('Далее', 'Keyingi');
  String get publishButton => _t('Опубликовать', 'Eʼlon qilish');

  // ---------------------------------------------------------------
  // Профиль (profile_screen.dart)
  // ---------------------------------------------------------------
  String get profileTitle => _t('Профиль', 'Profil');
  String get signInPromptTitle => _t('Войдите в аккаунт', 'Hisobga kiring');
  String get signInPromptSubtitle => _t(
      'Чтобы видеть свой профиль, отзывы и сохранённые места',
      'Profilingiz, sharhlar va saqlangan joylarni koʻrish uchun');
  String get signInButton => _t('Войти', 'Kirish');
  String get profileLoadError =>
      _t('Не удалось загрузить профиль', 'Profilni yuklab boʻlmadi');

  // ---------------------------------------------------------------
  // Предупреждение о необходимости входа перед действием (отзыв, сохранение)
  // ---------------------------------------------------------------
  String get authRequiredTitle =>
      _t('Нужна регистрация', 'Roʻyxatdan oʻtish kerak');
  String authRequiredMessage(String action) => _t(
      'Чтобы $action, сначала зарегистрируйтесь или войдите',
      '$action uchun avval roʻyxatdan oʻting yoki tizimga kiring');
  String get authRequiredActionReview =>
      _t('оставить отзыв', 'sharh qoldirish');
  String get authRequiredActionSave => _t('сохранить место', 'joyni saqlash');
  String get cancelButton => _t('Отмена', 'Bekor qilish');
  String get reviewApprovedPushTitle =>
      _t('Ваш отзыв одобрен', 'Sharhingiz tasdiqlandi');
  String reviewApprovedPushBody(String placeName) => _t(
      'Отзыв на «$placeName» теперь виден всем',
      '«$placeName» haqidagi sharhingiz endi hammaga koʻrinadi');

  // ---------------------------------------------------------------
  // Уведомления (notifications_screen.dart)
  // ---------------------------------------------------------------
  String get notificationsTitle => _t('Уведомления', 'Bildirishnomalar');
  String get noNotificationsTitle =>
      _t('Пока нет уведомлений', 'Hozircha bildirishnomalar yoʻq');
  String get noNotificationsSubtitle => _t(
      'Здесь появятся уведомления, например об одобрении отзыва',
      'Bu yerda bildirishnomalar paydo boʻladi, masalan sharh tasdiqlanganda');
  String get usefulLabel => _t('Полезно', 'Foydali');
  String get savedLabel => _t('Сохранено', 'Saqlangan');
  String get followersLabel => _t('Подписчиков', 'Obunachilar');
  String get expertBadge => _t('Вы эксперт', 'Siz ekspertsiz');
  String get noviceBadge => _t('Новичок', 'Yangi');
  String toGuruLevel(int remaining) => _t(
      'До уровня «Гуру» — ещё $remaining отзывов',
      '«Guru» darajasigacha yana $remaining ta sharh');
  String get tabMyReviews => _t('Мои отзывы', 'Mening sharhlarim');
  String get tabSaved => _t('Сохранённое', 'Saqlangan');
  String get tabSubscriptions => _t('Подписки', 'Obunalar');
  String get tabDrafts => _t('Черновики', 'Qoralamalar');
  String get noReviewsTitle => _t('Пока нет отзывов', 'Hozircha sharhlar yoʻq');
  String get noReviewsSubtitle => _t(
      'Оставьте первый отзыв о месте, в котором были — это займёт меньше минуты',
      'Boʻlgan joyingiz haqida birinchi sharhni qoldiring — bir daqiqadan kam vaqt oladi');
  String get savedSubTabPlaces => _t('Места', 'Joylar');
  String get savedSubTabReviews => _t('Отзывы', 'Sharhlar');
  String get noSavedPlacesTitle =>
      _t('Пока нет сохранённых мест', 'Hozircha saqlangan joylar yoʻq');
  String get noSavedPlacesSubtitle => _t(
      'Нажмите на иконку закладки на карточке места, чтобы сохранить его сюда',
      'Bu yerga saqlash uchun joy kartochkasidagi xatcho\'p belgisini bosing');
  String get noSavedReviewsTitle =>
      _t('Пока нет сохранённых отзывов', 'Hozircha saqlangan sharhlar yoʻq');
  String get noSavedReviewsSubtitle => _t(
      'Отмечайте полезные отзывы — они соберутся здесь',
      'Foydali sharhlarni belgilang — ular shu yerda toʻplanadi');
  String get noSubscriptionsTitle => _t('Нет подписок', 'Obunalar yoʻq');
  String get noSubscriptionsSubtitle => _t(
      'Подписывайтесь на других пользователей, чтобы видеть их отзывы первыми',
      'Boshqa foydalanuvchilarga obuna boʻling — sharhlarini birinchi bo\'lib ko\'ring');
  String get noDraftsTitle => _t('Нет черновиков', 'Qoralamalar yoʻq');
  String get noDraftsSubtitle => _t(
      'Незаконченные отзывы будут сохраняться здесь автоматически',
      'Tugallanmagan sharhlar shu yerda avtomatik saqlanadi');
  String get draftNoPlace => _t('Черновик без места', 'Joysiz qoralama');
  String get languageSectionTitle => _t('Язык интерфейса', 'Interfeys tili');
  String get themeSectionTitle => _t('Тема оформления', 'Mavzu');
  String get themeSystem => _t('Как в системе', 'Tizimdagidek');
  String get themeLight => _t('Светлая', 'Yorugʻ');
  String get themeDark => _t('Тёмная', 'Qorongʻi');
  String get feedbackButton =>
      _t('Жалобы и предложения', 'Shikoyat va takliflar');
  String get signOutButton => _t('Выйти из аккаунта', 'Hisobdan chiqish');

  // ---------------------------------------------------------------
  // Вход/регистрация (auth_screen.dart)
  // ---------------------------------------------------------------
  String get createAccountTitle => _t('Создать аккаунт', 'Hisob yaratish');
  String get welcomeBackTitle => _t('С возвращением', 'Xush kelibsiz');
  String get signUpSubtitle => _t(
      'Регистрация нужна, чтобы оставлять отзывы и сохранять места',
      'Sharh qoldirish va joylarni saqlash uchun roʻyxatdan oʻting');
  String get signInSubtitleAuth => _t(
      'Войдите, чтобы оставлять отзывы и сохранять места',
      'Sharh qoldirish va joylarni saqlash uchun kiring');
  String get continueWithGoogle =>
      _t('Продолжить с Google', 'Google orqali davom etish');
  String get orDivider => _t('или', 'yoki');
  String get nameHint => _t('Ваше имя', 'Ismingiz');
  String get emailHint => 'Email';
  String get passwordHint =>
      _t('Пароль (минимум 6 символов)', 'Parol (kamida 6 belgi)');
  String get signUpButton => _t('Зарегистрироваться', 'Roʻyxatdan oʻtish');
  String get haveAccountToggle =>
      _t('Уже есть аккаунт? Войти', 'Hisobingiz bormi? Kirish');
  String get noAccountToggle => _t('Нет аккаунта? Зарегистрироваться',
      'Hisobingiz yoʻqmi? Roʻyxatdan oʻtish');
  String get checkEmailSnackbar => _t(
      'Проверьте почту, чтобы подтвердить регистрацию, затем войдите',
      'Roʻyxatdan oʻtishni tasdiqlash uchun pochtangizni tekshiring, keyin kiring');
  String get googleSignInError => _t(
      'Не удалось войти через Google. Попробуйте ещё раз',
      'Google orqali kirib boʻlmadi. Qayta urinib koʻring');
  String get genericError => _t('Что-то пошло не так. Попробуйте ещё раз',
      'Nimadir xato ketdi. Qayta urinib koʻring');

  // ---------------------------------------------------------------
  // Жалобы и предложения (feedback_screen.dart)
  // ---------------------------------------------------------------
  String get feedbackIntro => _t(
      'Опишите, что случилось или что хотелось бы улучшить — сообщение придёт прямо разработчикам',
      'Nima boʻlganini yoki nimani yaxshilash kerakligini yozing — xabar toʻgʻridan-toʻgʻri dasturchilarga boradi');
  String get feedbackTypeLabel => _t('Тип обращения', 'Murojaat turi');
  String get complaintOption => _t('Жалоба', 'Shikoyat');
  String get suggestionOption => _t('Предложение', 'Taklif');
  String get messageHint => _t('Ваше сообщение…', 'Xabaringiz…');
  String get feedbackSendError => _t(
      'Не удалось отправить. Проверьте подключение и попробуйте снова',
      'Yuborib boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring');
  String get feedbackSentSnackbar => _t(
      'Спасибо! Сообщение отправлено разработчикам',
      'Rahmat! Xabar dasturchilarga yuborildi');
  String get sendButton => _t('Отправить', 'Yuborish');

  // ---------------------------------------------------------------
  // Онбординг (onboarding_screen.dart)
  // ---------------------------------------------------------------
  String get skip => _t('Пропустить', 'Oʻtkazib yuborish');
  String get startButton => _t('Начать', 'Boshlash');
  String get alreadyHaveAccount =>
      _t('У меня уже есть аккаунт', 'Mening hisobim bor');

  String get onboard1TitlePrefix =>
      _t('Находи лучшие места ', 'Eng yaxshi joylarni ');
  String get onboard1TitleAccent => _t('рядом с тобой', 'yoningizdan toping');
  String get onboard1Subtitle => _t(
      'Рестораны, кафе, парки и торговые центры Ташкента — с честными отзывами настоящих людей',
      'Toshkentning restoran, kafe, parklari va savdo markazlari — real odamlarning halol sharhlari bilan');

  String get onboard2TitlePrefix => _t('Выбирай ', 'Tanlang — ');
  String get onboard2TitleAccent => _t('по категориям', 'toifalar boʻyicha');
  String get onboard2Subtitle => _t('Всё, что интересно именно тебе',
      'Aynan sizga qiziqarli boʻlgan hamma narsa');

  String get onboard3TitlePrefix => _t('Доверяй ', 'Ishoning — ');
  String get onboard3TitleAccent =>
      _t('реальным отзывам', 'haqiqiy sharhlarga');
  String get onboard3Subtitle => _t(
      'Тысячи оценок от жителей города', 'Shahar aholisidan minglab baholar');
  String get onboardReview1 => _t(
      'Атмосфера просто огонь, обязательно вернёмся',
      'Muhiti zoʻr, albatta qaytamiz');
  String get onboardReview2 => _t('Отличное место для семейного отдыха',
      'Oilaviy dam olish uchun ajoyib joy');
}
