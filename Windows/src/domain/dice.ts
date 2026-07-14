export type DiceErrorCode = "invalidExpression" | "tooManyDice" | "invalidSides";

const ERROR_MESSAGES: Record<DiceErrorCode, string> = {
  invalidExpression: "Ungültiger Würfelausdruck",
  tooManyDice: "Zu viele Würfel in einem Ausdruck",
  invalidSides: "Ungültige Würfelseiten",
};

export class DiceError extends Error {
  readonly code: DiceErrorCode;

  constructor(code: DiceErrorCode) {
    super(ERROR_MESSAGES[code]);
    this.name = "DiceError";
    this.code = code;
  }
}

export interface DiceRoll {
  total: number;
  detail: string;
  rolls: number[];
}

export function rollDice(
  expression: string,
  random: (sides: number) => number = (sides) => Math.floor(Math.random() * sides) + 1,
): DiceRoll {
  let input = expression.trim().replace(/[Ww]/g, "d").replace(/−/g, "-").replace(/ /g, "");
  if (!input) return { total: 0, detail: "0", rolls: [] };
  if (/^[+-]?\d+$/.test(input)) {
    const value = Number.parseInt(input, 10);
    return { total: value, detail: String(value), rolls: [] };
  }
  if (!input.startsWith("+") && !input.startsWith("-")) input = `+${input}`;

  const pattern = /([+-])(?:(\d*)d(\d+)|(\d+))/gi;
  let cursor = 0;
  let total = 0;
  const details: string[] = [];
  const rolls: number[] = [];
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(input)) !== null) {
    if (match.index !== cursor) throw new DiceError("invalidExpression");
    cursor = pattern.lastIndex;
    const sign = match[1] === "-" ? -1 : 1;
    if (match[3] !== undefined) {
      const count = Math.max(1, Number.parseInt(match[2] || "1", 10));
      const sides = Number.parseInt(match[3], 10);
      if (count > 500) throw new DiceError("tooManyDice");
      if (sides <= 0) throw new DiceError("invalidSides");
      const local: number[] = [];
      for (let index = 0; index < count; index += 1) {
        const value = Math.max(1, Math.min(sides, Math.trunc(random(sides))));
        local.push(value);
        rolls.push(sign * value);
        total += sign * value;
      }
      details.push(`${sign < 0 ? "-" : "+"}${count}d${sides}[${local.join(",")}]`);
    } else {
      const value = Number.parseInt(match[4], 10);
      total += sign * value;
      details.push(`${sign < 0 ? "-" : "+"}${value}`);
    }
  }

  if (cursor !== input.length || cursor === 0) throw new DiceError("invalidExpression");
  return { total, detail: details.join("").replace(/^\+/, ""), rolls };
}
