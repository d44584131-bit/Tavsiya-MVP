-- =========================================================
-- Tavsiya — схема базы данных (Supabase / Postgres)
-- =========================================================
-- Порядок применения: этот файл целиком через Supabase SQL Editor
-- или как одну миграцию (supabase db push / migration new).
-- =========================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- быстрый поиск по названию (ILIKE / similarity)

-- ---------------------------------------------------------
-- ENUM-типы
-- ---------------------------------------------------------

create type place_category as enum ('restaurant', 'cafe', 'park', 'mall');

create type review_status as enum ('pending', 'approved', 'rejected');

create type price_level as enum ('budget', 'mid', 'mid_high', 'high');
-- budget: до 50 000, mid: 50-150 тыс, mid_high: 150-300 тыс, high: 300 тыс+

create type with_whom as enum ('alone', 'partner', 'friends', 'family');

create type review_language as enum ('ru', 'uz');
-- метаданные языка отзыва (для аналитики / будущего автоперевода),
-- НЕ используется для фильтрации видимости отзывов.

-- ---------------------------------------------------------
-- profiles — публичный профиль пользователя (1:1 с auth.users)
-- ---------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  avatar_url text,
  bio text,
  preferred_language review_language not null default 'ru',
  -- денормализованные счётчики — обновляются триггерами, чтобы не считать COUNT(*) на каждый рендер профиля
  reviews_count integer not null default 0,
  helpful_votes_count integer not null default 0,
  saved_count integer not null default 0,
  followers_count integer not null default 0,
  following_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Публичный профиль пользователя; статус эксперта считается из reviews_count на уровне приложения/view.';

-- ---------------------------------------------------------
-- places — места (рестораны/кафе/парки/ТЦ)
-- ---------------------------------------------------------

create table public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category place_category not null,
  description text,
  address text,
  district text,
  phone text,
  website text,
  price_level price_level,
  latitude double precision,
  longitude double precision,
  is_verified boolean not null default false,
  -- денормализация для быстрого рендера карточек без JOIN + AVG на каждый список
  rating_avg numeric(2,1) not null default 0,
  reviews_count integer not null default 0,
  photos_count integer not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index places_category_idx on public.places (category);
create index places_district_idx on public.places (district);
create index places_name_trgm_idx on public.places using gin (name gin_trgm_ops);

comment on table public.places is 'Места. Категория и переводимые лейблы категорий хранятся на клиенте (ru/uz), сама категория — фиксированный enum-ключ.';

-- ---------------------------------------------------------
-- place_photos — фото места (галерея карточки)
-- ---------------------------------------------------------

create table public.place_photos (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  storage_path text not null, -- путь в Supabase Storage, bucket 'place-photos'
  uploaded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index place_photos_place_idx on public.place_photos (place_id);

-- ---------------------------------------------------------
-- reviews — отзывы
-- ---------------------------------------------------------

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  text text not null check (char_length(text) between 10 and 500),
  pros text,
  cons text,
  price_level price_level,
  with_whom with_whom,
  language review_language not null default 'ru', -- метаданные, не влияет на видимость (см. комментарий к enum)
  status review_status not null default 'pending',
  moderated_by uuid references public.profiles (id) on delete set null,
  moderated_at timestamptz,
  rejection_reason text,
  helpful_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- один отзыв на пользователя на место (редактирование вместо дублей)
  unique (place_id, user_id)
);

create index reviews_place_idx on public.reviews (place_id) where status = 'approved';
create index reviews_user_idx on public.reviews (user_id);
create index reviews_status_idx on public.reviews (status);

comment on column public.reviews.language is 'Язык, на котором написан отзыв. Отзывы НЕ фильтруются по языку интерфейса — все approved-отзывы места видны всем пользователям независимо от языка UI.';

-- ---------------------------------------------------------
-- review_photos — фото внутри отзыва
-- ---------------------------------------------------------

create table public.review_photos (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews (id) on delete cascade,
  storage_path text not null, -- bucket 'review-photos'
  created_at timestamptz not null default now()
);

create index review_photos_review_idx on public.review_photos (review_id);

-- ---------------------------------------------------------
-- review_helpful_votes — отметки "полезно" под отзывом
-- ---------------------------------------------------------

create table public.review_helpful_votes (
  review_id uuid not null references public.reviews (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);

-- ---------------------------------------------------------
-- saved_places — сохранённые места пользователя
-- ---------------------------------------------------------

create table public.saved_places (
  user_id uuid not null references public.profiles (id) on delete cascade,
  place_id uuid not null references public.places (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

-- ---------------------------------------------------------
-- follows — подписки между пользователями (вне MVP, задел на будущее)
-- ---------------------------------------------------------

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

-- ---------------------------------------------------------
-- review_drafts — черновики отзывов (форма отзыва, шаг "Черновики" в профиле)
-- ---------------------------------------------------------

create table public.review_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  place_id uuid references public.places (id) on delete set null,
  place_name_draft text, -- если место ещё не выбрано/не создано
  rating smallint check (rating between 0 and 5),
  text text,
  pros text,
  cons text,
  price_level price_level,
  with_whom with_whom,
  updated_at timestamptz not null default now()
);

create index review_drafts_user_idx on public.review_drafts (user_id);

-- ---------------------------------------------------------
-- collections / collection_places — курируемые подборки мест
-- ("Подборки для вас" на главном экране)
-- ---------------------------------------------------------

create table public.collections (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.collection_places (
  collection_id uuid not null references public.collections (id) on delete cascade,
  place_id uuid not null references public.places (id) on delete cascade,
  sort_order integer not null default 0,
  primary key (collection_id, place_id)
);

-- =========================================================
-- ТРИГГЕРЫ: денормализованные счётчики
-- =========================================================

-- updated_at автообновление
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_places_updated_at before update on public.places
  for each row execute function public.set_updated_at();
create trigger trg_reviews_updated_at before update on public.reviews
  for each row execute function public.set_updated_at();

-- Пересчёт rating_avg / reviews_count у места при изменении статуса отзыва
create or replace function public.recalc_place_rating()
returns trigger language plpgsql as $$
declare
  target_place_id uuid;
begin
  target_place_id := coalesce(new.place_id, old.place_id);

  update public.places p
  set rating_avg = coalesce((
        select round(avg(r.rating)::numeric, 1)
        from public.reviews r
        where r.place_id = target_place_id and r.status = 'approved'
      ), 0),
      reviews_count = (
        select count(*) from public.reviews r
        where r.place_id = target_place_id and r.status = 'approved'
      )
  where p.id = target_place_id;

  return null;
end;
$$;

create trigger trg_reviews_recalc_rating
  after insert or update of status or delete on public.reviews
  for each row execute function public.recalc_place_rating();

-- Счётчик отзывов у профиля (для статуса "эксперт" и т.п.) — считаем по approved-отзывам
create or replace function public.recalc_profile_reviews_count()
returns trigger language plpgsql as $$
declare
  target_user_id uuid;
begin
  target_user_id := coalesce(new.user_id, old.user_id);

  update public.profiles pr
  set reviews_count = (
    select count(*) from public.reviews r
    where r.user_id = target_user_id and r.status = 'approved'
  )
  where pr.id = target_user_id;

  return null;
end;
$$;

create trigger trg_reviews_recalc_profile_count
  after insert or update of status or delete on public.reviews
  for each row execute function public.recalc_profile_reviews_count();

-- Счётчик "полезно" на отзыве
create or replace function public.recalc_review_helpful_count()
returns trigger language plpgsql as $$
declare
  target_review_id uuid;
begin
  target_review_id := coalesce(new.review_id, old.review_id);
  update public.reviews
  set helpful_count = (select count(*) from public.review_helpful_votes where review_id = target_review_id)
  where id = target_review_id;
  return null;
end;
$$;

create trigger trg_helpful_votes_recalc
  after insert or delete on public.review_helpful_votes
  for each row execute function public.recalc_review_helpful_count();

-- Счётчик сохранённых мест у профиля
create or replace function public.recalc_profile_saved_count()
returns trigger language plpgsql as $$
declare
  target_user_id uuid;
begin
  target_user_id := coalesce(new.user_id, old.user_id);
  update public.profiles
  set saved_count = (select count(*) from public.saved_places where user_id = target_user_id)
  where id = target_user_id;
  return null;
end;
$$;

create trigger trg_saved_places_recalc
  after insert or delete on public.saved_places
  for each row execute function public.recalc_profile_saved_count();

-- Автосоздание profiles при регистрации пользователя (auth.users -> profiles)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  -- 'display_name' — из формы регистрации по email; 'full_name'/'name' —
  -- то, что присылает Google OAuth в raw_user_meta_data.
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      'Новый пользователь'
    )
  );
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.profiles enable row level security;
alter table public.places enable row level security;
alter table public.place_photos enable row level security;
alter table public.reviews enable row level security;
alter table public.review_photos enable row level security;
alter table public.review_helpful_votes enable row level security;
alter table public.saved_places enable row level security;
alter table public.follows enable row level security;
alter table public.review_drafts enable row level security;
alter table public.collections enable row level security;
alter table public.collection_places enable row level security;

-- profiles: читать может любой (публичный профиль), редактировать — только владелец
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- places: читать может любой; создавать/редактировать — авторизованный пользователь
-- (модерация новых мест — на уровне отдельного admin-флоу/сервиса, вне этой схемы)
create policy "places_select_all" on public.places for select using (true);
create policy "places_insert_authenticated" on public.places for insert with check (auth.uid() is not null);

create policy "place_photos_select_all" on public.place_photos for select using (true);
create policy "place_photos_insert_authenticated" on public.place_photos for insert with check (auth.uid() is not null);

-- reviews: видны всем approved-отзывы + собственные отзывы автору (включая pending/rejected)
create policy "reviews_select_approved_or_own" on public.reviews
  for select using (status = 'approved' or auth.uid() = user_id);

create policy "reviews_insert_own" on public.reviews
  for insert with check (auth.uid() = user_id);

create policy "reviews_update_own_pending" on public.reviews
  for update using (auth.uid() = user_id and status = 'pending');
  -- редактировать можно только пока отзыв не прошёл модерацию;
  -- смену статуса (approve/reject) делает отдельная service-role роль модерации

create policy "review_photos_select_visible" on public.review_photos
  for select using (
    exists (
      select 1 from public.reviews r
      where r.id = review_photos.review_id
        and (r.status = 'approved' or r.user_id = auth.uid())
    )
  );
create policy "review_photos_insert_own" on public.review_photos
  for insert with check (
    exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid())
  );

-- helpful votes: видно всем, ставить/убирать может только сам пользователь за себя
create policy "helpful_select_all" on public.review_helpful_votes for select using (true);
create policy "helpful_insert_own" on public.review_helpful_votes for insert with check (auth.uid() = user_id);
create policy "helpful_delete_own" on public.review_helpful_votes for delete using (auth.uid() = user_id);

-- saved_places: видит и управляет только владелец
create policy "saved_select_own" on public.saved_places for select using (auth.uid() = user_id);
create policy "saved_insert_own" on public.saved_places for insert with check (auth.uid() = user_id);
create policy "saved_delete_own" on public.saved_places for delete using (auth.uid() = user_id);

-- follows: подписки видны всем, управляет только сам подписчик
create policy "follows_select_all" on public.follows for select using (true);
create policy "follows_insert_own" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete_own" on public.follows for delete using (auth.uid() = follower_id);

-- review_drafts: полностью приватны
create policy "drafts_all_own" on public.review_drafts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- collections: читать может любой; управляют только через дашборд/сервисную роль
create policy "collections_select_all" on public.collections for select using (true);
create policy "collection_places_select_all" on public.collection_places for select using (true);

-- =========================================================
-- STORAGE BUCKETS (создать через Dashboard или отдельным скриптом)
-- =========================================================
-- avatars        — публичный, 1 файл на пользователя (path: {user_id}/avatar.jpg)
-- place-photos   — публичный на чтение, запись — authenticated
-- review-photos  — публичный на чтение, запись — authenticated, привязка к своему отзыву
