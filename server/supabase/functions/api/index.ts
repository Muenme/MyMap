import { Hono } from "npm:hono@4";
import { createClient } from "npm:@supabase/supabase-js@2";

// Путь функции в URL — /functions/v1/api, поэтому базовый префикс «/api»
const app = new Hono().basePath("/api");

function apiError(c: any, status: number, code: string, message: string, details?: unknown) {
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

// Клиент, действующий от имени пользователя: RLS работает
function userClient(authHeader: string | undefined) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: authHeader ? { Authorization: authHeader } : {} } },
  );
}

app.get("/v1/health", (c) =>
  c.json({ status: "ok", time: new Date().toISOString() }));

app.get("/v1/points", async (c) => {
  const lat = Number(c.req.query("lat"));
  const lng = Number(c.req.query("lng"));
  const radius = Number(c.req.query("radius") ?? 500);

  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    return apiError(c, 400, "VALIDATION_ERROR", "Параметр lat обязателен, диапазон -90..90", { field: "lat" });
  }
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    return apiError(c, 400, "VALIDATION_ERROR", "Параметр lng обязателен, диапазон -180..180", { field: "lng" });
  }
  if (radius > 5000) {
    return apiError(c, 422, "RADIUS_TOO_LARGE", "Параметр radius не может превышать 5000", { field: "radius", value: radius, max: 5000 });
  }

  const supabase = userClient(c.req.header("Authorization"));
  const { data, error } = await supabase.rpc("nearby_points", {
    p_lat: lat, p_lng: lng, p_radius_m: radius,
  });
  if (error) return apiError(c, 500, "INTERNAL_ERROR", error.message);

  return c.json({ data, next_cursor: null });
});

app.get("/v1/me", async (c) => {
  const supabase = userClient(c.req.header("Authorization"));
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiError(c, 401, "AUTH_TOKEN_MISSING", "Требуется токен");

  const { data, error } = await supabase.from("users").select("*").eq("id", user.id).single();
  if (error) return apiError(c, 500, "INTERNAL_ERROR", error.message);
  return c.json(data);
});

Deno.serve(app.fetch);