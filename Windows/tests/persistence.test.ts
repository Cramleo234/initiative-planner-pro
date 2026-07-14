import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { decodePlannerState, normalizePlannerState } from "../src/domain/models";
import { loadStateFile, saveStateFileAtomic } from "../electron/persistence";

const fixturePath = resolve(import.meta.dirname, "../../Fixtures/planner-state-v1.json");
const fixtureState = decodePlannerState(readFileSync(fixturePath, "utf8"));

describe("state-file persistence", () => {
  it("writes atomically and loads the complete golden fixture", async () => {
    const directory = mkdtempSync(join(tmpdir(), "initiative-planner-persistence-"));
    const file = join(directory, "planner-state.json");

    await saveStateFileAtomic(file, fixtureState);
    const loaded = await loadStateFile(file);

    expect(loaded.recovery).toBeNull();
    expect(loaded.state).toEqual(normalizePlannerState(fixtureState));
    expect(readFileSync(file, "utf8")).toContain("Älva 🧙");
  });

  it("backs up corrupt or incompatible data before returning a default state", async () => {
    const directory = mkdtempSync(join(tmpdir(), "initiative-planner-recovery-"));
    const file = join(directory, "planner-state.json");
    writeFileSync(file, "{broken", "utf8");

    const loaded = await loadStateFile(file, { now: () => new Date("2026-02-03T04:05:06Z") });

    expect(loaded.state.players).toHaveLength(0);
    expect(loaded.recovery?.backupPath).toMatch(/planner-state\.incompatible-20260203T040506Z\.json$/);
    expect(readFileSync(loaded.recovery!.backupPath, "utf8")).toBe("{broken");
  });

  it("loads a missing file without reporting recovery", async () => {
    const directory = mkdtempSync(join(tmpdir(), "initiative-planner-missing-"));
    const loaded = await loadStateFile(join(directory, "planner-state.json"));
    expect(loaded.recovery).toBeNull();
    expect(loaded.state.selectedTheme).toBe("ember");
  });
});
