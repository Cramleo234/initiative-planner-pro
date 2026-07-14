import { describe, expect, it } from "vitest";
import { DiceError, rollDice } from "../src/domain/dice";

describe("rollDice", () => {
  it("rolls d notation with deterministic randomness", () => {
    const values = [3, 4];
    const result = rollDice("2d6+3", () => values.shift() ?? 1);

    expect(result).toEqual({ total: 10, detail: "2d6[3,4]+3", rolls: [3, 4] });
  });

  it("supports German W notation and negative modifiers", () => {
    expect(rollDice("1W8-2", () => 5).total).toBe(3);
  });

  it("accepts empty and plain integer expressions", () => {
    expect(rollDice("   ")).toEqual({ total: 0, detail: "0", rolls: [] });
    expect(rollDice("-12")).toEqual({ total: -12, detail: "-12", rolls: [] });
  });

  it("rejects malformed expressions, too many dice and invalid sides", () => {
    expect(() => rollDice("abc")).toThrowError(new DiceError("invalidExpression"));
    expect(() => rollDice("501d6")).toThrowError(new DiceError("tooManyDice"));
    expect(() => rollDice("d0")).toThrowError(new DiceError("invalidSides"));
  });

  it("clamps injected random values to the die range", () => {
    expect(rollDice("2d6", () => 99).rolls).toEqual([6, 6]);
    expect(rollDice("-d6", () => 0).rolls).toEqual([-1]);
  });
});
