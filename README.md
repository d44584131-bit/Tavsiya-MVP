# Схема данных Tavsiya (Supabase / Postgres)

## Таблицы и связи

```
auth.users (Supabase Auth)
   │ 1:1 (trigger handle_new_user)
   ▼
profiles ──────────────┐
   │ 1:N                │ 1:N
   ▼                    ▼
reviews             saved_places ──► places
   │ 1:N                              ▲
   ▼                                  │ 1:N
review_photos                    place_photos
   │
   ▼
review_helpful_votes (N:M profiles ↔ reviews)

profiles ──N:M(follows)──► profiles
profiles ──1:N──► review_drafts
```

## Ключевые решения

- **Категория места** — фиксированный `enum place_category` (`restaurant/cafe/park/mall`), лейблы на русском/узбекском живут на клиенте (i18n), не в БД — это позволяет переключать язык интерфейса без миграций.
- **Многоязычность отзывов** — `reviews.language` хранится только как метаданные. RLS и запросы **не фильтруют** отзывы по языку: все `status = 'approved'` отзывы места видны всем пользователям вне зависимости от языка интерфейса (см. правило проекта).
- **Денормализация счётчиков** — `places.rating_avg`, `places.reviews_count`, `profiles.reviews_count`, `reviews.helpful_count`, `profiles.saved_count` пересчитываются триггерами при изменении связанных таблиц. Это позволяет рендерить списки карточек без тяжёлых `AVG`/`COUNT` на каждый запрос.
- **Модерация** — `reviews.status` (`pending/approved/rejected`). Публикация отзыва создаёт запись со статусом `pending`; смену статуса делает отдельный модераторский сервис/админка (вне этой схемы, см. "Вне рамок MVP" в исходном ТЗ) через service-role ключ, в обход обычных RLS-политик пользователя.
- **"Вы эксперт" / прогресс уровня** — считается на клиенте из `profiles.reviews_count` (простое MVP-правило); при усложнении логики уровней стоит вынести в отдельную таблицу `expert_levels` или view.
- **Фото** — не хранятся в БД как бинарные данные: таблицы `place_photos`/`review_photos` держат только `storage_path` в Supabase Storage (buckets `place-photos`, `review-photos`, `avatars`).
- **Один отзыв на пользователя на место** — `unique (place_id, user_id)` в `reviews`; повторное посещение оформляется как редактирование существующего отзыва, а не дубль.

## RLS в двух словах

| Таблица | Читать | Писать |
|---|---|---|
| profiles | все | только владелец (update) |
| places | все | любой authenticated (insert) |
| reviews | approved-отзывы всем + свои любые | только свои, редактирование пока `pending` |
| saved_places / review_drafts | только владелец | только владелец |
| follows / review_helpful_votes | все читают | только от своего имени |

## Что дальше по БД

- Полнотекстовый поиск сейчас через `pg_trgm` по `places.name`; при росте базы — перейти на `tsvector` + GIN.
- Геопоиск ("места рядом") — задел есть (`latitude`/`longitude`), но для реального geo-запроса потребуется расширение `postgis`.
- Таблица под уведомления (из раздела "Уведомления" в ТЗ) не создана — она вне MVP, добавляется отдельной миграцией, когда фича будет в разработке.
