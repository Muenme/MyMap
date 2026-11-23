export type Parsed = { type: string | null; attributes: string[]; radius_m: number };

const TYPE_RULES: Array<[RegExp, string]> = [
  [/туалет|уборн|санузел/i, "TOILET"],
  [/лавк|скамей|скамь/i, "BENCH"],
  [/урн|мусорк/i, "TRASH_BIN"],
  [/фонтан|питьев/i, "DRINKING_WATER"],
  [/пеленальн/i, "CHANGING_TABLE"],
  [/пандус/i, "RAMP"],
];

const ATTR_RULES: Array<[RegExp, string]> = [
  [/пеленальн/i, "BABY_CHANGING"],
  [/бесплатн/i, "FREE"],
  [/(^|[^а-яё])платн/i, "PAID"],
  [/бумаг/i, "HAS_PAPER"],
  [/коляск|инвалид|колесн|пандус/i, "WHEELCHAIR_ACCESS"],
  [/тен[ьи]/i, "IN_SHADE"],
  [/открыт/i, "OPEN_NOW"],
];

const clamp = (n: number) => Math.min(5000, Math.max(100, n));

function parseRadius(text: string): number {
  const km = text.match(/(\d+(?:[.,]\d+)?)\s*км/i);
  if (km) return clamp(Math.round(parseFloat(km[1].replace(",", ".")) * 1000));
  const m = text.match(/(\d+)\s*(?:м|метр)/i);
  if (m) return clamp(parseInt(m[1], 10));
  return /рядом|близко/i.test(text) ? 300 : 500;
}

export function parseByRules(text: string): Parsed {
  const type = TYPE_RULES.find(([re]) => re.test(text))?.[1] ?? null;
  const attributes = ATTR_RULES.filter(([re]) => re.test(text)).map(([, a]) => a);
  return { type, attributes, radius_m: parseRadius(text) };
}