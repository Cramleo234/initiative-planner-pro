import { app, BrowserWindow, dialog, ipcMain, Menu, type MenuItemConstructorOptions } from "electron";
import { readdir, readFile, stat } from "node:fs/promises";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { decodePlannerState, PLANNER_THEMES, type PlannerState } from "../src/domain/models.js";
import { loadStateFile, saveStateFileAtomic } from "./persistence.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const isDevelopment = Boolean(process.env.VITE_DEV_SERVER_URL);
let mainWindow: BrowserWindow | null = null;
let playerWindow: BrowserWindow | null = null;
let currentState: PlannerState;
let statePath = "";

function sendCommand(command: string): void {
  mainWindow?.webContents.send("planner:command", command);
}

export function buildMenuTemplate(): MenuItemConstructorOptions[] {
  return [
    {
      label: "Datei",
      submenu: [
        { label: "Spieler hinzufügen", accelerator: "CommandOrControl+N", click: () => sendCommand("add-player") },
        { type: "separator" },
        { role: "quit", label: "Beenden" },
      ],
    },
    {
      label: "Kampf",
      submenu: [
        { label: "Nächster Zug", accelerator: "Space", click: () => sendCommand("next-turn") },
        { label: "Vorheriger Zug", accelerator: "Left", click: () => sendCommand("previous-turn") },
        { label: "Monster-Initiative würfeln", accelerator: "CommandOrControl+R", click: () => sendCommand("roll-monsters") },
        { type: "separator" },
        { label: "Rückgängig", accelerator: "CommandOrControl+Z", click: () => sendCommand("undo") },
        { label: "Wiederholen", accelerator: "CommandOrControl+Shift+Z", click: () => sendCommand("redo") },
      ],
    },
    {
      label: "Darstellung",
      submenu: [
        { label: "Player View öffnen", click: () => { void openPlayerView(); } },
        { type: "separator" },
        ...PLANNER_THEMES.map((theme) => ({ label: theme.name, type: "radio" as const, checked: currentState?.selectedTheme === theme.id, click: () => sendCommand(`theme:${theme.id}`) })),
        { label: "Nächstes Theme", accelerator: "CommandOrControl+Shift+T", click: () => sendCommand("next-theme") },
        { type: "separator" },
        { role: "togglefullscreen", label: "Vollbild" },
      ],
    },
  ];
}

function windowOptions(player = false): Electron.BrowserWindowConstructorOptions {
  return {
    width: player ? 1100 : 1366,
    height: player ? 760 : 900,
    minWidth: player ? 900 : 1180,
    minHeight: player ? 650 : 780,
    show: false,
    backgroundColor: "#17120d",
    title: player ? "Initiative Planner Pro — Player View" : "Initiative Planner Pro",
    titleBarStyle: "hidden",
    titleBarOverlay: { color: "#17120d", symbolColor: "#fff7e8", height: 36 },
    webPreferences: {
      preload: join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      devTools: isDevelopment,
    },
  };
}

async function loadRenderer(window: BrowserWindow, player = false): Promise<void> {
  const query = player ? { player: "1" } : undefined;
  if (process.env.VITE_DEV_SERVER_URL) await window.loadURL(`${process.env.VITE_DEV_SERVER_URL}${player ? "?player=1" : ""}`);
  else await window.loadFile(join(app.getAppPath(), "dist", "index.html"), { query });
}

async function createMainWindow(): Promise<void> {
  mainWindow = new BrowserWindow(windowOptions());
  mainWindow.on("closed", () => { mainWindow = null; });
  mainWindow.once("ready-to-show", () => mainWindow?.show());
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  mainWindow.webContents.on("before-input-event", (event, input) => {
    if ((input.control || input.meta) && input.key.toLowerCase() === "r") event.preventDefault();
  });
  await loadRenderer(mainWindow);
}

async function openPlayerView(): Promise<void> {
  if (playerWindow && !playerWindow.isDestroyed()) { playerWindow.show(); playerWindow.focus(); return; }
  playerWindow = new BrowserWindow(windowOptions(true));
  playerWindow.on("closed", () => { playerWindow = null; });
  playerWindow.once("ready-to-show", () => playerWindow?.show());
  playerWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  await loadRenderer(playerWindow, true);
  playerWindow.webContents.once("did-finish-load", () => playerWindow?.webContents.send("state:changed", currentState));
}

async function collectMonsterFiles(paths: string[]): Promise<Array<{ path: string; text: string; source: string }>> {
  const result: Array<{ path: string; text: string; source: string }> = [];
  const visit = async (candidate: string): Promise<void> => {
    if (result.length >= 500) return;
    const info = await stat(candidate).catch(() => null);
    if (!info) return;
    if (info.isDirectory()) {
      if (candidate.includes("__MACOSX")) return;
      for (const name of await readdir(candidate)) {
        if (name.startsWith(".") || name.startsWith("._")) continue;
        await visit(join(candidate, name));
      }
      return;
    }
    const extension = extname(candidate).toLowerCase();
    if ((extension !== ".md" && extension !== ".txt") || info.size > 5_000_000) return;
    const text = await readFile(candidate, "utf8").catch(() => null);
    if (text !== null) result.push({ path: candidate, text, source: candidate.split(/[\\/]/).at(-1) ?? "Import" });
  };
  for (const rawPath of paths.slice(0, 100)) await visit(resolve(rawPath));
  return result;
}

function installIPC(): void {
  ipcMain.handle("state:load", async () => loadStateFile(statePath));
  ipcMain.handle("state:save", async (_event, candidate: unknown) => {
    currentState = decodePlannerState(JSON.stringify(candidate));
    await saveStateFileAtomic(statePath, currentState);
    playerWindow?.webContents.send("state:changed", currentState);
  });
  ipcMain.handle("player:open", async () => openPlayerView());
  ipcMain.handle("window:fullscreen", (event) => {
    const window = BrowserWindow.fromWebContents(event.sender);
    if (window) window.setFullScreen(!window.isFullScreen());
  });
  ipcMain.handle("dialog:monster-files", async () => {
    const options: Electron.OpenDialogOptions = { properties: ["openFile", "multiSelections"], filters: [{ name: "Monsterdateien", extensions: ["md", "txt"] }] };
    const result = mainWindow ? await dialog.showOpenDialog(mainWindow, options) : await dialog.showOpenDialog(options);
    return result.canceled ? [] : result.filePaths;
  });
  ipcMain.handle("dialog:monster-folder", async () => {
    const options: Electron.OpenDialogOptions = { properties: ["openDirectory"] };
    const result = mainWindow ? await dialog.showOpenDialog(mainWindow, options) : await dialog.showOpenDialog(options);
    return result.canceled ? [] : result.filePaths;
  });
  ipcMain.handle("monster:read-paths", async (_event, paths: unknown) => Array.isArray(paths) && paths.every((path) => typeof path === "string") ? collectMonsterFiles(paths) : []);
}

app.whenReady().then(async () => {
  app.setAppUserModelId("com.cramleo.InitiativePlannerPro");
  statePath = join(app.getPath("userData"), "planner-state.json");
  const loaded = await loadStateFile(statePath);
  currentState = loaded.state;
  installIPC();
  Menu.setApplicationMenu(Menu.buildFromTemplate(buildMenuTemplate()));
  await createMainWindow();
  app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) void createMainWindow(); });
}).catch((error) => {
  dialog.showErrorBox("Initiative Planner Pro", error instanceof Error ? error.message : String(error));
  app.quit();
});

app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
