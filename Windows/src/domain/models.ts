export const CURRENT_SCHEMA_VERSION = 1;

export type CreatureKind = "player" | "monster";
export type HPMode = "average" | "roll";
export type StatusPolarity = "good" | "bad";

export const PLANNER_THEMES = [
  { id: "ember", name: "Bernstein" },
  { id: "obsidian", name: "Obsidian" },
  { id: "parchment", name: "Pergament" },
  { id: "pure", name: "Weiß" },
  { id: "midnight", name: "Mitternacht" },
] as const;

export interface StatusDefinition {
  id: string;
  label: string;
  short: string;
  category: string;
  priority: number;
  polarity: StatusPolarity;
  description: string;
  effects: string[];
  isOfficial: boolean;
}

export interface StatusInstance {
  id: string;
  duration: number | null;
  note: string;
}

export interface Creature {
  id: string;
  name: string;
  kind: CreatureKind;
  armorClass: number;
  hitPoints: number;
  maxHitPoints: number;
  temporaryHitPoints: number;
  initiativeBonus: number;
  currentInitiative: number | null;
  tieBreak: number | null;
  deathSaveSuccesses: number | null;
  deathSaveFailures: number | null;
  statuses: StatusInstance[];
  notes: string;
  sourceMonsterID: string | null;
}

export interface NamedAbility { name: string; text: string }
export interface AbilityValue { label: string; score: number; mod: string; save: string }

export interface StatBlock {
  subtitle: string;
  size: string;
  alignment: string;
  habitat: string;
  speed: string;
  senses: string;
  languages: string;
  skills: string;
  resistances: string;
  immunities: string;
  vulnerabilities: string;
  equipment: string;
  xp: string;
  proficiency: string;
  abilities: AbilityValue[];
  traits: NamedAbility[];
  actions: NamedAbility[];
  bonusActions: NamedAbility[];
  reactions: NamedAbility[];
  legendaryActions: NamedAbility[];
  legendaryIntro: string;
}

export interface MonsterTemplate {
  id: string;
  name: string;
  armorClass: number;
  hpAverage: number;
  hpDice: string;
  challengeRating: string;
  initiativeBonus: number;
  type: string;
  source: string;
  notes: string;
  importedAt: string | null;
  statblock: StatBlock | null;
}

export interface LogEntry { id: string; date: string; message: string; kind: string }

export interface Encounter {
  id: string;
  name: string;
  savedAt: string;
  round: number;
  activeID: string | null;
  players: Creature[];
  monsters: Creature[];
  log: LogEntry[];
}

export interface PlannerState {
  schemaVersion: number;
  players: Creature[];
  monsters: Creature[];
  round: number;
  activeID: string | null;
  monsterDatabase: MonsterTemplate[];
  encounters: Encounter[];
  statuses: StatusDefinition[];
  hpMode: HPMode;
  keepDatabaseOpen: boolean;
  selectedTheme: string;
  log: LogEntry[];
}

const official = (
  id: string,
  label: string,
  short: string,
  category: string,
  priority: number,
  polarity: StatusPolarity,
  description: string,
  effects: string[],
): StatusDefinition => ({ id, label, short, category, priority, polarity, description, effects, isOfficial: true });

export const OFFICIAL_STATUSES: readonly StatusDefinition[] = [
  official("concentration", "Konzentration", "Konz", "concentration", 10, "good", "Ein Zauber oder Effekt wird aktiv aufrechterhalten.", ["Bei Schaden: Konstitutionsrettungswurf, SG 10 oder halber erlittener Schaden, je nachdem was höher ist.", "Endet, wenn du einen weiteren Konzentrationseffekt beginnst.", "Endet, wenn du kampfunfähig wirst oder stirbst."]),
  official("dodging", "Ausweichend", "Ausw", "good", 5, "good", "Die Kreatur nutzt die Ausweichen-Aktion.", ["Bis zum Beginn ihres nächsten Zugs sind Angriffswürfe gegen sie im Nachteil, sofern sie den Angreifer sehen kann.", "Geschicklichkeitsrettungswürfe sind im Vorteil.", "Der Vorteil endet, wenn sie kampfunfähig wird oder ihre Bewegungsrate 0 beträgt."]),
  official("resistant", "Resistent", "Res", "physical", 2, "good", "Resistenz gegen eine Schadensart.", ["Schaden der angegebenen Art wird halbiert; pro Schadensinstanz nur einmal anwenden."]),
  official("immune", "Immun", "Imm", "physical", 3, "good", "Immunität gegen eine Schadensart oder einen Zustand.", ["Die angegebene Schadensart oder der angegebene Zustand beeinflusst die Kreatur nicht."]),
  official("blessed", "Gesegnet", "Seg", "good", 2, "good", "Hilfreicher Bonus, z. B. durch den Zauber Segnen.", ["Typische Erinnerung: +1W4 auf Angriffswürfe und Rettungswürfe, solange der Effekt gilt."]),
  official("inspired", "Inspiriert", "Ins", "good", 1, "good", "Hat Inspiration, Bardeninspiration oder einen vergleichbaren Bonus.", ["Als Marker für einen später einsetzbaren Bonus gedacht; genaue Wirkung hängt von der Quelle ab."]),
  official("stable", "Stabil", "Stab", "good", 2, "good", "Die Kreatur hat 0 Trefferpunkte, muss aber keine Todesrettungswürfe ablegen.", ["Marker für 0 HP ohne aktive Todesrettungswürfe.", "Weitere Treffer/Heilung wie gewohnt nach Regelquelle behandeln."]),
  official("hidden", "Versteckt", "Vers", "movement", 3, "good", "Die Kreatur hat sich erfolgreich versteckt.", ["Nach erfolgreichem Verstecken ist sie unsichtbar, solange sie versteckt bleibt.", "Das Würfelergebnis dient als SG, um sie mit Wahrnehmung aufzuspüren.", "Endet u. a., wenn sie lauter als ein Flüstern ist, aufgespürt wird, angreift oder einen Zauber mit Verbalkomponente wirkt."]),
  official("invisible", "Unsichtbar", "Uns", "movement", 4, "good", "Die Kreatur ist nicht sichtbar, außer ein Effekt erlaubt es, sie trotzdem zu sehen.", ["Bei Initiative im Vorteil, wenn sie beim Auswürfeln unsichtbar ist.", "Sie ist vor Effekten geschützt, die Sicht erfordern, sofern der Wirker sie nicht trotzdem sehen kann.", "Angriffe gegen sie sind im Nachteil; ihre Angriffswürfe sind im Vorteil, außer das Ziel kann sie sehen."]),
  official("bloodied", "Blutig", "Blut", "physical", 1, "bad", "Die Kreatur hat höchstens die Hälfte ihrer Trefferpunkte.", ["Reiner Zustandsmarker für Übersicht, Blutrausch, Phasenwechsel oder Monsterfähigkeiten."]),
  official("vulnerable", "Anfällig", "Anf", "physical", 3, "bad", "Anfälligkeit gegen eine Schadensart.", ["Schaden der angegebenen Art wird verdoppelt; pro Schadensinstanz nur einmal anwenden."]),
  official("surprised", "Überrascht", "Über", "mental", 4, "bad", "Die Kreatur hat nicht mit dem Kampf gerechnet.", ["Beim Initiativewurf im Nachteil.", "Danach als Erinnerung entfernen, falls der Effekt nicht länger relevant ist."]),
  official("stunned", "Betäubt", "Bet", "critical", 8, "bad", "Schwerer Zustand; die Kreatur ist handlungsunfähig und leichter zu treffen.", ["Hat den Zustand Kampfunfähig.", "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.", "Angriffswürfe gegen die Kreatur sind im Vorteil."]),
  official("unconscious", "Bewusstlos", "Bew", "critical", 9, "bad", "Die Kreatur nimmt ihre Umgebung nicht wahr und ist wehrlos.", ["Hat Kampfunfähig und Liegend und lässt Gehaltenes fallen; nach Ende bleibt sie liegend.", "Bewegungsrate 0 und kann nicht erhöht werden.", "Angriffswürfe gegen sie sind im Vorteil.", "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.", "Treffer aus bis zu 1,5 m Entfernung sind kritische Treffer.", "Sie nimmt die Umgebung nicht wahr."]),
  official("paralyzed", "Gelähmt", "Gel", "critical", 7, "bad", "Die Kreatur ist bewegungsunfähig und Treffer aus nächster Nähe sind besonders gefährlich.", ["Hat den Zustand Kampfunfähig.", "Bewegungsrate 0 und kann nicht erhöht werden.", "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.", "Angriffswürfe gegen sie sind im Vorteil.", "Treffer aus bis zu 1,5 m Entfernung sind kritische Treffer."]),
  official("petrified", "Versteinert", "Verst", "incapacitated", 6, "bad", "Die Kreatur ist in eine unbelebte Substanz verwandelt.", ["Mit nichtmagischer Ausrüstung in eine feste unbelebte Substanz verwandelt; Gewicht verzehnfacht, Alterung stoppt.", "Hat den Zustand Kampfunfähig.", "Bewegungsrate 0 und kann nicht erhöht werden.", "Angriffswürfe gegen sie sind im Vorteil.", "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.", "Resistenz gegen alle Schadensarten.", "Immun gegen den Zustand Vergiftet."]),
  official("incapacitated", "Kampfunfähig", "Kamp", "incapacitated", 6, "bad", "Die Kreatur kann praktisch nicht handeln.", ["Keine Aktionen, Bonusaktionen oder Reaktionen.", "Konzentration ist unterbrochen.", "Kann nicht sprechen.", "Bei Initiative im Nachteil, wenn sie beim Auswürfeln kampfunfähig ist."]),
  official("restrained", "Festgesetzt", "Fest", "movement", 5, "bad", "Die Kreatur ist stark in ihrer Bewegung eingeschränkt.", ["Bewegungsrate 0 und kann nicht erhöht werden.", "Angriffswürfe gegen sie sind im Vorteil; ihre eigenen Angriffswürfe sind im Nachteil.", "Geschicklichkeitsrettungswürfe sind im Nachteil."]),
  official("blinded", "Blind", "Blind", "physical", 5, "bad", "Die Kreatur kann nicht sehen.", ["Attributswürfe, die Sicht erfordern, scheitern automatisch.", "Angriffswürfe gegen sie sind im Vorteil; ihre eigenen Angriffswürfe sind im Nachteil."]),
  official("frightened", "Verängstigt", "Ver", "mental", 4, "bad", "Die Kreatur fürchtet eine Quelle.", ["Attributs- und Angriffswürfe sind im Nachteil, solange die Quelle der Furcht in Sichtlinie ist.", "Sie kann sich nicht willentlich auf die Quelle der Furcht zubewegen."]),
  official("poisoned", "Vergiftet", "Verg", "physical", 3, "bad", "Gift oder ein ähnlicher Effekt beeinträchtigt die Kreatur.", ["Angriffs- und Attributswürfe sind im Nachteil."]),
  official("exhaustion", "Erschöpft", "Ersch", "physical", 3, "bad", "Kumulativer Zustand mit Erschöpfungsstufen.", ["Jedes Erleiden erhöht die Erschöpfungsstufe; bei 6 Stufen stirbt die Kreatur.", "W20-Prüfungen werden um das Doppelte der Erschöpfungsstufe verringert.", "Bewegungsrate sinkt um 1,5 m pro Erschöpfungsstufe.", "Eine lange Rast entfernt eine Stufe; bei 0 Stufen endet der Zustand."]),
  official("deafened", "Taub", "Taub", "physical", 3, "bad", "Die Kreatur kann nicht hören.", ["Attributswürfe, die Hörvermögen erfordern, scheitern automatisch."]),
  official("prone", "Liegend", "Lieg", "movement", 3, "bad", "Die Kreatur liegt am Boden.", ["Sie kann nur kriechen oder die Hälfte ihrer Bewegungsrate ausgeben, um aufzustehen; bei Bewegungsrate 0 kann sie nicht aufstehen.", "Ihre Angriffswürfe sind im Nachteil.", "Angriffe gegen sie sind im Vorteil, wenn der Angreifer höchstens 1,5 m entfernt ist; sonst im Nachteil."]),
  official("grappled", "Gepackt", "Gep", "movement", 2, "bad", "Die Kreatur wird festgehalten.", ["Bewegungsrate 0 und kann nicht erhöht werden.", "Angriffe gegen Ziele außer der packenden Kreatur sind im Nachteil.", "Die packende Kreatur kann sie ziehen oder tragen; das kostet meist doppelte Bewegung."]),
  official("charmed", "Bezaubert", "Bez", "mental", 2, "bad", "Die Kreatur ist magisch oder anderweitig eingenommen.", ["Sie kann den Zauberwirker nicht angreifen oder als Ziel schädigender Fähigkeiten und magischer Effekte wählen.", "Der Zauberwirker hat Vorteil bei Attributswürfen für soziale Interaktionen mit ihr."]),
  official("dead", "Tot", "Tot", "critical", 10, "bad", "Die Kreatur ist tot.", ["Keine Trefferpunkte und keine Heilung möglich, bis ein passender Wiederbelebungseffekt greift.", "Als Encounter-Marker gedacht; ersetzt keine detaillierte Todes-/Wiederbelebungsregel."]),
] as const;

export class StateFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "StateFormatError";
  }
}

export function createDefaultState(now: () => string = () => new Date().toISOString()): PlannerState {
  return {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    players: [], monsters: [], round: 1, activeID: null, monsterDatabase: [], encounters: [],
    statuses: structuredClone([...OFFICIAL_STATUSES]), hpMode: "average", keepDatabaseOpen: true,
    selectedTheme: "ember",
    log: [{ id: crypto.randomUUID(), date: now(), message: "App gestartet", kind: "system" }],
  };
}

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const iso8601Pattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;

function record(value: unknown, path: string): Record<string, unknown> {
  if (!isRecord(value)) throw new StateFormatError(`${path} ist kein Objekt.`);
  return value;
}

function array(value: unknown, path: string): unknown[] {
  if (!Array.isArray(value)) throw new StateFormatError(`${path} fehlt oder ist ungültig.`);
  return value;
}

function string(value: unknown, path: string): string {
  if (typeof value !== "string") throw new StateFormatError(`${path} fehlt oder ist ungültig.`);
  return value;
}

function number(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new StateFormatError(`${path} fehlt oder ist ungültig.`);
  return value;
}

function boolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") throw new StateFormatError(`${path} fehlt oder ist ungültig.`);
  return value;
}

function optionalString(value: unknown, path: string): string | null {
  return value === undefined || value === null ? null : string(value, path);
}

function optionalNumber(value: unknown, path: string): number | null {
  return value === undefined || value === null ? null : number(value, path);
}

function uuid(value: unknown, path: string): string {
  const result = string(value, path);
  if (!uuidPattern.test(result)) throw new StateFormatError(`${path} ist keine gültige UUID.`);
  return result.toUpperCase();
}

function optionalUUID(value: unknown, path: string): string | null {
  return value === undefined || value === null ? null : uuid(value, path);
}

function date(value: unknown, path: string): string {
  const result = string(value, path);
  if (!iso8601Pattern.test(result) || !Number.isFinite(Date.parse(result))) throw new StateFormatError(`${path} ist kein gültiges ISO-8601-Datum.`);
  return result;
}

function decodeStatusInstance(value: unknown, path: string): StatusInstance {
  const raw = record(value, path);
  return { id: string(raw.id, `${path}.id`), duration: optionalNumber(raw.duration, `${path}.duration`), note: string(raw.note, `${path}.note`) };
}

function decodeCreature(value: unknown, path: string): Creature {
  const raw = record(value, path);
  if (raw.kind !== "player" && raw.kind !== "monster") throw new StateFormatError(`${path}.kind ist ungültig.`);
  return {
    id: uuid(raw.id, `${path}.id`), name: string(raw.name, `${path}.name`), kind: raw.kind,
    armorClass: number(raw.armorClass, `${path}.armorClass`), hitPoints: number(raw.hitPoints, `${path}.hitPoints`),
    maxHitPoints: number(raw.maxHitPoints, `${path}.maxHitPoints`), temporaryHitPoints: number(raw.temporaryHitPoints, `${path}.temporaryHitPoints`),
    initiativeBonus: number(raw.initiativeBonus, `${path}.initiativeBonus`), currentInitiative: optionalNumber(raw.currentInitiative, `${path}.currentInitiative`),
    tieBreak: optionalNumber(raw.tieBreak, `${path}.tieBreak`), deathSaveSuccesses: optionalNumber(raw.deathSaveSuccesses, `${path}.deathSaveSuccesses`),
    deathSaveFailures: optionalNumber(raw.deathSaveFailures, `${path}.deathSaveFailures`),
    statuses: array(raw.statuses, `${path}.statuses`).map((entry, index) => decodeStatusInstance(entry, `${path}.statuses[${index}]`)),
    notes: string(raw.notes, `${path}.notes`), sourceMonsterID: optionalString(raw.sourceMonsterID, `${path}.sourceMonsterID`),
  };
}

function decodeNamedAbility(value: unknown, path: string): NamedAbility {
  const raw = record(value, path);
  return { name: string(raw.name, `${path}.name`), text: string(raw.text, `${path}.text`) };
}

function decodeAbilityValue(value: unknown, path: string): AbilityValue {
  const raw = record(value, path);
  return { label: string(raw.label, `${path}.label`), score: number(raw.score, `${path}.score`), mod: string(raw.mod, `${path}.mod`), save: string(raw.save, `${path}.save`) };
}

function decodeStatBlock(value: unknown, path: string): StatBlock {
  const raw = record(value, path);
  const named = (key: keyof Pick<StatBlock, "traits" | "actions" | "bonusActions" | "reactions" | "legendaryActions">) =>
    array(raw[key], `${path}.${key}`).map((entry, index) => decodeNamedAbility(entry, `${path}.${key}[${index}]`));
  return {
    subtitle: string(raw.subtitle, `${path}.subtitle`), size: string(raw.size, `${path}.size`), alignment: string(raw.alignment, `${path}.alignment`),
    habitat: string(raw.habitat, `${path}.habitat`), speed: string(raw.speed, `${path}.speed`), senses: string(raw.senses, `${path}.senses`),
    languages: string(raw.languages, `${path}.languages`), skills: string(raw.skills, `${path}.skills`), resistances: string(raw.resistances, `${path}.resistances`),
    immunities: string(raw.immunities, `${path}.immunities`), vulnerabilities: string(raw.vulnerabilities, `${path}.vulnerabilities`),
    equipment: string(raw.equipment, `${path}.equipment`), xp: string(raw.xp, `${path}.xp`), proficiency: string(raw.proficiency, `${path}.proficiency`),
    abilities: array(raw.abilities, `${path}.abilities`).map((entry, index) => decodeAbilityValue(entry, `${path}.abilities[${index}]`)),
    traits: named("traits"), actions: named("actions"), bonusActions: named("bonusActions"), reactions: named("reactions"),
    legendaryActions: named("legendaryActions"), legendaryIntro: string(raw.legendaryIntro, `${path}.legendaryIntro`),
  };
}

function decodeMonsterTemplate(value: unknown, path: string): MonsterTemplate {
  const raw = record(value, path);
  return {
    id: string(raw.id, `${path}.id`), name: string(raw.name, `${path}.name`), armorClass: number(raw.armorClass, `${path}.armorClass`),
    hpAverage: number(raw.hpAverage, `${path}.hpAverage`), hpDice: string(raw.hpDice, `${path}.hpDice`), challengeRating: string(raw.challengeRating, `${path}.challengeRating`),
    initiativeBonus: number(raw.initiativeBonus, `${path}.initiativeBonus`), type: string(raw.type, `${path}.type`), source: string(raw.source, `${path}.source`),
    notes: string(raw.notes, `${path}.notes`), importedAt: raw.importedAt === undefined || raw.importedAt === null ? null : date(raw.importedAt, `${path}.importedAt`),
    statblock: raw.statblock === undefined || raw.statblock === null ? null : decodeStatBlock(raw.statblock, `${path}.statblock`),
  };
}

function decodeLogEntry(value: unknown, path: string): LogEntry {
  const raw = record(value, path);
  return { id: uuid(raw.id, `${path}.id`), date: date(raw.date, `${path}.date`), message: string(raw.message, `${path}.message`), kind: string(raw.kind, `${path}.kind`) };
}

function decodeEncounter(value: unknown, path: string): Encounter {
  const raw = record(value, path);
  return {
    id: uuid(raw.id, `${path}.id`), name: string(raw.name, `${path}.name`), savedAt: date(raw.savedAt, `${path}.savedAt`), round: number(raw.round, `${path}.round`),
    activeID: optionalUUID(raw.activeID, `${path}.activeID`),
    players: array(raw.players, `${path}.players`).map((entry, index) => decodeCreature(entry, `${path}.players[${index}]`)),
    monsters: array(raw.monsters, `${path}.monsters`).map((entry, index) => decodeCreature(entry, `${path}.monsters[${index}]`)),
    log: array(raw.log, `${path}.log`).map((entry, index) => decodeLogEntry(entry, `${path}.log[${index}]`)),
  };
}

function decodeStatusDefinition(value: unknown, path: string): StatusDefinition {
  const raw = record(value, path);
  if (raw.polarity !== "good" && raw.polarity !== "bad") throw new StateFormatError(`${path}.polarity ist ungültig.`);
  return {
    id: string(raw.id, `${path}.id`), label: string(raw.label, `${path}.label`), short: string(raw.short, `${path}.short`),
    category: string(raw.category, `${path}.category`), priority: number(raw.priority, `${path}.priority`), polarity: raw.polarity,
    description: string(raw.description, `${path}.description`), effects: array(raw.effects, `${path}.effects`).map((effect, index) => string(effect, `${path}.effects[${index}]`)),
    isOfficial: boolean(raw.isOfficial, `${path}.isOfficial`),
  };
}

export function decodePlannerState(text: string): PlannerState {
  let raw: unknown;
  try { raw = JSON.parse(text); } catch { throw new StateFormatError("Die Zustandsdatei enthält ungültiges JSON."); }
  const root = record(raw, "PlannerState");
  const schemaVersion: unknown = root.schemaVersion === undefined ? 1 : root.schemaVersion;
  if (typeof schemaVersion !== "number" || !Number.isInteger(schemaVersion) || schemaVersion < 1 || schemaVersion > CURRENT_SCHEMA_VERSION) {
    throw new StateFormatError(`Nicht unterstützte Schema-Version: ${String(schemaVersion)}`);
  }
  if (root.hpMode !== "average" && root.hpMode !== "roll") throw new StateFormatError("Ungültiger HP-Modus.");
  return {
    schemaVersion: schemaVersion as number,
    players: array(root.players, "players").map((entry, index) => decodeCreature(entry, `players[${index}]`)),
    monsters: array(root.monsters, "monsters").map((entry, index) => decodeCreature(entry, `monsters[${index}]`)),
    round: number(root.round, "round"), activeID: optionalUUID(root.activeID, "activeID"),
    monsterDatabase: array(root.monsterDatabase, "monsterDatabase").map((entry, index) => decodeMonsterTemplate(entry, `monsterDatabase[${index}]`)),
    encounters: array(root.encounters, "encounters").map((entry, index) => decodeEncounter(entry, `encounters[${index}]`)),
    statuses: array(root.statuses, "statuses").map((entry, index) => decodeStatusDefinition(entry, `statuses[${index}]`)),
    hpMode: root.hpMode, keepDatabaseOpen: boolean(root.keepDatabaseOpen, "keepDatabaseOpen"),
    selectedTheme: string(root.selectedTheme, "selectedTheme"),
    log: array(root.log, "log").map((entry, index) => decodeLogEntry(entry, `log[${index}]`)),
  };
}

export function encodePlannerState(state: PlannerState): string {
  return JSON.stringify({ ...state, schemaVersion: CURRENT_SCHEMA_VERSION });
}

export function initiativeList(state: PlannerState): Creature[] {
  return [...state.players, ...state.monsters]
    .filter((creature) => creature.currentInitiative !== null && creature.currentInitiative !== undefined)
    .sort((left, right) => {
      if (left.currentInitiative !== right.currentInitiative) return (right.currentInitiative ?? -999) - (left.currentInitiative ?? -999);
      if ((left.tieBreak ?? 0) !== (right.tieBreak ?? 0)) return (left.tieBreak ?? 0) - (right.tieBreak ?? 0);
      if (left.initiativeBonus !== right.initiativeBonus) return right.initiativeBonus - left.initiativeBonus;
      return left.name.localeCompare(right.name, "de-DE", { numeric: true, sensitivity: "base" });
    });
}

export function normalizePlannerState(input: PlannerState): PlannerState {
  const state = structuredClone(input);
  state.schemaVersion = CURRENT_SCHEMA_VERSION;
  if (state.selectedTheme === "glass" || state.selectedTheme === "white") state.selectedTheme = state.selectedTheme === "white" ? "pure" : "ember";
  state.monsterDatabase.sort((left, right) => left.name.localeCompare(right.name, "de-DE", { numeric: true, sensitivity: "base" }));
  const officialIDs = new Set(OFFICIAL_STATUSES.map((status) => status.id));
  const custom = state.statuses.filter((status) => !status.isOfficial && !officialIDs.has(status.id));
  state.statuses = [...structuredClone(OFFICIAL_STATUSES), ...custom];
  const list = initiativeList(state);
  if (list.length === 0) state.activeID = null;
  else if (!state.activeID || !list.some((creature) => creature.id === state.activeID)) state.activeID = list[0]?.id ?? null;
  if (state.players.length + state.monsters.length === 0) state.round = 1;
  return state;
}

export function createCreature(input: Partial<Creature> & Pick<Creature, "name" | "kind">): Creature {
  const hitPoints = Math.max(0, input.hitPoints ?? 0);
  return {
    id: input.id ?? crypto.randomUUID(), name: input.name, kind: input.kind,
    armorClass: input.armorClass ?? 10, hitPoints,
    maxHitPoints: Math.max(0, input.maxHitPoints ?? hitPoints), temporaryHitPoints: Math.max(0, input.temporaryHitPoints ?? 0),
    initiativeBonus: input.initiativeBonus ?? 0, currentInitiative: input.currentInitiative ?? null,
    tieBreak: input.tieBreak ?? null, deathSaveSuccesses: input.deathSaveSuccesses ?? null,
    deathSaveFailures: input.deathSaveFailures ?? null, statuses: input.statuses ?? [], notes: input.notes ?? "",
    sourceMonsterID: input.sourceMonsterID ?? null,
  };
}

export function createEmptyStatBlock(): StatBlock {
  return {
    subtitle: "", size: "", alignment: "", habitat: "", speed: "", senses: "", languages: "", skills: "",
    resistances: "", immunities: "", vulnerabilities: "", equipment: "", xp: "", proficiency: "",
    abilities: [], traits: [], actions: [], bonusActions: [], reactions: [], legendaryActions: [], legendaryIntro: "",
  };
}

export function challengeRatingValue(value: string): number {
  const clean = value.trim();
  if (!clean || clean === "?") return -1;
  if (clean.includes("/")) {
    const [numerator, denominator] = clean.split("/").map(Number);
    return numerator !== undefined && denominator ? numerator / denominator : -1;
  }
  const parsed = Number(clean.replace("+", ""));
  return Number.isFinite(parsed) ? parsed : -1;
}

export function slugifyMonsterID(value: string, fallbackNow = Date.now()): string {
  const folded = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/ß/g, "ss").toLocaleLowerCase("de-DE");
  const collapsed = folded.replace(/[^\p{L}\p{N}]+/gu, "_").split("_").filter(Boolean).join("_");
  return collapsed || `monster_${Math.floor(fallbackNow / 1000)}`;
}
