import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { createDefaultState } from "../src/domain/models";
import { PlannerStore } from "../src/domain/store";
import { App, createBlankMonster } from "../src/renderer/App";
import { PlayerView } from "../src/renderer/PlayerView";

function makeStore(): PlannerStore {
  let id = 0;
  return new PlannerStore({
    load: null,
    randomUUID: () => `30000000-0000-0000-0000-${String(++id).padStart(12, "0")}`,
    now: () => "2026-03-04T05:06:07Z",
    monotonicNow: (() => { let time = 0; return () => (time += 1000); })(),
  });
}

describe("renderer shell", () => {
  it("renders the product version, five tabs and focuses player creation on command", async () => {
    const store = makeStore();
    render(<App store={store} />);

    expect(screen.getByText("Initiative Planner Pro")).toBeInTheDocument();
    expect(screen.getByText("Version 0.9.1-beta.1")).toBeInTheDocument();
    for (const tab of ["Kampf", "Monster", "Encounters", "Status", "Protokoll"]) expect(screen.getByRole("button", { name: tab })).toBeInTheDocument();

    window.dispatchEvent(new CustomEvent("planner:add-player"));
    expect(screen.getByLabelText("Name")).toHaveFocus();
    await userEvent.type(screen.getByLabelText("Name"), "Älva");
    await userEvent.click(screen.getByRole("button", { name: "Hinzufügen" }));
    expect(screen.getByText("Älva")).toBeInTheDocument();
  });

  it("handles combat shortcuts without allowing Ctrl+R reload", () => {
    const store = makeStore();
    store.addCreature({ name: "Goblin", kind: "monster", armorClass: 15, hpExpression: "7", initiativeBonus: 2, initiative: null });
    render(<App store={store} />);
    const event = new KeyboardEvent("keydown", { key: "r", ctrlKey: true, cancelable: true });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
    expect(store.state.monsters[0]?.currentInitiative).not.toBeNull();

    const themeEvent = new KeyboardEvent("keydown", { key: "t", ctrlKey: true, shiftKey: true, cancelable: true });
    window.dispatchEvent(themeEvent);
    expect(themeEvent.defaultPrevented).toBe(true);
    expect(store.state.selectedTheme).toBe("obsidian");
  });

  it("exposes temporary HP and status duration controls on creature cards", async () => {
    const store = makeStore();
    store.addCreature({ name: "Älva", kind: "player", armorClass: 17, hpExpression: "31", initiativeBonus: 3, initiative: 18 });
    const id = store.state.players[0]!.id;
    store.toggleStatus("concentration", id, 2);
    render(<App store={store} />);

    const tempHP = screen.getByLabelText("Älva Temporäre HP");
    await userEvent.clear(tempHP);
    await userEvent.type(tempHP, "6");
    await userEvent.click(screen.getByRole("button", { name: "Älva Temp setzen" }));
    expect(store.state.players[0]?.temporaryHitPoints).toBe(6);

    const duration = screen.getByLabelText("Konzentration Dauer");
    await userEvent.clear(duration);
    await userEvent.type(duration, "4");
    fireEvent.blur(duration);
    expect(store.state.players[0]?.statuses[0]?.duration).toBe(4);
  });

  it("supports tab navigation and visible status search", async () => {
    render(<App store={makeStore()} />);
    await userEvent.click(screen.getByRole("button", { name: "Status" }));
    const search = screen.getByPlaceholderText("Status suchen");
    await userEvent.type(search, "blind");
    expect(screen.getAllByText("Blind")).not.toHaveLength(0);
    expect(screen.queryByText("Vergiftet")).not.toBeInTheDocument();
  });

  it("creates fully configured custom statuses", async () => {
    const store = makeStore();
    render(<App store={store} />);
    await userEvent.click(screen.getByRole("button", { name: "Status" }));
    await userEvent.type(screen.getByLabelText("Statusname"), "Markiert");
    await userEvent.type(screen.getByLabelText("Kurzform"), "Mark");
    await userEvent.selectOptions(screen.getByLabelText("Kategorie"), "mental");
    await userEvent.selectOptions(screen.getByLabelText("Polung"), "bad");
    await userEvent.clear(screen.getByLabelText("Priorität"));
    await userEvent.type(screen.getByLabelText("Priorität"), "6");
    await userEvent.type(screen.getByLabelText("Beschreibung"), "Leuchtet für Verfolger.");
    await userEvent.type(screen.getByLabelText("Regelwirkungen"), "Angriffe im Vorteil\nKeine Unsichtbarkeit");
    await userEvent.click(screen.getByRole("button", { name: "Status speichern" }));

    expect(store.state.statuses.at(-1)).toMatchObject({
      label: "Markiert", short: "Mark", category: "mental", polarity: "bad", priority: 6,
      description: "Leuchtet für Verfolger.", effects: ["Angriffe im Vorteil", "Keine Unsichtbarkeit"],
    });
  });

  it("renders complete imported statblocks", async () => {
    const store = makeStore();
    const monster = createBlankMonster("Nebelweber");
    monster.statblock = {
      ...monster.statblock!, subtitle: "Weber zwischen Welten", size: "Groß", alignment: "Neutral böse", habitat: "Unterreich",
      speed: "9 m", senses: "Dunkelsicht", languages: "Tiefensprache", skills: "Heimlichkeit +7",
      resistances: "Psychisch", immunities: "Bezaubert", vulnerabilities: "Gleißend", equipment: "Netz", xp: "1.100", proficiency: "+2",
      abilities: [{ label: "STÄ", score: 16, mod: "+3", save: "+3" }],
      traits: [{ name: "Spinnenklettern", text: "Klettert an Wänden." }], actions: [{ name: "Biss", text: "2W8+3 Giftschaden." }],
      bonusActions: [{ name: "Schattenritt", text: "Teleportiert sich." }], reactions: [{ name: "Parade", text: "+2 RK." }],
      legendaryActions: [{ name: "Netzwurf", text: "Setzt ein Ziel fest." }], legendaryIntro: "Zwei legendäre Aktionen.",
    };
    store.saveMonsterTemplate(monster);
    render(<App store={store} />);
    await userEvent.click(screen.getByRole("button", { name: "Monster" }));
    await userEvent.click(screen.getByRole("button", { name: /Nebelweber/ }));

    for (const text of ["Weber zwischen Welten", "Unterreich", "STÄ", "Spinnenklettern", "Biss", "Schattenritt", "Parade", "Netzwurf"]) {
      expect(screen.getByText(text)).toBeInTheDocument();
    }
  });
});

describe("PlayerView privacy", () => {
  it("shows player HP but never monster HP", () => {
    const state = createDefaultState(() => "2026-03-04T05:06:07Z");
    state.players.push({
      id: "player", name: "Älva", kind: "player", armorClass: 17, hitPoints: 23, maxHitPoints: 31,
      temporaryHitPoints: 0, initiativeBonus: 3, currentInitiative: 18, tieBreak: 0,
      deathSaveSuccesses: null, deathSaveFailures: null, statuses: [], notes: "", sourceMonsterID: null,
    });
    state.monsters.push({
      id: "monster", name: "Nebelweber", kind: "monster", armorClass: 15, hitPoints: 35, maxHitPoints: 42,
      temporaryHitPoints: 0, initiativeBonus: 2, currentInitiative: 12, tieBreak: 0,
      deathSaveSuccesses: null, deathSaveFailures: null, statuses: [], notes: "", sourceMonsterID: null,
    });
    state.activeID = "player";
    state.players[0]!.statuses = [{ id: "concentration", duration: 2, note: "" }];
    render(<PlayerView state={state} />);
    expect(screen.getAllByText("23 / 31 TP")).not.toHaveLength(0);
    expect(screen.queryByText("35 / 42 TP")).not.toBeInTheDocument();
    expect(screen.getByText("Spieleransicht · ohne versteckte DM-Werte")).toBeInTheDocument();
    expect(screen.getAllByText("Konzentration")).not.toHaveLength(0);
    expect(screen.queryByText("concentration")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Vollbild" }));
  });
});
