// Принимает вебхуки от Telegram: обрабатывает нажатия кнопок
// "Одобрить"/"Отклонить" под уведомлением о новом отзыве
// (см. api/notify-review.js) и обновляет статус отзыва в Supabase.
//
// Настройка (один раз, после того как заданы переменные окружения):
//   https://api.telegram.org/bot<TOKEN>/setWebhook?url=<адрес сайта>/api/telegram-webhook&secret_token=<TELEGRAM_WEBHOOK_SECRET>
//
// Переменные окружения:
//   TELEGRAM_BOT_TOKEN, SUPABASE_SERVICE_ROLE_KEY — как в api/notify-review.js
//   TELEGRAM_WEBHOOK_SECRET — произвольная секретная строка, которую вы сами
//     придумываете и используете в setWebhook выше; защищает эндпоинт от
//     чужих запросов (Telegram присылает её в заголовке при каждом вызове).

const SUPABASE_URL = 'https://ktdffwoogvyjbfzteaev.supabase.co';

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const expectedSecret = process.env.TELEGRAM_WEBHOOK_SECRET;
  if (expectedSecret && req.headers['x-telegram-bot-api-secret-token'] !== expectedSecret) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const update = req.body ?? {};
  const query = update.callback_query;
  if (!query) {
    // не нажатие кнопки (например, обычное сообщение боту) — просто отвечаем ok
    res.status(200).json({ ok: true });
    return;
  }

  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const [action, reviewId] = String(query.data ?? '').split(':');

  if (!['approve', 'reject'].includes(action) || !reviewId) {
    await answerCallback(botToken, query.id, 'Некорректная кнопка');
    res.status(200).json({ ok: true });
    return;
  }

  const newStatus = action === 'approve' ? 'approved' : 'rejected';

  const updateRes = await fetch(
    `${SUPABASE_URL}/rest/v1/reviews?id=eq.${reviewId}&select=user_id,places(name),profiles!reviews_user_id_fkey(preferred_language)`,
    {
      method: 'PATCH',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ status: newStatus }),
    },
  );

  if (!updateRes.ok) {
    await answerCallback(botToken, query.id, 'Ошибка обновления');
    res.status(200).json({ ok: true });
    return;
  }

  const label = action === 'approve' ? '✅ Одобрено' : '❌ Отклонено';
  await answerCallback(botToken, query.id, label);

  if (action === 'approve') {
    const updatedRows = await updateRes.json();
    const updated = Array.isArray(updatedRows) ? updatedRows[0] : null;
    if (updated?.user_id) {
      const placeName = updated.places?.name ?? '';
      const lang = updated.profiles?.preferred_language === 'uz' ? 'uz' : 'ru';
      const title = lang === 'uz' ? 'Sharhingiz tasdiqlandi' : 'Ваш отзыв одобрен';
      const body =
        lang === 'uz'
          ? `«${placeName}» haqidagi sharhingiz endi hammaga koʻrinadi`
          : `Отзыв на «${placeName}» теперь виден всем`;

      await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({ user_id: updated.user_id, title, body }),
      });
    }
  }

  const originalText = query.message?.text ?? '';
  if (query.message?.chat?.id && query.message?.message_id) {
    await fetch(`https://api.telegram.org/bot${botToken}/editMessageText`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: query.message.chat.id,
        message_id: query.message.message_id,
        text: `${originalText}\n\n${label}`,
      }),
    });
  }

  res.status(200).json({ ok: true });
};

async function answerCallback(botToken, callbackQueryId, text) {
  await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ callback_query_id: callbackQueryId, text }),
  });
}
