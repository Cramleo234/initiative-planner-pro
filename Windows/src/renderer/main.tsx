import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { createDefaultState, type PlannerState } from "../domain/models";
import { PlannerStore } from "../domain/store";
import { App } from "./App";
import { PlayerView } from "./PlayerView";
import "./styles.css";

async function bootstrap(): Promise<void> {
  const loaded = await window.plannerAPI?.loadState();
  const initialState = loaded?.state ?? createDefaultState();
  const isPlayerView = new URLSearchParams(window.location.search).get("player") === "1";
  const root = createRoot(document.getElementById("root")!);

  if (isPlayerView) {
    root.render(<StrictMode><PlayerViewBridge initialState={initialState} /></StrictMode>);
    return;
  }

  const store = new PlannerStore({
    load: initialState,
    onSave: async (state) => { await window.plannerAPI?.saveState(state); },
  });
  window.plannerAPI?.onCommand((command) => {
    if (command === "add-player") window.dispatchEvent(new CustomEvent("planner:add-player"));
    if (command === "next-turn") store.nextTurn();
    if (command === "previous-turn") store.previousTurn();
    if (command === "roll-monsters") store.rollAllMonsterInitiative();
    if (command === "undo") store.undo();
    if (command === "redo") store.redo();
    if (command === "next-theme") store.nextTheme();
    if (command.startsWith("theme:")) store.setTheme(command.slice("theme:".length));
  });
  window.addEventListener("beforeunload", () => { void store.flushPendingSave(); });
  if (loaded?.recovery) store.notice(`Inkompatible Zustandsdatei gesichert: ${loaded.recovery.backupPath}`, "warning");
  root.render(<StrictMode><App store={store} /></StrictMode>);
}

function PlayerViewBridge({ initialState }: { initialState: PlannerState }) {
  const [state, setState] = useState(initialState);
  useEffect(() => window.plannerAPI?.onStateChanged(setState), []);
  return <PlayerView state={state} />;
}

void bootstrap();
