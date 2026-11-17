# Join — плануйте подорожі разом

Сайт для спільного планування подорожей: готелі, логістика, план на кожен день, ресторани, магазини й поради. Користувачі входять через email, створюють подорожі й запрошують друзів посиланням.

## З чого складається

| Файл | Що робить |
|---|---|
| `index.html` | Увесь сайт: головна сторінка (лендинг), вхід і сам застосунок |
| `api/ai.js` | Серверна функція: безпечно звертається до Claude (ключ не видно в браузері) |
| `api/config.js` | Передає сайту адресу бази даних |
| `supabase/schema.sql` | Таблиці бази даних і правила доступу |

Сервіси, які знадобляться (усі мають безкоштовний старт):
- **GitHub**: тут зберігається код.
- **Supabase**: база даних і вхід користувачів.
- **Vercel**: хостинг сайту.
- **Anthropic Console**: ключ для Claude (оплата за використання).

Якщо відкрити `index.html` просто з комп'ютера, сайт запуститься в **демо-режимі**: усе працює, крім входу, спільного доступу та AI-генерації.

---

## Запуск крок за кроком (≈30–40 хвилин)

### 1. Завантажте код на GitHub
1. Зареєструйтесь на https://github.com.
2. Натисніть **New repository**, назвіть його `join` і створіть.
3. На сторінці репозиторію натисніть **uploading an existing file** і перетягніть **вміст** розпакованої папки: `index.html`, `package.json`, `README.md` і папки `api` та `supabase`. Потім натисніть **Commit changes**.

### 2. Створіть базу даних у Supabase
1. Зареєструйтесь на https://supabase.com і натисніть **New project**. Регіон оберіть **Central EU (Frankfurt)**, пароль бази даних збережіть.
2. Коли проєкт створиться, відкрийте **SQL Editor → New query**, вставте весь текст із `supabase/schema.sql` і натисніть **Run**. Має з'явитися «Success».
3. Відкрийте **Project Settings → API** (або **Data API**) і скопіюйте:
   - **Project URL**: це `SUPABASE_URL`;
   - **anon public key** (у нових проєктах він може називатися **Publishable key**): це `SUPABASE_ANON_KEY`.

### 3. Отримайте ключ Claude
1. Зареєструйтесь на https://console.anthropic.com.
2. У **Billing** поповніть баланс (для старту вистачить 5–10 $) і встановіть ліміт витрат.
3. У **API Keys** натисніть **Create Key** і скопіюйте ключ. Це `ANTHROPIC_API_KEY`. Нікому його не показуйте.

### 4. Опублікуйте сайт на Vercel
1. Зайдіть на https://vercel.com через акаунт GitHub.
2. Натисніть **Add New → Project** і оберіть репозиторій `join`. Framework: **Other**, нічого не змінюйте.
3. Розгорніть **Environment Variables** і додайте:

   | Назва | Значення |
   |---|---|
   | `SUPABASE_URL` | з кроку 2 |
   | `SUPABASE_ANON_KEY` | з кроку 2 |
   | `ANTHROPIC_API_KEY` | з кроку 3 |

4. Натисніть **Deploy**. Через хвилину сайт буде доступний за адресою на кшталт `join-xxxx.vercel.app`.

### 5. Підключіть вхід через email
1. У Supabase відкрийте **Authentication → URL Configuration**.
2. У **Site URL** вкажіть адресу сайту (наприклад, `https://join-xxxx.vercel.app`, а після підключення домену — ваш домен).
3. У **Redirect URLs** додайте ту саму адресу з `/**` у кінці, наприклад `https://join-xxxx.vercel.app/**`.
4. Перевірте: відкрийте сайт, введіть email і перейдіть за посиланням із листа.

> ⚠️ Вбудована пошта Supabase надсилає лише кілька листів на годину, і цього вистачає тільки для тестів. Для реальних користувачів підключіть безкоштовний SMTP (наприклад, https://resend.com) в **Authentication → Emails → SMTP Settings**.

### 6. Власний домен
1. Перевірте, чи вільні домени, і купіть один (Namecheap, GoDaddy, Cloudflare або український реєстратор для `.com.ua`). Варіанти: `jointrip.app`, `join.travel`, `gojoin.app`, `jointrips.com`, `join-trip.com.ua`.
2. У Vercel відкрийте **Project → Settings → Domains → Add** і виконайте інструкцію щодо DNS.
3. Оновіть **Site URL** і **Redirect URLs** у Supabase (крок 5) на новий домен.

### 7. (Необов'язково) Вхід через Google
1. У Google Cloud Console створіть OAuth Client (тип Web) за інструкцією Supabase: **Authentication → Providers → Google**.
2. Увімкніть Google у Supabase й вставте Client ID та Secret.
3. У Vercel додайте змінну `ENABLE_GOOGLE_AUTH` = `true` і зробіть **Redeploy**.

---

## Додаткові налаштування (Vercel → Environment Variables)

| Змінна | За замовчуванням | Навіщо |
|---|---|---|
| `ANTHROPIC_MODEL` | `claude-sonnet-5-5` | Модель для планів і підбірок |
| `ANTHROPIC_MODEL_QUICK` | `claude-haiku-5-5` | Модель для швидких підказок (поради міст) |
| `AI_LIMIT_PER_HOUR` | `40` | Скільки AI-запитів на годину може зробити один користувач |

## Важливо знати
- **Дані про готелі, ресторани й ціни** AI бере з власних знань, тому вони орієнтовні. Кнопки ведуть на Booking, Google Maps, Google Flights, Укрзалізницю та FlixBus з уже підставленими даними. Щоб показувати живі ціни Booking, потрібне партнерство з Booking (Affiliate Partner Programme / Demand API). Це можна додати пізніше.
- **Витрати на AI** залежать від кількості користувачів. Відстежуйте їх в Anthropic Console і встановіть місячний ліміт.
- **Оновлення сайту**: змініть файли в GitHub, і Vercel оновить сайт автоматично.
