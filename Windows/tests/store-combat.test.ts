import { describe, expect, it } from "vitest";
import { PlannerStore } from "../src/domain/store";

function makeStore(): PlannerStore {
  let id = 0;
  let time = 0;
  return new PlannerStore({
    load: null,
    randomUUID: () => `10000000-0000-0000-0000-${String(++id).padStart(12, "0")}`,
    now: () => "2026-01-01T00:00:00Z",
    random: () => 4,
    monotonicNow: () => (time += 1000),
  });
}

function add(store: PlannerStore, name: string, initiative: number | null, hp = "30"): string {
  store.addCreature({ name, kind: "player", armorClass: 10, hpExpression: hp, initiativeBonus: 0, initiative });
  return store.state.players.at(-1)!.id;
}

describe("PlannerStore HP, statuses and turn flow", () => {
  it("consumes temporary HP first and queues concentration at the correct DC", () => {
    const store = makeStore();
    const id = add(store, "Magier", null);
    store.setTemporaryHP(id, 5);
    store.toggleStatus("concentration", id);
    store.applyDamage(id, "26");

    expect(store.state.players[0]).toMatchObject({ temporaryHitPoints: 0, hitPoints: 9 });
    expect(store.concentrationChecks).toHaveLength(1);
    expect(store.concentrationChecks[0]).toMatchObject({ creatureID: id, creatureName: "Magier", damage: 26, dc: 13 });

    store.resolveConcentrationCheck(store.concentrationChecks[0]!, false);
    expect(store.state.players[0]?.statuses.some((status) => status.id === "concentration")).toBe(false);
    expect(store.concentrationChecks).toHaveLength(0);
  });

  it("uses DC 10 for small concentration damage and supports dismiss/pass", () => {
    const store = makeStore();
    const id = add(store, "Magier", null);
    store.toggleStatus("concentration", id);
    store.applyDamage(id, "7");
    expect(store.concentrationChecks[0]?.dc).toBe(10);
    store.resolveConcentrationCheck(store.concentrationChecks[0]!, true);
    expect(store.state.players[0]?.statuses.some((status) => status.id === "concentration")).toBe(true);
    store.applyDamage(id, "1");
    store.dismissConcentrationCheck(store.concentrationChecks[0]!);
    expect(store.concentrationChecks).toHaveLength(0);
  });

  it("marks death-save outcomes and healing resets saves and stable", () => {
    const store = makeStore();
    const id = add(store, "Held", null, "10");
    store.applyDamage(id, "10");
    store.setDeathSaves(id, 3, 1);
    expect(store.state.players[0]?.statuses.some((status) => status.id === "stable")).toBe(true);
    store.applyHealing(id, "5");
    expect(store.state.players[0]).toMatchObject({ hitPoints: 5, deathSaveSuccesses: null, deathSaveFailures: null });
    expect(store.state.players[0]?.statuses.some((status) => status.id === "stable")).toBe(false);

    store.applyDamage(id, "5");
    store.setDeathSaves(id, 0, 3);
    expect(store.state.players[0]?.statuses.some((status) => status.id === "dead")).toBe(true);
  });

  it("ticks status duration at the end of the active turn and wraps rounds", () => {
    const store = makeStore();
    const first = add(store, "A", 20);
    const second = add(store, "B", 10);
    store.toggleStatus("poisoned", first);
    store.setStatusDuration(first, "poisoned", 1);

    store.nextTurn();
    expect(store.state.activeID).toBe(second);
    expect(store.state.players[0]?.statuses.some((status) => status.id === "poisoned")).toBe(false);
    expect(store.state.log.at(-1)).toMatchObject({ message: "A: Status Vergiftet endet", kind: "status" });
    store.nextTurn();
    expect(store.state.activeID).toBe(first);
    expect(store.state.round).toBe(2);
    store.previousTurn();
    expect(store.state.activeID).toBe(second);
    expect(store.state.round).toBe(1);
  });

  it("clamps quick HP, death saves and status durations", () => {
    const store = makeStore();
    const id = add(store, "Held", null, "10");
    store.applyQuickHP(id, -5);
    store.applyQuickHP(id, 1);
    expect(store.state.players[0]?.hitPoints).toBe(6);
    store.setDeathSaves(id, 99, -4);
    expect(store.state.players[0]).toMatchObject({ deathSaveSuccesses: 3, deathSaveFailures: 0 });
    store.toggleStatus("poisoned", id, 120);
    expect(store.state.players[0]?.statuses.find((status) => status.id === "poisoned")?.duration).toBe(99);
  });

  it("warns when advancing without initiative", () => {
    const store = makeStore();
    add(store, "Held", null);
    store.nextTurn();
    expect(store.lastNotice?.message).toBe("Keine Initiative eingetragen");
  });
});
