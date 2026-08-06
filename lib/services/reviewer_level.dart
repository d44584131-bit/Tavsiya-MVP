/// Уровень пользователя по количеству одобренных отзывов — единая логика
/// для бейджа в профиле и для значка автора на карточках отзывов.
enum ReviewerLevel { novice, expert, guru }

const _expertThreshold = 10;
const _guruThreshold = 50;

ReviewerLevel reviewerLevelFor(int reviewsCount) {
  if (reviewsCount >= _guruThreshold) return ReviewerLevel.guru;
  if (reviewsCount >= _expertThreshold) return ReviewerLevel.expert;
  return ReviewerLevel.novice;
}
