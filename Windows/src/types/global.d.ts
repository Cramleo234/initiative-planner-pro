import type { PlannerState } from "../domain/models";

export interface PlannerAPI {
  loadState(): Promise<{ state: PlannerState; recovery: { backupPath: string; message: string } | null }>;
  saveState(state: PlannerState): Promise<void>;
  onStateChanged(listener: (state: PlannerState) => void): () => void;
  onCommand(listener: (command: string) => void): () => void;
  openPlayerView(): Promise<void>;
  toggleFullscreen(): Promise<void>;
  chooseMonsterFiles(): Promise<string[]>;
  chooseMonsterFolder(): Promise<string[]>;
  importMonsterPaths(paths: string[]): Promise<Array<{ path: string; text: string; source: string }>>;
  pathForFile(file: File): string;
}

declare global {
  interface Window {
    plannerAPI?: PlannerAPI;
  }
}

export {};
