import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
  CURRENT_SCHEMA_VERSION,
  StateFormatError,
  createDefaultState,
  decodePlannerState,
  encodePlannerState,
  initiativeList,
  normalizePlannerState,
} from "../src/domain/models";

const fixturePath = resolve(import.meta.dirname, "../../Fixtures/planner-state-v1.json");
const fixtureText = readFileSync(fixturePath, "utf8");

describe("PlannerState format", () => {
  it("uses a valid first-run theme and the complete official status library", () => {
    const state = createDefaultState();

    expect(state.schemaVersion).toBe(CURRENT_SCHEMA_VERSION);
    expect(state.selectedTheme).toBe("ember");
    expect(state.statuses).toHaveLength(27);
    expect(state.statuses.every((status) => status.isOfficial)).toBe(true);
  });

  it("decodes the complete cross-platform golden fixture", () => {
    const state = decodePlannerState(fixtureText);

    expect(state.schemaVersion).toBe(1);
    expect(state.players[0]?.name).toBe("Älva 🧙");
    expect(state.monsterDatabase[0]?.statblock?.actions[0]?.name).toBe("Biss");
    expect(state.encounters[0]?.name).toBe("Brücke über den Äther");
    expect(state.statuses).toHaveLength(28);
    expect(state.statuses[0]?.effects).toHaveLength(3);
    expect(state.log[0]?.date).toBe("2026-01-04T05:06:07Z");
  });

  it("accepts legacy unversioned state as schema version one", () => {
    const legacy = JSON.parse(fixtureText) as Record<string, unknown>;
    delete legacy.schemaVersion;

    expect(decodePlannerState(JSON.stringify(legacy)).schemaVersion).toBe(1);
  });

  it("accepts Swift-encoded omitted optionals and normalizes them to null", () => {
    const legacy = JSON.parse(fixtureText) as Record<string, unknown>;
    delete legacy.schemaVersion;
    const player = (legacy.players as Array<Record<string, unknown>>)[0]!;
    delete player.tieBreak;
    delete player.deathSaveSuccesses;
    delete player.deathSaveFailures;
    delete player.sourceMonsterID;
    const status = (player.statuses as Array<Record<string, unknown>>)[0]!;
    delete status.duration;
    const monster = (legacy.monsterDatabase as Array<Record<string, unknown>>)[0]!;
    delete monster.importedAt;

    const decoded = decodePlannerState(JSON.stringify(legacy));

    expect(decoded.players[0]).toMatchObject({
      tieBreak: null,
      deathSaveSuccesses: null,
      deathSaveFailures: null,
      sourceMonsterID: null,
    });
    expect(decoded.players[0]?.statuses[0]?.duration).toBeNull();
    expect(decoded.monsterDatabase[0]?.importedAt).toBeNull();
  });

  it("rejects incompatible, incomplete and corrupt state", () => {
    const future = JSON.parse(fixtureText) as Record<string, unknown>;
    future.schemaVersion = CURRENT_SCHEMA_VERSION + 1;
    expect(() => decodePlannerState(JSON.stringify(future))).toThrowError(StateFormatError);

    const incomplete = JSON.parse(fixtureText) as Record<string, unknown>;
    delete incomplete.players;
    expect(() => decodePlannerState(JSON.stringify(incomplete))).toThrowError(StateFormatError);
    expect(() => decodePlannerState("{broken")).toThrowError(StateFormatError);

    const invalidCreature = JSON.parse(fixtureText) as Record<string, unknown>;
    delete (invalidCreature.players as Array<Record<string, unknown>>)[0]!.name;
    expect(() => decodePlannerState(JSON.stringify(invalidCreature))).toThrowError(StateFormatError);

    const invalidDate = JSON.parse(fixtureText) as Record<string, unknown>;
    (invalidDate.log as Array<Record<string, unknown>>)[0]!.date = "not-a-date";
    expect(() => decodePlannerState(JSON.stringify(invalidDate))).toThrowError(StateFormatError);
  });

  it("normalizes official statuses, custom statuses, database order and active selection", () => {
    const decoded = decodePlannerState(fixtureText);
    decoded.monsterDatabase.push({ ...decoded.monsterDatabase[0]!, id: "aal", name: "Aal" });
    decoded.activeID = "99999999-9999-9999-9999-999999999999";

    const normalized = normalizePlannerState(decoded);

    expect(normalized.monsterDatabase.map((monster) => monster.name)).toEqual(["Aal", "Nebelweber"]);
    expect(normalized.statuses).toHaveLength(28);
    expect(normalized.statuses.at(-1)?.id).toBe("glowing");
    expect(normalized.activeID).toBe("11111111-1111-1111-1111-111111111111");
  });

  it("orders initiative by score, manual tie break, bonus and name", () => {
    const state = decodePlannerState(fixtureText);
    expect(initiativeList(state).map((creature) => creature.name)).toEqual(["Älva 🧙", "Nebelweber 1"]);
  });

  it("round-trips the fixture semantically while discarding unknown keys", () => {
    const raw = JSON.parse(fixtureText) as Record<string, unknown>;
    raw.windowsOnly = "ignored";
    const encoded = encodePlannerState(decodePlannerState(JSON.stringify(raw)));
    const reparsed = JSON.parse(encoded) as Record<string, unknown>;

    expect(reparsed.windowsOnly).toBeUndefined();
    expect(decodePlannerState(encoded)).toEqual(decodePlannerState(fixtureText));
  });
});
