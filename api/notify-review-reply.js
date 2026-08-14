// Уведомляет администратора в Telegram о новом ответе заведения на отзыв,
// ожидающем модерации, с кнопками "Одобрить"/"Отклонить" (нажатия
// обрабатывает telegram-webhook.js). Только ответы владельца места
// (is_owner_reply) идут через модерацию — обычные ответы пользователей
// друг другу публикуются сразу и сюда не попадают.
// Требует те же переменные окружения, что и api/notify-review.js.

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

  const { replyId } = req.body ?? {};
  if (!replyId) {
    res.status(400).json({ error: 'replyId is required' });
    return;
  }

  const replyRes = await fetch(
    `${SUPABASE_URL}/rest/v1/review_replies?id=eq.${replyId}&select=id,text,is_owner_reply,reviews(text,rating,places(name))`,
    { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
  );
  const rows = await replyRes.json();
  const reply = Array.isArray(rows) ? rows[0] : null;
  if (!reply || !reply.is_owner_reply) {
    res.status(404).json({ error: 'Reply not found' });
    return;
  }

  const placeName = reply.reviews?.places?.name ?? 'Неизвестное место';
  const reviewText = reply.reviews?.text ?? '';
  const reviewStars = '⭐'.repeat(reply.reviews?.rating ?? 0);

  const lines = [
    '🆕 Новый ответ заведения на модерации',
    `Место: ${placeName}`,
    '',
    `Отзыв (${reviewStars}): ${reviewText}`,
    '',
    `Ответ заведения: ${reply.text}`,
  ];

  await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text: lines.join('\n'),
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Одобрить', callback_data: `reply_approve:${replyId}` },
            { text: '❌ Отклонить', callback_data: `reply_reject:${replyId}` },
          ],
        ],
      },
    }),
  });

  res.status(200).json({ ok: true });
};
