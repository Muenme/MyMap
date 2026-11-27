import { Hono } from "npm:hono@4";
import { createClient } from "npm:@supabase/supabase-js@2";
import type { Context } from "npm:hono@4";
import { parseByRules, type Parsed } from "./parse.ts";

// Функция вызывается по адресу /functions/v1/api/..., поэтому префикс «/api»
const app = new Hono().basePath("/api");

app.use("*", async (c, next) => {
  const t = Date.now();
  await next();
  console.log(JSON.stringify({
    method: c.req.method, path: c.req.path, status: c.res.status, ms: Date.now() - t,
  }));
});

const PROFILES = ["DEFAULT", "WITH_STROLLER", "WITH_DOG", "ELDERLY", "DISABLED"];

//общие функции

function apiError(c: Context, status: number, code: string, message: string, details?: unknown) {
  return c.json({
    error: {
      code,
      message,
      details: details ?? null,
      request_id: `req_${crypto.randomUUID().slice(0, 8)}`,
      timestamp: new Date().toISOString(),
    },
  }, status);
}

// Клиент от имени пользователя: действует RLS
function userClient(authHeader?: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: authHeader ? { Authorization: authHeader } : {} } },
  );
}

// Пустая строка и мусор дают null, а не 0 или NaN
function toNumber(raw: string | undefined): number | null {
  if (raw === undefined || raw.trim() === "") return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

function bearerToken(c: Context): string | null {
  const h = c.req.header("Authorization") ?? "";
  return h.startsWith("Bearer ") ? h.slice(7) : null;
}

// Возвращает id пользователя или null. Токен передаём явно, иначе сессии не будет
async function currentUserId(c: Context): Promise<string | null> {
  const token = bearerToken(c);
  if (!token) return null;
  const supabase = userClient(`Bearer ${token}`);
  const { data: { user } } = await supabase.auth.getUser(token);
  return user?.id ?? null;
}

//health

app.get("/v1/health", (c) =>
  c.json({ status: "ok", time: new Date().toISOString() }));

//points

app.get("/v1/points", async (c) => {
  const lat = toNumber(c.req.query("lat"));
  const lng = toNumber(c.req.query("lng"));
  const rawRadius = c.req.query("radius");
  const radius = rawRadius === undefined ? 500 : toNumber(rawRadius);

  if (lat === null || lat < -90 || lat > 90) {
    return apiError(c, 400, "VALIDATION_ERROR", "Параметр lat обязателен, диапазон -90..90", { field: "lat" });
  }
  if (lng === null || lng < -180 || lng > 180) {
    return apiError(c, 400, "VALIDATION_ERROR", "Параметр lng обязателен, диапазон -180..180", { field: "lng" });
  }
  if (radius === null || radius < 1) {
    return apiError(c, 400, "VALIDATION_ERROR", "Параметр radius должен быть положительным числом", { field: "radius" });
  }
  if (radius > 5000) {
    return apiError(c, 422, "RADIUS_TOO_LARGE", "Параметр radius не может превышать 5000",
      { field: "radius", value: radius, max: 5000 });
  }

  const supabase = userClient(c.req.header("Authorization"));
  const { data, error } = await supabase.rpc("nearby_points", {
    p_lat: lat, p_lng: lng, p_radius_m: Math.round(radius),
  });
  if (error) return apiError(c, 500, "INTERNAL_ERROR", error.message);

  // Приводим поля к формату спецификации
  const items = (data ?? []).map((r: any) => ({
    id: r.point_id,
    type: r.point_type,
    name: r.point_name,
    lat: r.lat,
    lng: r.lng,
    distance_m: Math.round(r.distance_m),
    last_verified_at: r.last_verified_at,
  }));

  return c.json({ data: items, next_cursor: null });
});

//me

app.get("/v1/me", async (c) => {
  const token = bearerToken(c);
  if (!token) return apiError(c, 401, "AUTH_TOKEN_MISSING", "Требуется токен");

  const supabase = userClient(`Bearer ${token}`);
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return apiError(c, 401, "AUTH_TOKEN_INVALID", "Токен недействителен или истёк");
  }

  const { data, error } = await supabase
    .from("users").select("*").eq("id", user.id).maybeSingle();
  if (error) return apiError(c, 500, "INTERNAL_ERROR", error.message);
  if (!data) return apiError(c, 404, "USER_NOT_FOUND", "Профиль не найден");

  return c.json(data);
});

// Заглушка для LLM: возвращает null, пока провайдер не подключён
async function askLlm(_text: string): Promise<Parsed | null> {
  return null;
}

app.post("/v1/search/parse", async (c) => {
  if (!(await currentUserId(c))) {
    return apiError(c, 401, "AUTH_TOKEN_MISSING", "Требуется токен");
  }

  let body: any;
  try { body = await c.req.json(); }
  catch { return apiError(c, 400, "VALIDATION_ERROR", "Невалидный JSON"); }

  const text = typeof body?.text === "string" ? body.text.trim() : "";
  if (text.length === 0 || text.length > 500) {
    return apiError(c, 400, "VALIDATION_ERROR", "Поле text: 1–500 символов", { field: "text" });
  }

  const profile = body?.profile ?? "DEFAULT";
  if (!PROFILES.includes(profile)) {
    return apiError(c, 400, "VALIDATION_ERROR", "Неизвестный profile", { field: "profile", value: profile });
  }

  const llm = await askLlm(text);
  if (llm) {
    return c.json({ intent: "FIND_POINT", ...llm, profile, source: "llm", fallback: false });
  }

  const rules = parseByRules(text);
  const nothingFound = rules.type === null && rules.attributes.length === 0;
  return c.json({
    intent: rules.type ? "FIND_POINT" : null,
    ...rules,
    profile,
    source: "rules",
    fallback: nothingFound,  // true: запрос не распознан, клиент показывает обычный поиск
  });
});

app.notFound((c) => apiError(c, 404, "NOT_FOUND", "Маршрут не найден"));

app.onError((err, c) => {
  console.log(JSON.stringify({ fn: "api", error: String(err) }));
  return apiError(c, 500, "INTERNAL_ERROR", "Внутренняя ошибка сервера");
});

Deno.serve(app.fetch);