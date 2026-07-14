import { describe, expect, it } from "vitest";
import { MonsterImportError, importMonsters } from "../src/domain/monsterImporter";

describe("importMonsters", () => {
  it("imports Obsidian frontmatter as one permanent monster", () => {
    const text = `---
name: Schattenwolf
rk: 14
tp: 45 (6d10+12)
hg: 3
initiative: +3
typ: Bestie
notizen: Rudeljäger
---`;
    const monsters = importMonsters(text, "Bestiarium.md", () => "2026-01-01T00:00:00Z");

    expect(monsters).toHaveLength(1);
    expect(monsters[0]).toMatchObject({ name: "Schattenwolf", armorClass: 14, hpAverage: 45, hpDice: "6d10+12", challengeRating: "3", initiativeBonus: 3 });
  });

  it("imports key/value and compact text blocks without duplicate IDs", () => {
    const text = `Name: Kristallspinne
AC: 16
HP: 58 (9d8+18)
CR: 4
Initiative: +2
Type: Konstrukt


###

Kristallspinne
RK 16; TP 58 (9W8+18); HG 4; Ini +2; Typ Konstrukt`;
    const monsters = importMonsters(text, "Paste", () => "2026-01-01T00:00:00Z");

    expect(monsters).toHaveLength(1);
    expect(monsters[0]).toMatchObject({ name: "Kristallspinne", type: "Konstrukt", hpDice: "9d8+18" });
  });

  it("builds the full statblock and ignores code/lore phantom entries", () => {
    const text = `---
name: Testdrache
untertitel: Drache der Prüfung
typ: Drache (metallisch)
größe: Riesig
gesinnung: Rechtschaffen gut
rk: 19
tp: "243 (18W12+126)"
initiative: "+14 (24)"
bewegungsrate: "12 m, Fliegen 24 m"
stä: 27
stä_mod: "+8"
stä_rw: "+8"
ges: 14
ges_mod: "+2"
ges_rw: "+8"
kon: 25
kon_mod: "+7"
kon_rw: "+7"
int: 16
int_mod: "+3"
int_rw: "+3"
wei: 15
wei_mod: "+2"
wei_rw: "+8"
cha: 24
cha_mod: "+7"
cha_rw: "+7"
hg: 17
üb: "+6"
fertigkeiten: [Heimlichkeit +8, Wahrnehmung +14]
resistenzen: [Blitz, Kälte]
immunitäten: [Feuer]
sinne: [Blindsicht 18 m, Passive Wahrnehmung 24]
sprachen: [Drakonisch, Gemeinsprache]
---

\`\`\`dataviewjs
const p = dv.current(); // RK 5
\`\`\`

# Testdrache
Lore mit 45 (6d10+12) TP.

## Merkmale
**Amphibisch:** Der Drache kann Luft und Wasser atmen.
**Legendäre Resistenz (3-mal täglich):** Bei gescheitertem Rettungswurf bestehen.

## Aktionen
**Mehrfachangriff:** Drei Angriffe.
**Feuerodem (Aufladung 5–6):** *Geschicklichkeitsrettungswurf:* SG 21.
**Zauberwirken:** Der Drache wirkt Zauber:
- **Beliebig oft:** *Magie entdecken*, *Gestaltwandel*
- **Je 1-mal täglich:** *Flammenschlag*

## Bonusaktionen
**Teleportieren:** Bis zu 18 m.

## Reaktionen
**Parieren:** +2 RK.

## Legendäre Aktionen
*Anwendungen legendärer Aktionen: 3.*
**Anspringen:** Halbe Bewegungsrate.`;
    const [monster] = importMonsters(text, "Testdrache.md", () => "2026-01-01T00:00:00Z");
    const statblock = monster?.statblock;

    expect(statblock?.abilities).toHaveLength(6);
    expect(statblock?.resistances).toBe("Blitz, Kälte");
    expect(statblock?.traits).toHaveLength(2);
    expect(statblock?.actions.find((entry) => entry.name === "Zauberwirken")?.text).toContain("Beliebig oft");
    expect(statblock?.actions.some((entry) => entry.name === "Beliebig oft")).toBe(false);
    expect(statblock?.bonusActions[0]?.name).toBe("Teleportieren");
    expect(statblock?.legendaryIntro).toContain("Anwendungen legendärer Aktionen");
  });

  it("rejects empty and unrecognized input", () => {
    expect(() => importMonsters("   ")).toThrowError(new MonsterImportError("empty"));
    expect(() => importMonsters("Nur eine Sitzungsnotiz ohne Werte")).toThrowError(new MonsterImportError("noMonstersFound"));
  });
});
