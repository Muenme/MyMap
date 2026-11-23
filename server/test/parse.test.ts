import { assertEquals } from "jsr:@std/assert";
import { parseByRules } from "../supabase/functions/api/parse.ts";

Deno.test("туалет с пеленальным: тип и атрибут", () => {
  const r = parseByRules("туалет с пеленальным рядом с парком");
  assertEquals(r.type, "TOILET");
  assertEquals(r.attributes.includes("BABY_CHANGING"), true);
});

Deno.test("«рядом» даёт радиус 300", () => {
  assertEquals(parseByRules("лавка рядом").radius_m, 300);
});

Deno.test("радиус в километрах", () => {
  assertEquals(parseByRules("урна в 1,5 км").radius_m, 1500);
});

Deno.test("радиус ограничивается 5000", () => {
  assertEquals(parseByRules("туалет 9000 м").radius_m, 5000);
});

Deno.test("«бесплатный» не даёт PAID", () => {
  const r = parseByRules("бесплатный туалет");
  assertEquals(r.attributes.includes("PAID"), false);
  assertEquals(r.attributes.includes("FREE"), true);
});

Deno.test("«платный» даёт PAID", () => {
  assertEquals(parseByRules("платный туалет").attributes.includes("PAID"), true);
});

Deno.test("фонтанчик распознаётся как DRINKING_WATER", () => {
  assertEquals(parseByRules("фонтанчик у метро").type, "DRINKING_WATER");
});

Deno.test("нераспознанный запрос даёт type = null", () => {
  assertEquals(parseByRules("привет как дела").type, null);
});

Deno.test("коляска даёт WHEELCHAIR_ACCESS", () => {
  assertEquals(parseByRules("вход с коляской").attributes.includes("WHEELCHAIR_ACCESS"), true);
});