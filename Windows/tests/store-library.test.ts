import { describe, expect, it, vi } from "vitest";
import { createEmptyStatBlock, type MonsterTemplate, type StatusDefinition } from "../src/domain/models";
import { PlannerStore } from "../src/domain/store";

function makeStore(): PlannerStore {
  let id = 0;
  return new PlannerStore({
    load: null,
    randomUUID: () => `20000000-0000-0000-0000-${String(++id).padStart(12, "0")}`,
    now: () => "2026-02-03T04:05:06Z",
    random: () => 4,
    monotonicNow: (() => { let time = 0; return () => (time += 1000); })(),
  });
}

const template: MonsterTemplate = {
  id: "goblin", name: "Goblin", armorClass: 15, hpAverage: 7, hpDice: "2d6",
  challengeRating: "1/4", initiativeBonus: 2, type: "Humanoid", source: "Test",
  notes: "", importedAt: null, statblock: createEmptyStatBlock(),
};

describe("PlannerStore library, encounters and history", () => {
  it("supports undo and redo for domain changes", () => {
    const store = makeStore();
    store.addCreature({ name: "Held", kind: "player", armorClass: 14, hpExpression: "10", initiativeBonus: 1, initiative: 12 });
    expect(store.state.players).toHaveLength(1);
    store.undo();
    expect(store.state.players).toHaveLength(0);
    expect(store.canRedo).toBe(true);
    store.redo();
    expect(store.state.players[0]?.name).toBe("Held");
  });

  it("manages custom statuses while protecting official definitions", () => {
    const store = makeStore();
    store.addStatus({ label: "Glühend", short: "Glüh", category: "magic", polarity: "bad", priority: 4, description: "Leuchtet", effects: ["Sichtbar"] });
    const custom = store.state.statuses.find((status) => status.id === "gluhend")!;
    expect(custom).toMatchObject({ isOfficial: false, label: "Glühend" });

    const updated: StatusDefinition = { ...custom, description: "Sehr hell" };
    store.updateStatus(updated);
    expect(store.state.statuses.find((status) => status.id === custom.id)?.description).toBe("Sehr hell");
    store.updateStatus({ ...store.state.statuses[0]!, label: "Manipuliert" });
    expect(store.lastNotice?.message).toBe("Offizielle Status können nicht bearbeitet werden.");
    store.deleteStatus(custom.id);
    expect(store.state.statuses.some((status) => status.id === custom.id)).toBe(false);
  });

  it("manages monster templates, filters quantities and supports both HP modes", () => {
    const store = makeStore();
    store.saveMonsterTemplate(template);
    store.addMonsterFromDatabase(template, 2, "average");
    expect(store.state.monsters.map((monster) => [monster.name, monster.hitPoints])).toEqual([["Goblin 1", 7], ["Goblin 2", 7]]);
    store.addMonsterFromDatabase(template, 1, "roll");
    expect(store.state.monsters[2]).toMatchObject({ name: "Goblin 3", hitPoints: 8 });
    store.deleteMonsterTemplate(template.id);
    expect(store.state.monsterDatabase).toHaveLength(0);
  });

  it("imports monster text and persists encounters", () => {
    const store = makeStore();
    store.importMonsterText("Name: Nebelweber\nRK: 15\nTP: 42 (8d8+8)\nHG: 4", "Fixture.md");
    expect(store.state.monsterDatabase[0]).toMatchObject({ name: "Nebelweber", source: "Fixture.md" });
    store.addCreature({ name: "Held", kind: "player", armorClass: 14, hpExpression: "10", initiativeBonus: 1, initiative: 12 });
    store.saveEncounter("Brücke");
    const encounter = store.state.encounters[0]!;
    store.clearCombat();
    store.loadEncounter(encounter);
    expect(store.state.players[0]?.name).toBe("Held");
    store.deleteEncounter(encounter.id);
    expect(store.state.encounters).toHaveLength(0);
  });

  it("updates settings, clears defeated monsters and preserves database", () => {
    const store = makeStore();
    store.setHPMode("roll");
    store.setTheme("midnight");
    store.toggleKeepDatabaseOpen();
    store.saveMonsterTemplate(template);
    store.addMonsterFromDatabase(template, 1, "average");
    const id = store.state.monsters[0]!.id;
    store.applyDamage(id, "7");
    store.removeDefeatedMonsters();
    expect(store.state.monsters).toHaveLength(0);
    expect(store.state.monsterDatabase).toHaveLength(1);
    expect(store.state).toMatchObject({ hpMode: "roll", selectedTheme: "midnight", keepDatabaseOpen: false });
  });

  it("reports rejected debounced saves instead of creating an unhandled rejection", async () => {
    vi.useFakeTimers();
    try {
      const store = new PlannerStore({
        load: null,
        randomUUID: () => "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
        now: () => "2026-02-03T04:05:06Z",
        onSave: async () => { throw new Error("Datenträger voll"); },
      });
      store.setTheme("midnight");

      await vi.advanceTimersByTimeAsync(350);

      expect(store.lastNotice).toMatchObject({ message: "Speichern fehlgeschlagen: Datenträger voll", style: "error" });
    } finally {
      vi.useRealTimers();
    }
  });
});
