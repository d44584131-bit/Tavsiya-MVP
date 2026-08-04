// Vercel serverless-функция: принимает жалобу/предложение из приложения и
// пересылает его администратору личным сообщением от Telegram-бота.
// Требует переменные окружения в настройках проекта на Vercel:
//   TELEGRAM_BOT_TOKEN     — токен бота от @BotFather
//   TELEGRAM_ADMIN_CHAT_ID — chat_id администратора (см. README-инструкцию)
// Токен и chat_id никогда не попадают в код приложения — только сюда.

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

  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_ADMIN_CHAT_ID;
  if (!token || !chatId) {
    res.status(500).json({ error: 'Server is not configured' });
    return;
  }

  const { message, category, userEmail, userName } = req.body ?? {};
  const text = String(message ?? '').trim();
  if (!text) {
    res.status(400).json({ error: 'message is required' });
    return;
  }

  const categoryLabel = { complaint: 'Жалоба', suggestion: 'Предложение' }[category] ?? 'Обращение';
  const lines = [
    `📩 ${categoryLabel} из Tavsiya`,
    userName ? `От: ${userName}` : null,
    userEmail ? `Email: ${userEmail}` : null,
    '',
    text,
  ].filter(Boolean);

  const telegramRes = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text: lines.join('\n') }),
  });

  if (!telegramRes.ok) {
    res.status(502).json({ error: 'Failed to deliver message' });
    return;
  }

  res.status(200).json({ ok: true });
};
