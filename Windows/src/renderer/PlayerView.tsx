import type { CSSProperties } from "react";
import { initiativeList, type PlannerState } from "../domain/models";

export interface PlayerViewProps {
  state: PlannerState;
}

export function PlayerView({ state }: PlayerViewProps) {
  const creatures = initiativeList(state);
  const activeIndex = Math.max(0, creatures.findIndex((creature) => creature.id === state.activeID));
  const active = creatures[activeIndex];
  const statusLabels = new Map(state.statuses.map((status) => [status.id, status.label]));
  const labelFor = (id: string) => statusLabels.get(id) ?? id;

  if (creatures.length === 0) {
    return <main className="player-view empty"><p>Noch keine Initiative gesetzt.</p></main>;
  }

  return (
    <main className={`player-view theme-${state.selectedTheme}`}>
      <header className="player-chrome">
        <div><strong>⚔️ Initiative</strong><span>Spieleransicht · ohne versteckte DM-Werte</span></div>
        <button type="button" aria-label="Vollbild" onClick={() => void window.plannerAPI?.toggleFullscreen()}>⛶ Vollbild</button>
      </header>
      <section className="initiative-ring" aria-label="Initiative-Ring">
        {creatures.map((creature, index) => {
          const angle = ((index - activeIndex) * 360) / Math.max(1, creatures.length) - 90;
          const style = { "--token-angle": `${angle}deg` } as CSSProperties;
          return (
            <article key={creature.id} className={`ring-token ${creature.id === state.activeID ? "active" : ""}`} style={style}>
              <span className="token-kind">{creature.kind === "player" ? "🧙" : "👹"}</span>
              <strong>{creature.name}</strong>
              {index === (activeIndex + 1) % creatures.length && <small>NÄCHSTER</small>}
              <div className="token-statuses">{creature.statuses.slice(0, 2).map((status) => <span key={status.id}>{labelFor(status.id)}</span>)}</div>
              {creature.kind === "player" && <span className="player-hp">{creature.hitPoints} / {creature.maxHitPoints} TP</span>}
              {creature.maxHitPoints > 0 && creature.hitPoints <= 0 && <span aria-label="Besiegt">✕</span>}
            </article>
          );
        })}
        <div className="ring-center">
          <small>RUNDE</small><strong>{state.round}</strong>
          <span>AM ZUG</span><h1>{active?.name}</h1>
          {active?.kind === "player" && <p>{active.hitPoints} / {active.maxHitPoints} TP</p>}
          <div>{active?.statuses.slice(0, 4).map((status) => <span className="status-chip" key={status.id}>{labelFor(status.id)}</span>)}</div>
        </div>
      </section>
    </main>
  );
}
