// Серверна функція Vercel: безпечно викликає Claude API.
// Ключ ANTHROPIC_API_KEY зберігається лише на сервері й ніколи не потрапляє в браузер.
export const config = { maxDuration: 60 };

const hits = new Map(); // простий ліміт запитів на користувача (у пам'яті функції)

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { SUPABASE_URL, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY } = process.env;
  if (!ANTHROPIC_API_KEY) return res.status(500).json({ error: "На сервері не налаштовано ANTHROPIC_API_KEY" });
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return res.status(500).json({ error: "На сервері не налаштовано Supabase" });

  // 1. Перевіряємо, що запит від користувача, який увійшов
  const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!token) return res.status(401).json({ error: "Потрібно увійти" });
  let user;
  try {
    const u = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` },
    });
    if (!u.ok) return res.status(401).json({ error: "Сесія недійсна, увійдіть знову" });
    user = await u.json();
  } catch (e) {
    return res.status(502).json({ error: "Не вдалося перевірити вхід" });
  }

  // 2. Ліміт запитів на годину (захист від зловживань і зайвих витрат)
  const now = Date.now();
  const limit = Number(process.env.AI_LIMIT_PER_HOUR || 40);
  const recent = (hits.get(user.id) || []).filter((t) => now - t < 3600e3);
  if (recent.length >= limit) return res.status(429).json({ error: "Забагато запитів. Спробуйте пізніше." });
  recent.push(now);
  hits.set(user.id, recent);

  // 3. Запит до Claude
  const { prompt, tier } = req.body || {};
  if (typeof prompt !== "string" || !prompt.trim() || prompt.length > 40000) {
    return res.status(400).json({ error: "Некоректний запит" });
  }
  const model = tier === "quick"
    ? process.env.ANTHROPIC_MODEL_QUICK || "claude-haiku-5-5"
    : process.env.ANTHROPIC_MODEL || "claude-sonnet-5-5";

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: 8000,
        system: "Ти — помічник сервісу планування подорожей Join. Відповідай лише валідним JSON за схемою з запиту, українською мовою.",
        messages: [{ role: "user", content: prompt }],
      }),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) {
      return res.status(r.status === 429 ? 429 : 502).json({ error: j?.error?.message || "Помилка сервісу Claude" });
    }
    const text = (j.content || []).filter((b) => b.type === "text").map((b) => b.text).join("");
    return res.status(200).json({ text, truncated: j.stop_reason === "max_tokens" });
  } catch (e) {
    return res.status(502).json({ error: "Claude не відповів. Спробуйте ще раз." });
  }
}
