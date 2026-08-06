// Уведомляет администратора в Telegram о новом отзыве, ожидающем модерации,
// с кнопками "Одобрить"/"Отклонить" (нажатия обрабатывает telegram-webhook.js).
// Требует переменные окружения:
//   TELEGRAM_BOT_TOKEN, TELEGRAM_ADMIN_CHAT_ID — как в api/feedback.js
//   SUPABASE_SERVICE_ROLE_KEY — секретный ключ Supabase (Project Settings →
//     API → service_role). Даёт полный доступ к базе в обход RLS, поэтому
//     используется только здесь, на сервере, и никогда не попадает в приложение.

const SUPABASE_URL = 'https://ktdffwoogvyjbfzteaev.supabase.co';

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_ADMIN_CHAT_ID;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!botToken || !chatId || !serviceKey) {
    res.status(500).json({ error: 'Server is not configured' });
    return;
  }

  const { reviewId } = req.body ?? {};
  if (!reviewId) {
    res.status(400).json({ error: 'reviewId is required' });
    return;
  }

  const reviewRes = await fetch(
    `${SUPABASE_URL}/rest/v1/reviews?id=eq.${reviewId}&select=id,rating,text,pros,cons,price_level,created_at,places(name),profiles!reviews_user_id_fkey(display_name),review_photos(storage_path)`,
    { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
  );
  const rows = await reviewRes.json();
  const review = Array.isArray(rows) ? rows[0] : null;
  if (!review) {
    res.status(404).json({ error: 'Review not found' });
    return;
  }

  const PRICE_LABELS = {
    budget: 'до 50 000',
    mid: '50–150 тыс',
    mid_high: '150–300 тыс',
    high: '300 тыс+',
  };

  const placeName = review.places?.name ?? 'Неизвестное место';
  const authorName = review.profiles?.display_name ?? 'Гость';
  const stars = '⭐'.repeat(review.rating ?? 0);
  const date = formatDate(review.created_at);

  const lines = [
    '🆕 Новый отзыв на модерации',
    `Место: ${placeName}`,
    `Автор: ${authorName}`,
    `Оценка: ${stars}`,
    `Дата: ${date}`,
  ];
  if (review.price_level) {
    lines.push(`Средний чек: ${PRICE_LABELS[review.price_level] ?? review.price_level}`);
  }
  lines.push('', review.text ?? '');
  if (review.pros) lines.push('', `👍 Понравилось: ${review.pros}`);
  if (review.cons) lines.push(`👎 Не понравилось: ${review.cons}`);
  const text = lines.join('\n');

  const photoUrls = (review.review_photos ?? [])
    .map((p) => `${SUPABASE_URL}/storage/v1/object/public/review-photos/${p.storage_path}`)
    .slice(0, 10);

  if (photoUrls.length === 1) {
    await fetch(`https://api.telegram.org/bot${botToken}/sendPhoto`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, photo: photoUrls[0] }),
    });
  } else if (photoUrls.length > 1) {
    await fetch(`https://api.telegram.org/bot${botToken}/sendMediaGroup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        media: photoUrls.map((url) => ({ type: 'photo', media: url })),
      }),
    });
  }

  await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Одобрить', callback_data: `approve:${reviewId}` },
            { text: '❌ Отклонить', callback_data: `reject:${reviewId}` },
          ],
        ],
      },
    }),
  });

  res.status(200).json({ ok: true });
};

function formatDate(isoString) {
  const d = new Date(isoString);
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`;
}
