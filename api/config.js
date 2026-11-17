// Віддає браузеру публічні налаштування (адреса Supabase і публічний anon-ключ — вони не секретні).
export default function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.status(200).json({
    supabaseUrl: (process.env.SUPABASE_URL || "").trim().replace(/\/rest\/v1\/?$/, "").replace(/\/$/, ""),
    supabaseAnonKey: (process.env.SUPABASE_ANON_KEY || "").trim(),
    google: process.env.ENABLE_GOOGLE_AUTH === "true",
  });
}
