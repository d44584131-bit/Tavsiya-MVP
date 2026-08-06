// Уведомляет администратора в Telegram о новом заведении, ожидающем
// модерации, со всей информацией для проверки и кнопками
// "Одобрить"/"Отклонить" (нажатия обрабатывает telegram-webhook.js).
// Место не видно другим пользователям, пока не будет одобрено (RLS:
// places_select_approved_or_own — см. schema.sql).
// Требует те же переменные окружения, что и api/notify-review.js.

const SUPABASE_URL = 'https://ktdffwoogvyjbfzteaev.supabase.co';

const CATEGORY_LABELS = {
  restaurant: 'Ресторан',
  cafe: 'Кафе',
  park: 'Парк',
  mall: 'ТЦ',
};

const PRICE_LABELS = {
  budget: 'до 50 000',
  mid: '50–150 тыс',
  mid_high: '150–300 тыс',
  high: '300 тыс+',
};

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

  const { placeId } = req.body ?? {};
  if (!placeId) {
    res.status(400).json({ error: 'placeId is required' });
    return;
  }

  const placeRes = await fetch(
    `${SUPABASE_URL}/rest/v1/places?id=eq.${placeId}&select=id,name,category,description,address,phone,website,price_level,city,profiles!places_created_by_fkey(display_name)`,
    { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
  );
  const rows = await placeRes.json();
  const place = Array.isArray(rows) ? rows[0] : null;
  if (!place) {
    res.status(404).json({ error: 'Place not found' });
    return;
  }

  const ownerName = place.profiles?.display_name ?? 'Гость';

  const lines = [
    '🏢 Новое заведение на модерации',
    `Название: ${place.name}`,
    `Категория: ${CATEGORY_LABELS[place.category] ?? place.category}`,
    `Владелец: ${ownerName}`,
  ];
  if (place.address) lines.push(`Адрес: ${place.address}`);
  if (place.phone) lines.push(`Телефон: ${place.phone}`);
  if (place.website) lines.push(`Сайт: ${place.website}`);
  if (place.price_level) {
    lines.push(`Средний чек: ${PRICE_LABELS[place.price_level] ?? place.price_level}`);
  }
  if (place.description) lines.push('', place.description);
  const text = lines.join('\n');

  await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Одобрить', callback_data: `place_approve:${placeId}` },
            { text: '❌ Отклонить', callback_data: `place_reject:${placeId}` },
          ],
        ],
      },
    }),
  });

  res.status(200).json({ ok: true });
};
