import { describe, expect, it } from "vitest";
import { PlannerStore } from "../src/domain/store";

function makeStore(): PlannerStore {
  let id = 0;
  return new PlannerStore({
    load: null,
    randomUUID: () => `00000000-0000-0000-0000-${String(++id).padStart(12, "0")}`,
    now: () => "2026-01-01T00:00:00Z",
    random: () => 4,
  });
}

describe("PlannerStore creatures and initiative", () => {
  it("validates and adds players and sequentially named monsters", () => {
    const store = makeStore();
    expect(store.addCreature({ name: " ", kind: "player", armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: null })).toBe(false);
    expect(store.lastNotice?.message).toBe("Bitte Namen eingeben");
    expect(store.addCreature({ name: "Goblin", kind: "monster", armorClass: 15, hpExpression: "0", initiativeBonus: 2, initiative: 12 })).toBe(false);
    expect(store.lastNotice?.message).toBe("Monster brauchen HP");

    store.addCreature({ name: "Älva", kind: "player", armorClass: 17, hpExpression: "3d6+3", initiativeBonus: 3, initiative: 18 });
    store.addCreature({ name: "Goblin", kind: "monster", armorClass: 15, hpExpression: "7", initiativeBonus: 2, initiative: 12 });
    store.addCreature({ name: "Goblin", kind: "monster", armorClass: 15, hpExpression: "7", initiativeBonus: 2, initiative: 12 });

    expect(store.state.players[0]).toMatchObject({ name: "Älva", hitPoints: 15, maxHitPoints: 15 });
    expect(store.state.monsters.map((creature) => creature.name)).toEqual(["Goblin 1", "Goblin 2"]);
    expect(store.state.activeID).toBe(store.state.players[0]?.id);
  });

  it("duplicates, activates and deletes creatures without losing invariants", () => {
    const store = makeStore();
    store.addCreature({ name: "Held", kind: "player", armorClass: 12, hpExpression: "10", initiativeBonus: 1, initiative: null });
    const heldID = store.state.players[0]!.id;
    store.duplicateCreature(heldID);
    expect(store.state.players.map((creature) => creature.name)).toEqual(["Held", "Held Kopie"]);
    expect(store.state.players[1]?.currentInitiative).toBeNull();

    store.setActive(heldID);
    expect(store.state.players[0]?.currentInitiative).toBe(0);
    expect(store.state.activeID).toBe(heldID);
    store.deleteCreature(heldID);
    expect(store.state.activeID).toBeNull();
  });

  it("allows drag ordering only inside an initiative tie", () => {
    const store = makeStore();
    for (const name of ["A", "B", "C"]) store.addCreature({ name, kind: "player", armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: name === "C" ? 9 : 10 });
    const [a, b, c] = store.state.players;
    store.moveCreature(b!.id, a!.id);
    expect(store.initiativeList.map((creature) => creature.name)).toEqual(["B", "A", "C"]);

    store.moveCreature(c!.id, a!.id);
    expect(store.lastNotice?.message).toBe("Reihenfolge lässt sich nur bei gleicher Initiative ändern");
  });

  it("edits creature identity and combat values with safe clamps", () => {
    const store = makeStore();
    store.addCreature({ name: "Held", kind: "player", armorClass: 12, hpExpression: "10", initiativeBonus: 1, initiative: 8 });
    const id = store.state.players[0]!.id;
    store.updateCreature(id, { name: "Heldin", armorClass: 99, maxHitPoints: 20, hitPoints: 15, initiativeBonus: -2, currentInitiative: 11, notes: "Frontlinie" });
    expect(store.state.players[0]).toMatchObject({ name: "Heldin", armorClass: 40, maxHitPoints: 20, hitPoints: 15, initiativeBonus: -2, currentInitiative: 11, notes: "Frontlinie" });
  });
});
