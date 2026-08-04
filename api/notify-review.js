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
    `${SUPABASE_URL}/rest/v1/reviews?id=eq.${reviewId}&select=id,rating,text,places(name),profiles!reviews_user_id_fkey(display_name)`,
    { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
  );
  const rows = await reviewRes.json();
  const review = Array.isArray(rows) ? rows[0] : null;
  if (!review) {
    res.status(404).json({ error: 'Review not found' });
    return;
  }

  const placeName = review.places?.name ?? 'Неизвестное место';
  const authorName = review.profiles?.display_name ?? 'Гость';
  const stars = '⭐'.repeat(review.rating ?? 0);
  const text = [
    '🆕 Новый отзыв на модерации',
    `Место: ${placeName}`,
    `Автор: ${authorName}`,
    `Оценка: ${stars}`,
    '',
    review.text ?? '',
  ].join('\n');

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
