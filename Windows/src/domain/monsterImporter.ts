import { createEmptyStatBlock, slugifyMonsterID, type MonsterTemplate, type NamedAbility, type StatBlock } from "./models.js";

export type MonsterImportErrorCode = "empty" | "noMonstersFound";
const messages: Record<MonsterImportErrorCode, string> = {
  empty: "Der Import ist leer.",
  noMonstersFound: "Keine Monsterdaten erkannt. Unterstützt werden Markdown-Frontmatter, Schlüssel/Wert-Listen und kompakte Textblöcke.",
};

export class MonsterImportError extends Error {
  readonly code: MonsterImportErrorCode;
  constructor(code: MonsterImportErrorCode) {
    super(messages[code]);
    this.name = "MonsterImportError";
    this.code = code;
  }
}

type Values = Record<string, string>;
type SectionKey = "traits" | "actions" | "bonusActions" | "reactions" | "legendaryActions";

export function importMonsters(
  text: string,
  sourceName = "Import",
  now: () => string = () => new Date().toISOString(),
): MonsterTemplate[] {
  const trimmed = text.trim();
  if (!trimmed) throw new MonsterImportError("empty");
  const frontmatter = parseFrontmatterDocument(trimmed, sourceName, now);
  if (frontmatter) return [frontmatter];

  const imported: MonsterTemplate[] = [];
  for (const block of splitIntoBlocks(trimmed)) {
    const monster = parseKeyValueBlock(block, sourceName, now) ?? parseCompactBlock(block, sourceName, now);
    if (monster && !imported.some((existing) => existing.id === monster.id)) imported.push(monster);
  }
  if (imported.length === 0) throw new MonsterImportError("noMonstersFound");
  return imported;
}

function splitIntoBlocks(text: string): string[] {
  return text.replace(/\r\n/g, "\n").split(/\n\s*(?:---|===|###|##)\s*\n|\n\s*\n\s*\n/g).map((part) => part.trim()).filter(Boolean);
}

function parseFrontmatterDocument(text: string, filename: string, now: () => string): MonsterTemplate | null {
  if (!text.startsWith("---")) return null;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return null;
  const values = yamlishDictionary(text.slice(3, end));
  const fallback = filename.replace(/\.(md|txt)$/i, "");
  const monster = buildMonster(values, fallback, filename, now);
  if (!monster) return null;
  const statblock = buildStatBlock(values, text.slice(end + 4));
  monster.statblock = isEmptyStatBlock(statblock) ? null : statblock;
  return monster;
}

function cleanListValue(raw = ""): string {
  let value = raw.trim();
  if (value.startsWith("[") && value.endsWith("]")) value = value.slice(1, -1);
  return value.trim().replace(/^["']|["']$/g, "");
}

function cleanMarkdown(text: string): string {
  return text.replace(/\*\*/g, "").replace(/\*/g, "").replace(/\s+/g, " ").trim();
}

function buildStatBlock(values: Values, body: string): StatBlock {
  const statblock = createEmptyStatBlock();
  statblock.subtitle = cleanListValue(values["untertitel"]);
  statblock.size = cleanListValue(values["größe"]);
  statblock.alignment = cleanListValue(values["gesinnung"]);
  statblock.habitat = cleanListValue(values["habitat"]);
  statblock.speed = cleanListValue(values["bewegungsrate"]);
  statblock.senses = cleanListValue(values["sinne"]);
  statblock.languages = cleanListValue(values["sprachen"]);
  statblock.skills = cleanListValue(values["fertigkeiten"]);
  statblock.resistances = cleanListValue(values["resistenzen"]);
  statblock.immunities = cleanListValue(values["immunitäten"]);
  statblock.vulnerabilities = cleanListValue(values["anfälligkeiten"]);
  statblock.equipment = cleanListValue(values["ausrüstung"]);
  statblock.xp = cleanListValue(values["ep"]);
  statblock.proficiency = cleanListValue(values["üb"]);

  for (const [key, label] of [["stä", "STÄ"], ["ges", "GES"], ["kon", "KON"], ["int", "INT"], ["wei", "WEI"], ["cha", "CHA"]] as const) {
    const score = Number.parseInt(values[key] ?? "", 10);
    if (Number.isFinite(score)) statblock.abilities.push({ label, score, mod: cleanListValue(values[`${key}_mod`]), save: cleanListValue(values[`${key}_rw`]) });
  }
  parseBodySections(body, statblock);
  return statblock;
}

function parseBodySections(body: string, statblock: StatBlock): void {
  const withoutCode = body.replace(/```[\s\S]*?```/g, "");
  let section: SectionKey | null = null;
  let current: NamedAbility | null = null;

  const flush = () => {
    if (section && current) statblock[section].push(current);
    current = null;
  };

  for (const raw of withoutCode.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith("## ")) {
      flush();
      const title = line.slice(3).trim().toLocaleLowerCase("de-DE");
      section = ({ merkmale: "traits", aktionen: "actions", bonusaktionen: "bonusActions", reaktionen: "reactions", "legendäre aktionen": "legendaryActions" } as Record<string, SectionKey>)[title] ?? null;
      continue;
    }
    if (line.startsWith("# ")) { flush(); section = null; continue; }
    if (!section || !line || line === "---" || line.startsWith("|")) continue;
    if (line.startsWith("*") && !line.startsWith("**")) {
      const cleaned = cleanMarkdown(line);
      if (section === "legendaryActions" && !statblock.legendaryIntro && !current) statblock.legendaryIntro = cleaned;
      else if (current) current.text += `${current.text ? "\n" : ""}${cleaned}`;
      continue;
    }
    if (line.startsWith("- ")) {
      if (current) current.text += `\n• ${cleanMarkdown(line.slice(2))}`;
      continue;
    }
    if (/^\d+\.\s/.test(line)) {
      if (current) current.text += `\n${cleanMarkdown(line)}`;
      continue;
    }
    const entry = /^\*\*(.+?):?\*\*:?\s*(.*)$/.exec(line);
    if (entry) {
      const name = cleanMarkdown(entry[1] ?? "");
      const rest = cleanMarkdown(entry[2] ?? "");
      const spellList = /^(je\s+)?(beliebig oft|\d+[\-‑–]?\s?mal täglich.*|\d+\s?×\s?\/?\s?tag)$/i.test(name);
      if (spellList && current) current.text += `\n• ${name}: ${rest}`;
      else { flush(); current = { name, text: rest }; }
      continue;
    }
    if (current) current.text += ` ${cleanMarkdown(line)}`;
  }
  flush();
}

function parseKeyValueBlock(block: string, sourceName: string, now: () => string): MonsterTemplate | null {
  const values = yamlishDictionary(block);
  if (!["name", "rk", "ac", "hp", "tp", "cr", "hg"].some((key) => key in values)) return null;
  return buildMonster(values, null, sourceName, now);
}

function parseCompactBlock(block: string, sourceName: string, now: () => string): MonsterTemplate | null {
  const lines = block.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const name = lines[0];
  if (!name) return null;
  const joined = lines.join(" ");
  const armorClass = firstInt(joined, [/(?:RK|AC|Armor Class)\s*[:=]?\s*(\d+)/i]);
  const hp = hpPair(joined);
  if (armorClass === null && hp.average <= 0) return null;
  const challengeRating = firstString(joined, [/(?:CR|HG|Challenge)\s*[:=]?\s*([0-9]+\/[0-9]+|[0-9]+\+?)/i]) ?? "?";
  const initiativeBonus = firstInt(joined, [/(?:Ini|Initiative|Initiative Bonus)\s*[:=]?\s*([+-]?\d+)/i]) ?? 0;
  const type = firstString(joined, [/(?:Typ|Type)\s*[:=]?\s*([^.;]+)/i]) ?? "";
  return makeMonster(name, armorClass ?? 10, hp.average, hp.dice, challengeRating, initiativeBonus, type, sourceName, "Importiert aus Text", now);
}

function yamlishDictionary(text: string): Values {
  const values: Values = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#") || line.startsWith("---")) continue;
    const match = /^([A-Za-zÄÖÜäöüß_ -]+)\s*[:=]\s*(.*)$/.exec(line);
    if (match) values[(match[1] ?? "").trim().toLocaleLowerCase("de-DE")] = (match[2] ?? "").trim().replace(/^["']|["']$/g, "");
  }
  return values;
}

function buildMonster(values: Values, fallbackName: string | null, sourceName: string, now: () => string): MonsterTemplate | null {
  const name = firstValue(values, ["name", "titel"]) ?? fallbackName;
  if (!name?.trim()) return null;
  const hp = hpPair(firstValue(values, ["tp", "hp", "hit points", "trefferpunkte"]) ?? "");
  if (hp.average <= 0 && values.name === undefined) return null;
  const armorClass = Number.parseInt(firstValue(values, ["rk", "ac", "armor class"]) ?? "10", 10) || 10;
  const challengeRating = firstValue(values, ["hg", "cr", "challenge", "challenge rating"]) ?? "?";
  const initiativeBonus = firstInt(firstValue(values, ["initiative", "ini", "initiativebonus", "initiative bonus"]) ?? "0", [/([+-]?\d+)/]) ?? 0;
  const type = firstValue(values, ["typ", "type", "art"]) ?? "";
  const notes = firstValue(values, ["notizen", "notes", "beschreibung", "description"]) ?? "";
  return makeMonster(name.trim(), armorClass, hp.average, hp.dice, challengeRating, initiativeBonus, type, sourceName, notes, now);
}

function makeMonster(name: string, armorClass: number, average: number, dice: string, challengeRating: string, initiativeBonus: number, type: string, source: string, notes: string, now: () => string): MonsterTemplate {
  return { id: slugifyMonsterID(name), name, armorClass, hpAverage: Math.max(1, average), hpDice: dice || "1d8", challengeRating: challengeRating || "?", initiativeBonus, type, source, notes, importedAt: now(), statblock: null };
}

function firstValue(values: Values, keys: string[]): string | null {
  for (const key of keys) { const value = values[key.toLocaleLowerCase("de-DE")]; if (value) return value; }
  return null;
}

function hpPair(text: string): { average: number; dice: string } {
  const average = firstInt(text, [/(\d+)\s*(?:\(([^)]+)\))?/]) ?? 0;
  const dice = firstString(text, [/\(([^)]*[dDwW][^)]*)\)/, /(\d+\s*[dDwW]\s*\d+\s*(?:[+-]\s*\d+)?)/])?.replace(/[Ww]/g, "d").replace(/ /g, "");
  return { average, dice: dice ?? (average > 0 ? `${Math.max(1, Math.floor(average / 5))}d8` : "1d8") };
}

function firstInt(text: string, patterns: RegExp[]): number | null {
  const value = firstString(text, patterns);
  if (value === null) return null;
  const parsed = Number.parseInt(value.replace("+", ""), 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function firstString(text: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) { const match = pattern.exec(text); const value = match?.[1]?.trim(); if (value) return value; }
  return null;
}

function isEmptyStatBlock(statblock: StatBlock): boolean {
  return statblock.abilities.length === 0 && statblock.traits.length === 0 && statblock.actions.length === 0 && statblock.bonusActions.length === 0 && statblock.reactions.length === 0 && statblock.legendaryActions.length === 0
    && [statblock.subtitle, statblock.size, statblock.alignment, statblock.speed, statblock.senses, statblock.languages, statblock.skills, statblock.resistances, statblock.immunities, statblock.vulnerabilities, statblock.equipment].every((value) => !value);
}
