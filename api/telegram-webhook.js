// Принимает вебхуки от Telegram: обрабатывает нажатия кнопок
// "Одобрить"/"Отклонить" под уведомлением о новом отзыве
// (см. api/notify-review.js) или новом заведении (api/notify-place.js) и
// обновляет соответствующий статус в Supabase.
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
  const sep = String(query.data ?? '').lastIndexOf(':');
  const prefix = sep === -1 ? String(query.data ?? '') : query.data.slice(0, sep);
  const id = sep === -1 ? '' : query.data.slice(sep + 1);

  let label;
  if (['approve', 'reject'].includes(prefix) && id) {
    label = await moderateReview({ id, approve: prefix === 'approve', botToken, serviceKey });
  } else if (['place_approve', 'place_reject'].includes(prefix) && id) {
    label = await moderatePlace({ id, approve: prefix === 'place_approve', botToken, serviceKey });
  } else {
    await answerCallback(botToken, query.id, 'Некорректная кнопка');
    res.status(200).json({ ok: true });
    return;
  }

  if (label === null) {
    await answerCallback(botToken, query.id, 'Ошибка обновления');
    res.status(200).json({ ok: true });
    return;
  }

  await answerCallback(botToken, query.id, label);

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

/// Одобрение/отклонение отзыва. При одобрении пишет автору in-app
/// уведомление на его языке интерфейса (profiles.preferred_language), а
/// также отдельным уведомлением — владельцу(ям) заведения ("Вам пришёл
/// новый отзыв"), если это не он сам оставил отзыв на своё же место.
async function moderateReview({ id, approve, botToken, serviceKey }) {
  const newStatus = approve ? 'approved' : 'rejected';

  const updateRes = await fetch(
    `${SUPABASE_URL}/rest/v1/reviews?id=eq.${id}&select=user_id,place_id,places(name),profiles!reviews_user_id_fkey(preferred_language)`,
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
  if (!updateRes.ok) return null;

  if (approve) {
    const rows = await updateRes.json();
    const updated = Array.isArray(rows) ? rows[0] : null;
    if (updated?.user_id) {
      const placeName = updated.places?.name ?? '';
      const lang = updated.profiles?.preferred_language === 'uz' ? 'uz' : 'ru';
      const title = lang === 'uz' ? 'Izohingiz eʼlon qilindi' : 'Комментарий опубликован';
      const body =
        lang === 'uz'
          ? `«${placeName}» uchun izohingiz eʼlon qilindi`
          : `Комментарий на «${placeName}» опубликован`;
      await insertNotification({ userId: updated.user_id, title, body, serviceKey });
    }
    if (updated?.place_id) {
      await notifyPlaceOwnersOfNewReview({
        placeId: updated.place_id,
        placeName: updated.places?.name ?? '',
        reviewAuthorId: updated.user_id,
        serviceKey,
      });
    }
  }

  return approve ? '✅ Одобрено' : '❌ Отклонено';
}

async function notifyPlaceOwnersOfNewReview({ placeId, placeName, reviewAuthorId, serviceKey }) {
  const ownersRes = await fetch(
    `${SUPABASE_URL}/rest/v1/place_owners?place_id=eq.${placeId}&select=user_id`,
    { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
  );
  if (!ownersRes.ok) return;
  const owners = await ownersRes.json();

  for (const owner of owners) {
    if (owner.user_id === reviewAuthorId) continue; // не уведомляем о своём же отзыве на своё место

    const profRes = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${owner.user_id}&select=preferred_language`,
      { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
    );
    const profRows = profRes.ok ? await profRes.json() : [];
    const lang = profRows[0]?.preferred_language === 'uz' ? 'uz' : 'ru';
    const title = lang === 'uz' ? 'Sizga yangi sharh keldi' : 'Вам пришёл новый отзыв';
    const body =
      lang === 'uz' ? `«${placeName}» uchun yangi sharh` : `Новый отзыв на «${placeName}»`;
    await insertNotification({ userId: owner.user_id, title, body, serviceKey });
  }
}

/// Одобрение/отклонение нового заведения. При одобрении место становится
/// видно всем (RLS: places_select_approved_or_own) и владелец получает
/// in-app уведомление на своём языке интерфейса.
async function moderatePlace({ id, approve, botToken, serviceKey }) {
  const newStatus = approve ? 'approved' : 'rejected';

  const updateRes = await fetch(
    `${SUPABASE_URL}/rest/v1/places?id=eq.${id}&select=name,created_by,profiles!places_created_by_fkey(preferred_language)`,
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
  if (!updateRes.ok) return null;

  if (approve) {
    const rows = await updateRes.json();
    const updated = Array.isArray(rows) ? rows[0] : null;
    if (updated?.created_by) {
      const placeName = updated.name ?? '';
      const lang = updated.profiles?.preferred_language === 'uz' ? 'uz' : 'ru';
      const title = lang === 'uz' ? 'Muassasangiz qoʻshildi' : 'Ваше заведение добавлено';
      const body =
        lang === 'uz'
          ? `«${placeName}» endi foydalanuvchilarga koʻrinadi`
          : `«${placeName}» теперь виден пользователям`;
      await insertNotification({ userId: updated.created_by, title, body, serviceKey });
    }
  }

  return approve ? '✅ Одобрено' : '❌ Отклонено';
}

async function insertNotification({ userId, title, body, serviceKey }) {
  await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({ user_id: userId, title, body }),
  });
}

async function answerCallback(botToken, callbackQueryId, text) {
  await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ callback_query_id: callbackQueryId, text }),
  });
}
