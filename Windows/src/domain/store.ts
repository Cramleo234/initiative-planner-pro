import { rollDice } from "./dice.js";
import {
  createCreature,
  createDefaultState,
  initiativeList,
  normalizePlannerState,
  PLANNER_THEMES,
  slugifyMonsterID,
  type Creature,
  type CreatureKind,
  type HPMode,
  type MonsterTemplate,
  type PlannerState,
  type StatusDefinition,
} from "./models.js";
import { importMonsters } from "./monsterImporter.js";

export interface Notice { id: string; message: string; style: string }

export interface StoreOptions {
  load?: PlannerState | null;
  randomUUID?: () => string;
  now?: () => string;
  monotonicNow?: () => number;
  random?: (sides: number) => number;
  onSave?: (state: PlannerState) => void | Promise<void>;
}

export interface ConcentrationCheck {
  id: string;
  creatureID: string;
  creatureName: string;
  damage: number;
  dc: number;
}

export interface AddCreatureInput {
  name: string;
  kind: CreatureKind;
  armorClass: number;
  hpExpression: string;
  initiativeBonus: number;
  initiative: number | null;
}

export type CustomStatusInput = Omit<StatusDefinition, "id" | "isOfficial">;
export type CreatureUpdate = Partial<Pick<Creature, "name" | "armorClass" | "hitPoints" | "maxHitPoints" | "initiativeBonus" | "currentInitiative" | "notes">>;

export class PlannerStore {
  private currentState: PlannerState;
  private readonly randomUUID: () => string;
  private readonly now: () => string;
  private readonly random: (sides: number) => number;
  private readonly monotonicNow: () => number;
  private readonly onSave?: (state: PlannerState) => void | Promise<void>;
  private readonly undoStack: PlannerState[] = [];
  private readonly redoStack: PlannerState[] = [];
  private readonly listeners = new Set<() => void>();
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private noticeTimer: ReturnType<typeof setTimeout> | null = null;
  private lastTurnAdvance = Number.NEGATIVE_INFINITY;
  lastNotice: Notice | null = null;
  concentrationChecks: ConcentrationCheck[] = [];

  constructor(options: StoreOptions = {}) {
    this.randomUUID = options.randomUUID ?? (() => crypto.randomUUID());
    this.now = options.now ?? (() => new Date().toISOString());
    this.random = options.random ?? ((sides) => Math.floor(Math.random() * sides) + 1);
    this.monotonicNow = options.monotonicNow ?? (() => performance.now());
    this.onSave = options.onSave;
    this.currentState = options.load ? normalizePlannerState(options.load) : createDefaultState(this.now);
  }

  get state(): PlannerState { return this.currentState; }
  get initiativeList(): Creature[] { return initiativeList(this.currentState); }
  get canUndo(): boolean { return this.undoStack.length > 0; }
  get canRedo(): boolean { return this.redoStack.length > 0; }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }

  private emit(): void { for (const listener of this.listeners) listener(); }

  notice(message: string, style = "success"): void {
    if (this.noticeTimer) clearTimeout(this.noticeTimer);
    const notice = { id: this.randomUUID(), message, style };
    this.lastNotice = notice;
    this.emit();
    this.noticeTimer = setTimeout(() => {
      if (this.lastNotice?.id === notice.id) {
        this.lastNotice = null;
        this.emit();
      }
      this.noticeTimer = null;
    }, 5000);
  }

  addCreature(input: AddCreatureInput): boolean {
    const cleanName = input.name.trim();
    if (!cleanName) { this.notice("Bitte Namen eingeben", "error"); return false; }
    let hitPoints: number;
    try { hitPoints = input.hpExpression.trim() ? Math.max(0, rollDice(input.hpExpression, this.random).total) : 0; }
    catch (error) { this.notice(error instanceof Error ? error.message : String(error), "error"); return false; }
    if (input.kind === "monster" && hitPoints <= 0) { this.notice("Monster brauchen HP", "error"); return false; }

    this.commit(`${input.kind === "player" ? "Spieler" : "Monster"} ${cleanName} hinzugefügt`, "success", true, (state) => {
      const name = input.kind === "monster" ? nextMonsterName(cleanName, state.monsters.map((creature) => creature.name)) : cleanName;
      const creature = createCreature({
        id: this.randomUUID(), name, kind: input.kind, armorClass: input.armorClass,
        hitPoints, maxHitPoints: hitPoints, initiativeBonus: input.initiativeBonus, currentInitiative: input.initiative,
      });
      if (input.kind === "player") state.players.push(creature); else state.monsters.push(creature);
      if (input.initiative !== null && state.activeID === null) state.activeID = creature.id;
    });
    return true;
  }

  updateCreature(id: string, update: CreatureUpdate): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    const name = update.name?.trim();
    if (update.name !== undefined && !name) { this.notice("Bitte Namen eingeben", "error"); return; }
    this.commit(`${name ?? creature.name} aktualisiert`, "success", true, (state) => {
      this.mutateCreature(state, id, (entry) => {
        if (name) entry.name = name;
        if (update.armorClass !== undefined) entry.armorClass = Math.max(1, Math.min(40, Math.trunc(update.armorClass)));
        if (update.maxHitPoints !== undefined) entry.maxHitPoints = Math.max(0, Math.trunc(update.maxHitPoints));
        if (update.hitPoints !== undefined) entry.hitPoints = Math.max(0, Math.min(entry.maxHitPoints, Math.trunc(update.hitPoints)));
        if (update.initiativeBonus !== undefined) entry.initiativeBonus = Math.max(-10, Math.min(20, Math.trunc(update.initiativeBonus)));
        if (update.currentInitiative !== undefined) entry.currentInitiative = update.currentInitiative === null ? null : Math.trunc(update.currentInitiative);
        if (update.notes !== undefined) entry.notes = update.notes;
      });
    });
  }

  deleteCreature(id: string): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    this.commit(`${creature.name} entfernt`, "warning", true, (state) => {
      state.players = state.players.filter((entry) => entry.id !== id);
      state.monsters = state.monsters.filter((entry) => entry.id !== id);
      if (state.activeID === id) state.activeID = null;
    });
  }

  duplicateCreature(id: string): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    this.commit(`${creature.name} dupliziert`, "success", true, (state) => {
      const copy = structuredClone(creature);
      copy.id = this.randomUUID();
      copy.currentInitiative = null;
      copy.name = creature.kind === "monster"
        ? nextMonsterName(creature.name.replace(/\s\d+$/, ""), state.monsters.map((entry) => entry.name))
        : `${creature.name} Kopie`;
      if (copy.kind === "player") state.players.push(copy); else state.monsters.push(copy);
    });
  }

  setActive(id: string): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    this.commit(`${creature.name} ist aktiv`, "info", true, (state) => {
      this.mutateCreature(state, id, (entry) => { if (entry.currentInitiative === null) entry.currentInitiative = 0; });
      state.activeID = id;
    });
  }

  setInitiative(id: string, value: number | null): void {
    this.commit(null, "success", false, (state) => {
      this.mutateCreature(state, id, (creature) => { creature.currentInitiative = value; });
      if (value !== null && state.activeID === null) state.activeID = id;
    });
  }

  moveCreature(movedID: string, targetID: string): void {
    if (movedID === targetID) return;
    const moved = this.findCreature(movedID);
    const target = this.findCreature(targetID);
    if (!moved || !target) return;
    if (moved.currentInitiative === null || target.currentInitiative !== moved.currentInitiative) {
      this.notice("Reihenfolge lässt sich nur bei gleicher Initiative ändern", "warning");
      return;
    }
    const score = moved.currentInitiative;
    this.commit(`Reihenfolge bei Initiative ${score} angepasst`, "info", true, (state) => {
      const group = initiativeList(state).filter((creature) => creature.currentInitiative === score).map((creature) => creature.id).filter((id) => id !== movedID);
      group.splice(group.indexOf(targetID) >= 0 ? group.indexOf(targetID) : group.length, 0, movedID);
      group.forEach((id, position) => this.mutateCreature(state, id, (creature) => { creature.tieBreak = position; }));
    });
  }

  setTemporaryHP(id: string, amount: number): void {
    this.commit("Temporäre HP gesetzt", "info", true, (state) => {
      this.mutateCreature(state, id, (creature) => { creature.temporaryHitPoints = Math.max(0, Math.trunc(amount)); });
    });
  }

  applyDamage(id: string, expression: string): void { this.applyHPChange(id, expression, false); }

  applyHealing(id: string, expression: string): void { this.applyHPChange(id, expression, true); }

  applyQuickHP(id: string, delta: number): void {
    if (delta < 0) this.applyDamage(id, String(-delta));
    else if (delta > 0) this.applyHealing(id, String(delta));
  }

  private applyHPChange(id: string, expression: string, healing: boolean): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    let amount: number;
    try { amount = Math.max(0, rollDice(expression, this.random).total); }
    catch (error) { this.notice(error instanceof Error ? error.message : String(error), "error"); return; }
    if (amount === 0) return;
    const hadConcentration = creature.statuses.some((status) => status.id === "concentration");
    this.commit(`${creature.name}: ${healing ? `${amount} Heilung` : `${amount} Schaden`}`, healing ? "success" : "warning", true, (state) => {
      this.mutateCreature(state, id, (entry) => {
        if (healing) {
          entry.hitPoints = Math.min(entry.maxHitPoints || amount, entry.hitPoints + amount);
          if (entry.hitPoints > 0) {
            entry.deathSaveSuccesses = null;
            entry.deathSaveFailures = null;
            entry.statuses = entry.statuses.filter((status) => status.id !== "stable");
          }
        } else {
          const absorbed = Math.min(entry.temporaryHitPoints, amount);
          entry.temporaryHitPoints -= absorbed;
          entry.hitPoints = Math.max(0, entry.hitPoints - (amount - absorbed));
        }
      });
    });
    if (!healing && hadConcentration) {
      this.concentrationChecks.push({
        id: this.randomUUID(), creatureID: id, creatureName: creature.name,
        damage: amount, dc: Math.max(10, Math.floor(amount / 2)),
      });
      this.emit();
    }
  }

  resolveConcentrationCheck(check: ConcentrationCheck, passed: boolean): void {
    this.concentrationChecks = this.concentrationChecks.filter((entry) => entry.id !== check.id);
    const creature = this.findCreature(check.creatureID);
    if (!creature) return;
    this.commit(null, passed ? "info" : "warning", false, (state) => {
      if (!passed) this.mutateCreature(state, check.creatureID, (entry) => {
        entry.statuses = entry.statuses.filter((status) => status.id !== "concentration");
      });
      state.log.push({
        id: this.randomUUID(), date: this.now(),
        message: `${creature.name}: Konzentrationsprobe SG ${check.dc} ${passed ? "bestanden" : "verpatzt — Konzentration endet"}`,
        kind: passed ? "info" : "warning",
      });
    });
  }

  dismissConcentrationCheck(check: ConcentrationCheck): void {
    this.concentrationChecks = this.concentrationChecks.filter((entry) => entry.id !== check.id);
    this.emit();
  }

  setDeathSaves(id: string, successes: number, failures: number): void {
    if (!this.findCreature(id)) return;
    const clampedSuccesses = Math.max(0, Math.min(3, Math.trunc(successes)));
    const clampedFailures = Math.max(0, Math.min(3, Math.trunc(failures)));
    this.commit(null, "info", false, (state) => {
      this.mutateCreature(state, id, (entry) => {
        entry.deathSaveSuccesses = clampedSuccesses;
        entry.deathSaveFailures = clampedFailures;
        if (clampedFailures >= 3 && !entry.statuses.some((status) => status.id === "dead")) entry.statuses.push({ id: "dead", duration: null, note: "" });
        if (clampedSuccesses >= 3 && !entry.statuses.some((status) => status.id === "stable")) entry.statuses.push({ id: "stable", duration: null, note: "" });
      });
    });
  }

  toggleStatus(statusID: string, creatureID: string, duration: number | null = null): void {
    if (!this.currentState.statuses.some((status) => status.id === statusID) || !this.findCreature(creatureID)) return;
    this.commit(null, "info", false, (state) => {
      this.mutateCreature(state, creatureID, (creature) => {
        const index = creature.statuses.findIndex((status) => status.id === statusID);
        if (index >= 0) creature.statuses.splice(index, 1);
        else creature.statuses.push({ id: statusID, duration: duration === null ? null : Math.max(0, Math.min(99, Math.trunc(duration))), note: "" });
      });
    });
  }

  setStatusDuration(creatureID: string, statusID: string, duration: number | null): void {
    this.commit(null, "info", false, (state) => {
      this.mutateCreature(state, creatureID, (creature) => {
        const status = creature.statuses.find((entry) => entry.id === statusID);
        if (status) status.duration = duration === null ? null : Math.max(0, Math.min(99, Math.trunc(duration)));
      });
    });
  }

  nextTurn(): void {
    if (this.initiativeList.length === 0) { this.notice("Keine Initiative eingetragen", "warning"); return; }
    if (!this.allowTurnAdvance()) return;
    this.commit(null, "info", false, (state) => {
      if (state.activeID) this.tickDurations(state, state.activeID);
      const list = initiativeList(state);
      let index = list.findIndex((creature) => creature.id === state.activeID) + 1;
      if (index >= list.length) { index = 0; state.round += 1; }
      state.activeID = list[index]?.id ?? null;
    });
  }

  previousTurn(): void {
    if (this.initiativeList.length === 0 || !this.allowTurnAdvance()) return;
    this.commit(null, "info", false, (state) => {
      const list = initiativeList(state);
      let index = list.findIndex((creature) => creature.id === state.activeID) - 1;
      if (index < 0) { index = list.length - 1; state.round = Math.max(1, state.round - 1); }
      state.activeID = list[index]?.id ?? null;
    });
  }

  private allowTurnAdvance(): boolean {
    const now = this.monotonicNow();
    if (now - this.lastTurnAdvance <= 200) return false;
    this.lastTurnAdvance = now;
    return true;
  }

  private tickDurations(state: PlannerState, activeID: string): void {
    this.mutateCreature(state, activeID, (creature) => {
      creature.statuses = creature.statuses.flatMap((status) => {
        if (status.duration === null) return [status];
        const duration = status.duration - 1;
        if (duration > 0) return [{ ...status, duration }];
        const label = state.statuses.find((definition) => definition.id === status.id)?.label ?? status.id;
        state.log.push({ id: this.randomUUID(), date: this.now(), message: `${creature.name}: Status ${label} endet`, kind: "status" });
        return [];
      });
    });
  }

  undo(): void {
    const previous = this.undoStack.pop();
    if (!previous) { this.notice("Nichts zum Rückgängigmachen", "warning"); return; }
    this.redoStack.push(structuredClone(this.currentState));
    this.currentState = normalizePlannerState(previous);
    this.scheduleSave();
    this.emit();
    this.notice("Rückgängig");
  }

  redo(): void {
    const next = this.redoStack.pop();
    if (!next) { this.notice("Nichts zum Wiederholen", "warning"); return; }
    this.undoStack.push(structuredClone(this.currentState));
    this.currentState = normalizePlannerState(next);
    this.scheduleSave();
    this.emit();
    this.notice("Wiederholt");
  }

  addStatus(input: CustomStatusInput): void {
    const label = input.label.trim();
    if (!label) { this.notice("Status braucht einen Namen", "error"); return; }
    const id = slugifyMonsterID(label);
    this.commit(`Status ${label} erstellt`, "success", true, (state) => {
      state.statuses = state.statuses.filter((status) => status.id !== id);
      state.statuses.push({ ...input, id, label, short: input.short || label.slice(0, 4), isOfficial: false });
    });
  }

  updateStatus(definition: StatusDefinition): void {
    const existing = this.currentState.statuses.find((status) => status.id === definition.id);
    if (!existing) return;
    if (existing.isOfficial) { this.notice("Offizielle Status können nicht bearbeitet werden.", "warning"); return; }
    this.commit(`Status ${definition.label} aktualisiert`, "success", true, (state) => {
      const index = state.statuses.findIndex((status) => status.id === definition.id);
      if (index >= 0) state.statuses[index] = {
        id: definition.id,
        label: definition.label,
        short: definition.short,
        category: definition.category,
        priority: definition.priority,
        polarity: definition.polarity,
        description: definition.description,
        effects: [...definition.effects],
        isOfficial: false,
      };
    });
  }

  deleteStatus(id: string): void {
    const status = this.currentState.statuses.find((entry) => entry.id === id);
    if (!status || status.isOfficial) { this.notice("Offizielle Status können nicht gelöscht werden.", "warning"); return; }
    this.commit(`Status ${status.label} gelöscht`, "warning", true, (state) => {
      state.statuses = state.statuses.filter((entry) => entry.id !== id);
      for (const creature of [...state.players, ...state.monsters]) creature.statuses = creature.statuses.filter((entry) => entry.id !== id);
    });
  }

  saveMonsterTemplate(template: MonsterTemplate): void {
    this.commit(`${template.name} in Datenbank gespeichert`, "success", true, (state) => {
      state.monsterDatabase = state.monsterDatabase.filter((entry) => entry.id !== template.id);
      state.monsterDatabase.push(structuredClone(template));
    });
  }

  deleteMonsterTemplate(id: string): void {
    const template = this.currentState.monsterDatabase.find((entry) => entry.id === id);
    if (!template) return;
    this.commit(`${template.name} aus Datenbank gelöscht`, "warning", true, (state) => {
      state.monsterDatabase = state.monsterDatabase.filter((entry) => entry.id !== id);
    });
  }

  clearMonsterDatabase(): void {
    if (this.currentState.monsterDatabase.length === 0) { this.notice("Die Datenbank ist bereits leer", "warning"); return; }
    this.commit("Monsterdatenbank geleert", "warning", true, (state) => { state.monsterDatabase = []; });
  }

  addMonsterFromDatabase(template: MonsterTemplate, quantity: number, mode: HPMode): void {
    const count = Math.max(1, Math.min(50, Math.trunc(quantity)));
    this.commit(`${count}× ${template.name} hinzugefügt`, "success", true, (state) => {
      for (let index = 0; index < count; index += 1) {
        const hp = mode === "roll" ? Math.max(1, rollDice(template.hpDice, this.random).total) : template.hpAverage;
        state.monsters.push(createCreature({
          id: this.randomUUID(), name: nextMonsterName(template.name, state.monsters.map((entry) => entry.name)),
          kind: "monster", armorClass: template.armorClass, hitPoints: hp, maxHitPoints: hp,
          initiativeBonus: template.initiativeBonus, sourceMonsterID: template.id,
        }));
      }
    });
  }

  importMonsterText(text: string, sourceName: string): void {
    try {
      const monsters = importMonsters(text, sourceName || "Import", this.now);
      this.commit(`${monsters.length} Monster dauerhaft importiert`, "success", true, (state) => {
        for (const monster of monsters) {
          state.monsterDatabase = state.monsterDatabase.filter((entry) => entry.id !== monster.id);
          state.monsterDatabase.push({ ...monster, source: sourceName || "Import", importedAt: this.now() });
        }
      });
    } catch (error) {
      this.notice(error instanceof Error ? error.message : String(error), "error");
    }
  }

  saveEncounter(name: string): void {
    const clean = name.trim();
    if (!clean) { this.notice("Bitte Encounter-Namen eingeben", "error"); return; }
    this.commit(`Encounter ${clean} gespeichert`, "success", true, (state) => {
      state.encounters = state.encounters.filter((entry) => entry.name.toLocaleLowerCase("de-DE") !== clean.toLocaleLowerCase("de-DE"));
      state.encounters.unshift({
        id: this.randomUUID(), name: clean, savedAt: this.now(), round: state.round, activeID: state.activeID,
        players: structuredClone(state.players), monsters: structuredClone(state.monsters), log: structuredClone(state.log),
      });
    });
  }

  loadEncounter(encounter: PlannerState["encounters"][number]): void {
    this.commit(`Encounter ${encounter.name} geladen`, "success", true, (state) => {
      state.players = structuredClone(encounter.players);
      state.monsters = structuredClone(encounter.monsters);
      state.round = encounter.round;
      state.activeID = encounter.activeID;
      state.log = structuredClone(encounter.log);
    });
  }

  deleteEncounter(id: string): void {
    this.commit("Encounter gelöscht", "warning", true, (state) => {
      state.encounters = state.encounters.filter((entry) => entry.id !== id);
    });
  }

  clearCombat(): void {
    this.commit("Kampf geleert", "warning", true, (state) => {
      state.players = [];
      state.monsters = [];
      state.round = 1;
      state.activeID = null;
    });
  }

  removeDefeatedMonsters(): void {
    const count = this.currentState.monsters.filter((monster) => monster.maxHitPoints > 0 && monster.hitPoints <= 0).length;
    if (count === 0) { this.notice("Keine besiegten Monster im Kampf", "warning"); return; }
    this.commit(`${count} besiegte Monster aufgeräumt`, "warning", true, (state) => {
      state.monsters = state.monsters.filter((monster) => !(monster.maxHitPoints > 0 && monster.hitPoints <= 0));
    });
  }

  resetRound(): void {
    if (this.currentState.round === 1) return;
    this.commit("Runde auf 1 zurückgesetzt", "info", true, (state) => { state.round = 1; });
  }

  setHPMode(mode: HPMode): void { this.commit(null, "info", false, (state) => { state.hpMode = mode; }); }

  setTheme(id: string): void { this.commit(null, "info", false, (state) => { state.selectedTheme = id; }); }

  nextTheme(): void {
    const index = PLANNER_THEMES.findIndex((theme) => theme.id === this.currentState.selectedTheme);
    this.setTheme(PLANNER_THEMES[(index + 1 + PLANNER_THEMES.length) % PLANNER_THEMES.length]!.id);
  }

  toggleKeepDatabaseOpen(): void { this.commit(null, "info", false, (state) => { state.keepDatabaseOpen = !state.keepDatabaseOpen; }); }

  clearLog(): void { this.commit("Protokoll geleert", "warning", true, (state) => { state.log = []; }); }

  rollInitiative(id: string): void {
    const creature = this.findCreature(id);
    if (!creature) return;
    const result = rollDice(`d20${creature.initiativeBonus >= 0 ? "+" : ""}${creature.initiativeBonus}`, this.random).total;
    this.setInitiative(id, result);
  }

  rollAllMonsterInitiative(): void {
    if (this.currentState.monsters.length === 0) { this.notice("Keine Monster vorhanden", "warning"); return; }
    this.commit("Monster-Initiative gewürfelt", "info", true, (state) => {
      for (const monster of state.monsters) monster.currentInitiative = rollDice(`d20${monster.initiativeBonus >= 0 ? "+" : ""}${monster.initiativeBonus}`, this.random).total;
    });
  }

  private findCreature(id: string): Creature | undefined {
    return [...this.currentState.players, ...this.currentState.monsters].find((creature) => creature.id === id);
  }

  private mutateCreature(state: PlannerState, id: string, update: (creature: Creature) => void): void {
    const creature = [...state.players, ...state.monsters].find((entry) => entry.id === id);
    if (creature) update(creature);
  }

  private commit(message: string | null, style: string, notify: boolean, body: (state: PlannerState) => void): void {
    const next = structuredClone(this.currentState);
    this.undoStack.push(structuredClone(this.currentState));
    if (this.undoStack.length > 80) this.undoStack.shift();
    this.redoStack.length = 0;
    try {
      body(next);
      if (message) {
        next.log.push({ id: this.randomUUID(), date: this.now(), message, kind: style });
        if (next.log.length > 220) next.log = next.log.slice(-220);
      }
      this.currentState = normalizePlannerState(next);
      this.emit();
      if (message && notify) this.notice(message, style);
      this.scheduleSave();
    } catch (error) {
      this.undoStack.pop();
      this.notice(error instanceof Error ? error.message : String(error), "error");
    }
  }

  private scheduleSave(): void {
    if (!this.onSave) return;
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      void Promise.resolve(this.onSave?.(structuredClone(this.currentState))).catch((error: unknown) => {
        this.notice(`Speichern fehlgeschlagen: ${error instanceof Error ? error.message : String(error)}`, "error");
      });
    }, 350);
  }

  async flushPendingSave(): Promise<void> {
    if (!this.onSave) return;
    if (this.saveTimer) {
      clearTimeout(this.saveTimer);
      this.saveTimer = null;
    }
    await this.onSave(structuredClone(this.currentState));
  }
}

export function nextMonsterName(base: string, existing: string[]): string {
  const clean = base.trim().replace(/\s\d+$/, "");
  let index = 1;
  while (existing.includes(`${clean} ${index}`)) index += 1;
  return `${clean} ${index}`;
}
