import { useEffect, useMemo, useRef, useState, useSyncExternalStore, type DragEvent, type FormEvent } from "react";
import type { Creature, CreatureKind, HPMode, MonsterTemplate, PlannerState, StatBlock, StatusDefinition, StatusPolarity } from "../domain/models";
import { challengeRatingValue, createEmptyStatBlock, PLANNER_THEMES, slugifyMonsterID } from "../domain/models";
import { PlannerStore } from "../domain/store";

const VERSION = "0.9.0";
const tabs = ["Kampf", "Monster", "Encounters", "Status", "Protokoll"] as const;
type Tab = (typeof tabs)[number];


function useStore(store: PlannerStore): PlannerState {
  return useSyncExternalStore((listener) => store.subscribe(listener), () => store.state, () => store.state);
}

export function App({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  const [tab, setTab] = useState<Tab>("Kampf");
  const nameInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const focusPlayer = () => {
      setTab("Kampf");
      if (nameInput.current) nameInput.current.focus();
      else requestAnimationFrame(() => nameInput.current?.focus());
    };
    const keydown = (event: KeyboardEvent) => {
      if (event.ctrlKey && event.key.toLowerCase() === "n") { event.preventDefault(); focusPlayer(); return; }
      if (event.ctrlKey && event.key.toLowerCase() === "r") { event.preventDefault(); store.rollAllMonsterInitiative(); return; }
      if (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === "t") { event.preventDefault(); store.nextTheme(); return; }
      const editing = event.target instanceof Element && event.target.matches("input, textarea, select, [contenteditable='true']");
      if (!editing && event.code === "Space") { event.preventDefault(); store.nextTurn(); }
      if (!editing && event.key === "ArrowLeft") { event.preventDefault(); store.previousTurn(); }
    };
    window.addEventListener("planner:add-player", focusPlayer);
    window.addEventListener("keydown", keydown);
    return () => {
      window.removeEventListener("planner:add-player", focusPlayer);
      window.removeEventListener("keydown", keydown);
    };
  }, [store]);

  const active = state.players.concat(state.monsters).find((creature) => creature.id === state.activeID);
  return (
    <div className={`app theme-${state.selectedTheme}`} data-theme={state.selectedTheme}>
      <InitiativeRail store={store} />
      <aside className="sidebar">
        <div className="brand"><span className="brand-mark">⚔️</span><div><strong>Initiative Planner Pro</strong><small>Version {VERSION}</small></div></div>
        <nav>{tabs.map((item) => <button type="button" key={item} className={tab === item ? "selected" : ""} onClick={() => setTab(item)}>{item}</button>)}</nav>
        <div className="sidebar-spacer" />
        <label className="theme-picker">Theme<select value={state.selectedTheme} onChange={(event) => store.setTheme(event.target.value)}>{PLANNER_THEMES.map((theme) => <option key={theme.id} value={theme.id}>{theme.name}</option>)}</select></label>
        <div className="toolbar-buttons">
          <button type="button" disabled={!store.canUndo} onClick={() => store.undo()}>↶ Undo</button>
          <button type="button" disabled={!store.canRedo} onClick={() => store.redo()}>↷ Redo</button>
          <button type="button" onClick={() => void window.plannerAPI?.openPlayerView()}>◉ Player View</button>
        </div>
        <p className="import-hint">Monster lassen sich als Markdown/Text, Datei, Ordner oder per Drag & Drop importieren.</p>
      </aside>
      <main className="content">
        <header className="content-title"><div><small>AM ZUG</small><h1>{active?.name ?? "Noch niemand"}</h1></div><span>Runde {state.round}</span></header>
        {tab === "Kampf" && <CombatView store={store} nameInput={nameInput} />}
        {tab === "Monster" && <MonsterView store={store} />}
        {tab === "Encounters" && <EncounterView store={store} />}
        {tab === "Status" && <StatusLibrary store={store} />}
        {tab === "Protokoll" && <LogView store={store} />}
      </main>
      {store.lastNotice && <div className={`toast ${store.lastNotice.style}`} role="status">{store.lastNotice.message}</div>}
      {store.concentrationChecks[0] && <ConcentrationDialog store={store} />}
    </div>
  );
}

function InitiativeRail({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  return (
    <header className="initiative-rail">
      <button type="button" className="round-pill" onContextMenu={(event) => { event.preventDefault(); store.resetRound(); }}><small>RUNDE</small><strong>{state.round}</strong></button>
      <button type="button" onClick={() => store.previousTurn()} aria-label="Vorheriger Zug">←</button>
      <button type="button" className="next-turn" onClick={() => store.nextTurn()}>Nächster Zug →</button>
      <button type="button" onClick={() => store.rollAllMonsterInitiative()}>🎲 Monster-Ini</button>
      <div className="initiative-list">
        {store.initiativeList.map((creature) => (
          <button
            type="button" draggable key={creature.id}
            className={`initiative-token ${creature.id === state.activeID ? "active" : ""}`}
            onClick={() => store.setActive(creature.id)}
            onDragStart={(event) => event.dataTransfer.setData("application/x-initiative-id", creature.id)}
            onDragOver={(event) => event.preventDefault()}
            onDrop={(event) => store.moveCreature(event.dataTransfer.getData("application/x-initiative-id"), creature.id)}
          ><b>{creature.currentInitiative}</b><span>{creature.kind === "player" ? "🧙" : "👹"} {creature.name}</span><small>RK {creature.armorClass} · {creature.hitPoints}/{creature.maxHitPoints} TP</small></button>
        ))}
      </div>
    </header>
  );
}

function CombatView({ store, nameInput }: { store: PlannerStore; nameInput: React.RefObject<HTMLInputElement | null> }) {
  const state = useStore(store);
  const [kind, setKind] = useState<CreatureKind>("player");
  const [name, setName] = useState("");
  const [armorClass, setArmorClass] = useState(10);
  const [hp, setHP] = useState("10");
  const [bonus, setBonus] = useState(0);
  const [initiative, setInitiative] = useState("");
  const submit = (event: FormEvent) => {
    event.preventDefault();
    const added = store.addCreature({ name, kind, armorClass, hpExpression: hp, initiativeBonus: bonus, initiative: initiative === "" ? null : Number(initiative) });
    if (added) setName("");
  };
  return (
    <section className="view combat-view">
      <form className="glass-card add-creature" onSubmit={submit}>
        <div className="section-heading"><div><small>NEUER KÄMPFER</small><h2>Spieler oder Monster hinzufügen</h2></div><div className="segmented"><button type="button" aria-label="Typ: Spieler" className={kind === "player" ? "selected" : ""} onClick={() => setKind("player")}>Spieler</button><button type="button" aria-label="Typ: Monster" className={kind === "monster" ? "selected" : ""} onClick={() => setKind("monster")}>Monster</button></div></div>
        <div className="form-row">
          <label>Name<input ref={nameInput} aria-label="Name" value={name} onChange={(event) => setName(event.target.value)} placeholder="Name" /></label>
          <label>RK<input type="number" min={1} max={40} value={armorClass} onChange={(event) => setArmorClass(Number(event.target.value))} /></label>
          <label>TP / Würfel<input value={hp} onChange={(event) => setHP(event.target.value)} placeholder="2d8+4" /></label>
          <label>Ini-Bonus<input type="number" min={-10} max={20} value={bonus} onChange={(event) => setBonus(Number(event.target.value))} /></label>
          <label>Initiative<input type="number" value={initiative} onChange={(event) => setInitiative(event.target.value)} /></label>
          <button className="primary" type="submit">Hinzufügen</button>
        </div>
      </form>
      <div className="quick-controls glass-card"><span>{state.players.length} Spieler · {state.monsters.length} Monster · {state.monsters.filter((monster) => monster.hitPoints <= 0).length} besiegt</span><button type="button" onClick={() => store.removeDefeatedMonsters()}>Besiegte aufräumen</button><button type="button" onClick={() => store.clearCombat()}>Kampf leeren</button></div>
      <div className="creature-grid">{state.players.concat(state.monsters).map((creature) => <CreatureCard key={creature.id} store={store} creature={creature} />)}</div>
      {state.players.length + state.monsters.length === 0 && <div className="empty-state glass-card"><h2>Noch keine Kämpfer</h2><p>Füge oben Spieler oder Monster hinzu.</p></div>}
    </section>
  );
}

function CreatureCard({ store, creature }: { store: PlannerStore; creature: Creature }) {
  const state = useStore(store);
  const [amount, setAmount] = useState("1");
  const [temporaryHP, setTemporaryHP] = useState(String(creature.temporaryHitPoints));
  const [statusID, setStatusID] = useState("");
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState({
    name: creature.name, armorClass: creature.armorClass, hitPoints: creature.hitPoints,
    maxHitPoints: creature.maxHitPoints, initiativeBonus: creature.initiativeBonus,
    currentInitiative: creature.currentInitiative === null ? "" : String(creature.currentInitiative), notes: creature.notes,
  });
  const statusLabels = new Map(state.statuses.map((status) => [status.id, status.label]));
  return (
    <article className={`glass-card creature-card ${state.activeID === creature.id ? "active" : ""}`}>
      <header><button type="button" className="creature-title" onClick={() => store.setActive(creature.id)}><span>{creature.kind === "player" ? "🧙" : "👹"}</span><div><h2>{creature.name}</h2><small>RK {creature.armorClass} · Ini {creature.currentInitiative ?? "—"}</small></div></button><div><button type="button" onClick={() => setEditing(!editing)} aria-label={`${creature.name} bearbeiten`}>✎</button><button type="button" onClick={() => store.duplicateCreature(creature.id)} aria-label={`${creature.name} duplizieren`}>⧉</button><button type="button" onClick={() => store.deleteCreature(creature.id)} aria-label={`${creature.name} entfernen`}>×</button></div></header>
      {editing && <form className="creature-editor" onSubmit={(event) => { event.preventDefault(); store.updateCreature(creature.id, { ...draft, currentInitiative: draft.currentInitiative === "" ? null : Number(draft.currentInitiative) }); setEditing(false); }}><label>Name<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label><label>RK<input type="number" value={draft.armorClass} onChange={(event) => setDraft({ ...draft, armorClass: Number(event.target.value) })} /></label><label>TP<input type="number" value={draft.hitPoints} onChange={(event) => setDraft({ ...draft, hitPoints: Number(event.target.value) })} /></label><label>Max<input type="number" value={draft.maxHitPoints} onChange={(event) => setDraft({ ...draft, maxHitPoints: Number(event.target.value) })} /></label><label>Ini<input type="number" value={draft.currentInitiative} onChange={(event) => setDraft({ ...draft, currentInitiative: event.target.value })} /></label><label>Bonus<input type="number" value={draft.initiativeBonus} onChange={(event) => setDraft({ ...draft, initiativeBonus: Number(event.target.value) })} /></label><label className="editor-notes">Notizen<textarea value={draft.notes} onChange={(event) => setDraft({ ...draft, notes: event.target.value })} /></label><button className="primary" type="submit">Speichern</button></form>}
      <div className="hp-summary"><strong>{creature.hitPoints}</strong><span>/ {creature.maxHitPoints} TP</span>{creature.temporaryHitPoints > 0 && <b>+{creature.temporaryHitPoints} temp.</b>}</div>
      <progress max={Math.max(1, creature.maxHitPoints)} value={creature.hitPoints} />
      <div className="quick-hp">{[-10, -5, -1, 1, 5].map((delta) => <button type="button" key={delta} onClick={() => store.applyQuickHP(creature.id, delta)}>{delta > 0 ? `+${delta}` : delta}</button>)}</div>
      <div className="hp-form"><input aria-label={`${creature.name} TP-Ausdruck`} value={amount} onChange={(event) => setAmount(event.target.value)} /><button type="button" onClick={() => store.applyDamage(creature.id, amount)}>Schaden</button><button type="button" onClick={() => store.applyHealing(creature.id, amount)}>Heilen</button></div>
      <div className="temp-hp-form"><input type="number" min={0} aria-label={`${creature.name} Temporäre HP`} value={temporaryHP} onChange={(event) => setTemporaryHP(event.target.value)} /><button type="button" aria-label={`${creature.name} Temp setzen`} onClick={() => store.setTemporaryHP(creature.id, Number(temporaryHP))}>Temp setzen</button></div>
      <div className="status-chips">{creature.statuses.map((status) => {
        const label = statusLabels.get(status.id) ?? status.id;
        return <span className="status-control" key={status.id}><button type="button" className="status-chip" title={status.note} onClick={() => store.toggleStatus(status.id, creature.id)}>{label}</button><input type="number" min={0} max={99} placeholder="∞" aria-label={`${label} Dauer`} value={status.duration ?? ""} onChange={(event) => store.setStatusDuration(creature.id, status.id, event.target.value === "" ? null : Number(event.target.value))} /></span>;
      })}</div>
      <div className="status-add"><select aria-label={`${creature.name} Status`} value={statusID} onChange={(event) => setStatusID(event.target.value)}><option value="">Status setzen…</option>{state.statuses.map((status) => <option key={status.id} value={status.id}>{status.label}</option>)}</select><button type="button" onClick={() => { if (statusID) store.toggleStatus(statusID, creature.id); }}>Setzen</button></div>
      {creature.kind === "player" && creature.hitPoints === 0 && <DeathSaves store={store} creature={creature} />}
    </article>
  );
}

function DeathSaves({ store, creature }: { store: PlannerStore; creature: Creature }) {
  const successes = creature.deathSaveSuccesses ?? 0;
  const failures = creature.deathSaveFailures ?? 0;
  return <div className="death-saves"><span>Todesrettungen</span><div>Erfolge {[1, 2, 3].map((value) => <button type="button" key={value} className={value <= successes ? "filled" : ""} onClick={() => store.setDeathSaves(creature.id, value === successes ? value - 1 : value, failures)}>●</button>)}</div><div>Fehler {[1, 2, 3].map((value) => <button type="button" key={value} className={value <= failures ? "filled failure" : ""} onClick={() => store.setDeathSaves(creature.id, successes, value === failures ? value - 1 : value)}>●</button>)}</div></div>;
}

function MonsterView({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  const [search, setSearch] = useState("");
  const [cr, setCR] = useState("all");
  const [quantity, setQuantity] = useState(1);
  const [importText, setImportText] = useState("");
  const [source, setSource] = useState("Import");
  const [creating, setCreating] = useState(false);
  const filtered = state.monsterDatabase.filter((monster) => {
    const needle = search.toLocaleLowerCase("de-DE");
    const text = `${monster.name} ${monster.type} ${monster.source} ${monster.challengeRating} ${monster.notes}`.toLocaleLowerCase("de-DE");
    const value = challengeRatingValue(monster.challengeRating);
    return text.includes(needle) && (cr === "all" || (cr.endsWith("+") ? value >= Number(cr.slice(0, -1)) : monster.challengeRating === cr));
  });
  const importFiles = async () => {
    const files = await window.plannerAPI?.chooseMonsterFiles();
    if (files?.length) {
      const imported = await window.plannerAPI?.importMonsterPaths(files);
      for (const file of imported ?? []) store.importMonsterText(file.text, file.source);
    }
  };
  const importFolder = async () => {
    const folders = await window.plannerAPI?.chooseMonsterFolder();
    if (folders?.length) {
      const imported = await window.plannerAPI?.importMonsterPaths(folders);
      for (const file of imported ?? []) store.importMonsterText(file.text, file.source);
    }
  };
  const drop = async (event: DragEvent) => {
    event.preventDefault();
    const paths = Array.from(event.dataTransfer.files).map((file) => window.plannerAPI?.pathForFile(file)).filter((path): path is string => Boolean(path));
    if (paths.length) {
      const imported = await window.plannerAPI?.importMonsterPaths(paths);
      for (const file of imported ?? []) store.importMonsterText(file.text, file.source);
    }
  };
  return (
    <section className="view monster-view" onDragOver={(event) => event.preventDefault()} onDrop={(event) => void drop(event)}>
      <div className="glass-card monster-toolbar"><input placeholder="Monster suchen" value={search} onChange={(event) => setSearch(event.target.value)} /><select value={cr} onChange={(event) => setCR(event.target.value)}><option value="all">Alle HG</option><option value="10+">10+</option><option value="15+">15+</option><option value="20+">20+</option></select><label>Menge<input type="number" min={1} max={50} value={quantity} onChange={(event) => setQuantity(Number(event.target.value))} /></label><select value={state.hpMode} onChange={(event) => store.setHPMode(event.target.value as HPMode)}><option value="average">Durchschnitt</option><option value="roll">Würfeln</option></select><button type="button" onClick={() => setCreating(!creating)}>Neu</button><button type="button" onClick={() => void importFiles()}>Datei importieren</button><button type="button" onClick={() => void importFolder()}>Ordner</button><button type="button" onClick={() => store.clearMonsterDatabase()}>Alle löschen</button></div>
      {creating && <MonsterEditor initial={createBlankMonster("Neues Monster")} onCancel={() => setCreating(false)} onSave={(monster) => { store.saveMonsterTemplate(monster); setCreating(false); }} />}
      <details className="glass-card import-panel"><summary>Markdown-/Text-Import</summary><label>Quelle<input value={source} onChange={(event) => setSource(event.target.value)} /></label><textarea value={importText} onChange={(event) => setImportText(event.target.value)} placeholder="Monsterdaten einfügen…" /><button type="button" onClick={() => store.importMonsterText(importText, source)}>Dauerhaft importieren</button></details>
      <div className="monster-list">{filtered.map((monster) => <MonsterRow key={monster.id} monster={monster} quantity={quantity} hpMode={state.hpMode} store={store} />)}</div>
      {filtered.length === 0 && <div className="empty-state glass-card"><h2>Keine Monster gefunden</h2><p>Importiere eigene Markdown-Dateien oder passe den Filter an.</p></div>}
    </section>
  );
}

function MonsterRow({ monster, quantity, hpMode, store }: { monster: MonsterTemplate; quantity: number; hpMode: HPMode; store: PlannerStore }) {
  const [expanded, setExpanded] = useState(false);
  const [editing, setEditing] = useState(false);
  return <article className="glass-card monster-row"><button type="button" className="monster-main" onClick={() => setExpanded(!expanded)}><div><h2>{monster.name}</h2><small>{monster.type || "Monster"} · {monster.source}</small></div><div><b>RK {monster.armorClass}</b><b>TP {monster.hpAverage}</b><b>HG {monster.challengeRating}</b></div></button><div className="monster-actions"><button type="button" onClick={() => store.addMonsterFromDatabase(monster, quantity, hpMode)}>{hpMode === "roll" ? "🎲 Würfeln" : "+ Durchschnitt"}</button><button type="button" onClick={() => setEditing(!editing)}>Bearbeiten</button><button type="button" onClick={() => store.deleteMonsterTemplate(monster.id)}>Löschen</button></div>{editing && <MonsterEditor initial={monster} onCancel={() => setEditing(false)} onSave={(updated) => { store.saveMonsterTemplate(updated); setEditing(false); }} />}{expanded && <div className="statblock">{monster.notes && <p>{monster.notes}</p>}{monster.statblock ? <StatBlockView statblock={monster.statblock} /> : <p>Keine weiteren Details hinterlegt.</p>}</div>}</article>;
}

function StatBlockView({ statblock }: { statblock: StatBlock }) {
  const metadata = [
    ["Größe", statblock.size], ["Gesinnung", statblock.alignment], ["Habitat", statblock.habitat], ["Bewegung", statblock.speed],
    ["Sinne", statblock.senses], ["Sprachen", statblock.languages], ["Fertigkeiten", statblock.skills], ["Resistenzen", statblock.resistances],
    ["Immunitäten", statblock.immunities], ["Anfälligkeiten", statblock.vulnerabilities], ["Ausrüstung", statblock.equipment], ["EP", statblock.xp], ["ÜB", statblock.proficiency],
  ].filter((entry) => entry[1]);
  const sections: Array<[string, StatBlock["actions"], string]> = [
    ["Merkmale", statblock.traits, ""], ["Aktionen", statblock.actions, ""], ["Bonusaktionen", statblock.bonusActions, ""],
    ["Reaktionen", statblock.reactions, ""], ["Legendäre Aktionen", statblock.legendaryActions, statblock.legendaryIntro],
  ];
  return <div className="statblock-content">
    {statblock.subtitle && <h3>{statblock.subtitle}</h3>}
    <dl className="statblock-meta">{metadata.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>
    {statblock.abilities.length > 0 && <div className="ability-grid">{statblock.abilities.map((ability) => <div key={ability.label}><strong>{ability.label}</strong><span>{ability.score}</span><small>{ability.mod} / RW {ability.save}</small></div>)}</div>}
    {sections.filter(([, items, intro]) => items.length > 0 || intro).map(([title, items, intro]) => <section className="statblock-section" key={title}><h3>{title}</h3>{intro && <p><em>{intro}</em></p>}{items.map((ability) => <p key={`${title}-${ability.name}`}><strong>{ability.name}</strong><span>{ability.text}</span></p>)}</section>)}
  </div>;
}

function MonsterEditor({ initial, onSave, onCancel }: { initial: MonsterTemplate; onSave: (monster: MonsterTemplate) => void; onCancel: () => void }) {
  const [draft, setDraft] = useState(initial);
  return <form className="monster-editor glass-card" onSubmit={(event) => { event.preventDefault(); onSave({ ...draft, name: draft.name.trim(), hpAverage: Math.max(1, draft.hpAverage), armorClass: Math.max(1, Math.min(40, draft.armorClass)), hpDice: draft.hpDice || "1d8", challengeRating: draft.challengeRating || "?" }); }}><label>Name<input value={draft.name} required onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label><label>RK<input type="number" value={draft.armorClass} onChange={(event) => setDraft({ ...draft, armorClass: Number(event.target.value) })} /></label><label>TP<input type="number" value={draft.hpAverage} onChange={(event) => setDraft({ ...draft, hpAverage: Number(event.target.value) })} /></label><label>TP-Würfel<input value={draft.hpDice} onChange={(event) => setDraft({ ...draft, hpDice: event.target.value })} /></label><label>HG<input value={draft.challengeRating} onChange={(event) => setDraft({ ...draft, challengeRating: event.target.value })} /></label><label>Ini-Bonus<input type="number" value={draft.initiativeBonus} onChange={(event) => setDraft({ ...draft, initiativeBonus: Number(event.target.value) })} /></label><label>Typ<input value={draft.type} onChange={(event) => setDraft({ ...draft, type: event.target.value })} /></label><label>Quelle<input value={draft.source} onChange={(event) => setDraft({ ...draft, source: event.target.value })} /></label><label className="editor-notes">Notizen<textarea value={draft.notes} onChange={(event) => setDraft({ ...draft, notes: event.target.value })} /></label><button type="button" onClick={onCancel}>Abbrechen</button><button className="primary" type="submit">Speichern</button></form>;
}

function EncounterView({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  const [name, setName] = useState("");
  return <section className="view"><form className="glass-card encounter-form" onSubmit={(event) => { event.preventDefault(); store.saveEncounter(name); setName(""); }}><input placeholder="Encounter-Name" value={name} onChange={(event) => setName(event.target.value)} /><button className="primary" type="submit">Encounter speichern</button></form><div className="encounter-list">{state.encounters.map((encounter) => <article className="glass-card encounter-row" key={encounter.id}><div><h2>{encounter.name}</h2><small>Runde {encounter.round} · {encounter.players.length} Spieler · {encounter.monsters.length} Monster · {new Date(encounter.savedAt).toLocaleString("de-DE")}</small></div><button type="button" onClick={() => store.loadEncounter(encounter)}>Laden</button><button type="button" onClick={() => store.deleteEncounter(encounter.id)}>Löschen</button></article>)}</div></section>;
}

function StatusLibrary({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  const [search, setSearch] = useState("");
  const [draft, setDraft] = useState({ label: "", short: "", category: "physical", priority: 1, polarity: "bad" as StatusPolarity, description: "", effects: "" });
  const visible = useMemo(() => state.statuses.filter((status) => `${status.label} ${status.description}`.toLocaleLowerCase("de-DE").includes(search.toLocaleLowerCase("de-DE"))).sort((left, right) => right.priority - left.priority || left.label.localeCompare(right.label, "de-DE")), [search, state.statuses]);
  const add = (event: FormEvent) => {
    event.preventDefault();
    store.addStatus({ ...draft, effects: draft.effects.split("\n").map((effect) => effect.trim()).filter(Boolean) });
    setDraft({ label: "", short: "", category: "physical", priority: 1, polarity: "bad", description: "", effects: "" });
  };
  return <section className="view"><div className="glass-card status-toolbar"><input placeholder="Status suchen" value={search} onChange={(event) => setSearch(event.target.value)} /></div><form className="glass-card status-create" onSubmit={add}><label>Statusname<input aria-label="Statusname" value={draft.label} onChange={(event) => setDraft({ ...draft, label: event.target.value })} /></label><label>Kurzform<input aria-label="Kurzform" value={draft.short} onChange={(event) => setDraft({ ...draft, short: event.target.value })} /></label><label>Kategorie<select aria-label="Kategorie" value={draft.category} onChange={(event) => setDraft({ ...draft, category: event.target.value })}>{["physical", "mental", "movement", "critical", "incapacitated", "concentration", "good", "custom"].map((category) => <option key={category} value={category}>{category}</option>)}</select></label><label>Polung<select aria-label="Polung" value={draft.polarity} onChange={(event) => setDraft({ ...draft, polarity: event.target.value as StatusPolarity })}><option value="good">gut / hilfreich</option><option value="bad">schlecht / hinderlich</option></select></label><label>Priorität<input aria-label="Priorität" type="number" min={0} max={10} value={draft.priority} onChange={(event) => setDraft({ ...draft, priority: Number(event.target.value) })} /></label><label className="wide">Beschreibung<textarea aria-label="Beschreibung" value={draft.description} onChange={(event) => setDraft({ ...draft, description: event.target.value })} /></label><label className="wide">Regelwirkungen<textarea aria-label="Regelwirkungen" value={draft.effects} onChange={(event) => setDraft({ ...draft, effects: event.target.value })} /></label><button className="primary" type="submit" aria-label="Status speichern">Status speichern</button></form><div className="status-library">{visible.map((status) => <StatusCard key={status.id} status={status} store={store} />)}</div></section>;
}

function StatusCard({ status, store }: { status: StatusDefinition; store: PlannerStore }) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState({ ...status, effectsText: status.effects.join("\n") });
  return <article className={`glass-card status-card ${status.polarity}`}><header><span className="status-chip">{status.short}</span><div><h2>{status.label}</h2><small>{status.category} · Priorität {status.priority}</small></div>{!status.isOfficial && <><button type="button" onClick={() => setEditing(!editing)}>Bearbeiten</button><button type="button" onClick={() => store.deleteStatus(status.id)}>Löschen</button></>}</header>{editing ? <form className="status-editor" onSubmit={(event) => { event.preventDefault(); store.updateStatus({ ...draft, effects: draft.effectsText.split("\n").map((effect) => effect.trim()).filter(Boolean) }); setEditing(false); }}><label>Name<input value={draft.label} onChange={(event) => setDraft({ ...draft, label: event.target.value })} /></label><label>Kurzform<input value={draft.short} onChange={(event) => setDraft({ ...draft, short: event.target.value })} /></label><label>Kategorie<input value={draft.category} onChange={(event) => setDraft({ ...draft, category: event.target.value })} /></label><label>Polung<select value={draft.polarity} onChange={(event) => setDraft({ ...draft, polarity: event.target.value as StatusPolarity })}><option value="good">gut</option><option value="bad">schlecht</option></select></label><label>Priorität<input type="number" min={0} max={10} value={draft.priority} onChange={(event) => setDraft({ ...draft, priority: Number(event.target.value) })} /></label><label>Beschreibung<textarea value={draft.description} onChange={(event) => setDraft({ ...draft, description: event.target.value })} /></label><label>Regelwirkungen<textarea value={draft.effectsText} onChange={(event) => setDraft({ ...draft, effectsText: event.target.value })} /></label><button className="primary" type="submit">Speichern</button></form> : <><p>{status.description}</p><ul>{status.effects.map((effect) => <li key={effect}>{effect}</li>)}</ul></>}</article>;
}

function LogView({ store }: { store: PlannerStore }) {
  const state = useStore(store);
  const copy = async () => { await navigator.clipboard?.writeText(state.log.map((entry) => `[${new Date(entry.date).toLocaleString("de-DE")}] ${entry.message}`).join("\n")); store.notice("Protokoll in die Zwischenablage kopiert"); };
  return <section className="view"><div className="glass-card log-toolbar"><button type="button" onClick={() => void copy()}>Protokoll kopieren</button><button type="button" onClick={() => store.clearLog()}>Leeren</button></div><ol className="log-list">{[...state.log].reverse().map((entry) => <li className="glass-card" key={entry.id}><time>{new Date(entry.date).toLocaleString("de-DE")}</time><span>{entry.message}</span></li>)}</ol></section>;
}

function ConcentrationDialog({ store }: { store: PlannerStore }) {
  const check = store.concentrationChecks[0]!;
  return <div className="modal-backdrop"><section className="modal glass-card" role="dialog" aria-modal="true" aria-label="Konzentrationsprobe"><h2>Konzentrationsprobe</h2><p><strong>{check.creatureName}</strong> erleidet {check.damage} Schaden.</p><p>SG <strong>{check.dc}</strong> (10 oder halber Schaden)</p><button type="button" onClick={() => store.resolveConcentrationCheck(check, false)}>Verpatzt — Konzentration endet</button><button className="primary" type="button" onClick={() => store.resolveConcentrationCheck(check, true)}>Bestanden</button><button type="button" onClick={() => store.dismissConcentrationCheck(check)}>Ignorieren</button></section></div>;
}

export function createBlankMonster(name: string): MonsterTemplate {
  return { id: slugifyMonsterID(name), name, armorClass: 10, hpAverage: 1, hpDice: "1d8", challengeRating: "?", initiativeBonus: 0, type: "", source: "App", notes: "", importedAt: new Date().toISOString(), statblock: createEmptyStatBlock() };
}
