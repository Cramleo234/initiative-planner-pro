import { contextBridge, ipcRenderer, webUtils } from "electron";

const api = {
  loadState: () => ipcRenderer.invoke("state:load"),
  saveState: (state: unknown) => ipcRenderer.invoke("state:save", state),
  onStateChanged: (listener: (state: unknown) => void) => {
    const handler = (_event: Electron.IpcRendererEvent, state: unknown) => listener(state);
    ipcRenderer.on("state:changed", handler);
    return () => ipcRenderer.removeListener("state:changed", handler);
  },
  onCommand: (listener: (command: string) => void) => {
    const handler = (_event: Electron.IpcRendererEvent, command: string) => listener(command);
    ipcRenderer.on("planner:command", handler);
    return () => ipcRenderer.removeListener("planner:command", handler);
  },
  openPlayerView: () => ipcRenderer.invoke("player:open"),
  toggleFullscreen: () => ipcRenderer.invoke("window:fullscreen"),
  chooseMonsterFiles: () => ipcRenderer.invoke("dialog:monster-files"),
  chooseMonsterFolder: () => ipcRenderer.invoke("dialog:monster-folder"),
  importMonsterPaths: (paths: string[]) => ipcRenderer.invoke("monster:read-paths", paths),
  pathForFile: (file: File) => webUtils.getPathForFile(file),
};

contextBridge.exposeInMainWorld("plannerAPI", Object.freeze(api));
