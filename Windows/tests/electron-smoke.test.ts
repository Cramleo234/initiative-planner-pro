import { copyFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { _electron as playwrightElectron, expect, test } from "@playwright/test";

const require = createRequire(import.meta.url);
const electronExecutable = require("electron") as string;
const artifactDirectory = process.env.E2E_ARTIFACT_DIR ?? resolve("verification");

test("boots main, preload and renderer with fixture data and opens privacy-safe Player View", async () => {
  const userData = join(artifactDirectory, "electron-user-data");
  mkdirSync(userData, { recursive: true });
  copyFileSync(resolve("../Fixtures/planner-state-v1.json"), join(userData, "planner-state.json"));

  const electronApp = await playwrightElectron.launch({
    executablePath: electronExecutable,
    args: [resolve("."), `--user-data-dir=${userData}`, "--disable-gpu"],
    cwd: resolve("."),
    env: { ...process.env, ELECTRON_DISABLE_SECURITY_WARNINGS: "true" },
  });

  try {
    const main = await electronApp.firstWindow();
    await main.waitForLoadState("domcontentloaded");
    await expect(main.getByText("Initiative Planner Pro")).toBeVisible();
    await expect(main.getByText("Älva 🧙").first()).toBeVisible();
    expect(await main.evaluate(() => Object.keys(window.plannerAPI ?? {}).sort())).toEqual([
      "chooseMonsterFiles", "chooseMonsterFolder", "importMonsterPaths", "loadState", "onCommand",
      "onStateChanged", "openPlayerView", "pathForFile", "saveState", "toggleFullscreen",
    ]);
    expect(await main.evaluate(() => typeof process)).toBe("undefined");

    await main.keyboard.press("Control+N");
    await expect(main.getByLabel("Name")).toBeFocused();
    const beforeURL = main.url();
    await main.keyboard.press("Control+R");
    await main.waitForTimeout(150);
    expect(main.url()).toBe(beforeURL);
    await main.screenshot({ path: join(artifactDirectory, "electron-main.png"), fullPage: true });

    await main.getByRole("button", { name: "Monster", exact: true }).click();
    await expect(main.getByRole("heading", { name: "Nebelweber" })).toBeVisible();
    await main.screenshot({ path: join(artifactDirectory, "electron-monster-database.png"), fullPage: true });
    await main.getByRole("button", { name: "Encounters", exact: true }).click();
    await expect(main.getByRole("heading", { name: "Brücke über den Äther" })).toBeVisible();
    await main.screenshot({ path: join(artifactDirectory, "electron-encounters.png"), fullPage: true });
    await main.getByRole("button", { name: "Status", exact: true }).click();
    await expect(main.getByRole("heading", { name: "Konzentration" })).toBeVisible();
    await main.screenshot({ path: join(artifactDirectory, "electron-status-library.png"), fullPage: true });
    await main.getByRole("button", { name: "Protokoll", exact: true }).click();
    await expect(main.getByText("Runde 3 — Älva ist am Zug 🎲")).toBeVisible();
    await main.screenshot({ path: join(artifactDirectory, "electron-log.png"), fullPage: true });

    const playerPromise = electronApp.waitForEvent("window");
    await main.evaluate(() => window.plannerAPI?.openPlayerView());
    const player = await playerPromise;
    await player.waitForLoadState("domcontentloaded");
    await expect(player.getByText("Spieleransicht · ohne versteckte DM-Werte")).toBeVisible();
    await expect(player.getByText("23 / 31 TP").first()).toBeVisible();
    await expect(player.getByText("35 / 42 TP")).toHaveCount(0);
    await player.screenshot({ path: join(artifactDirectory, "electron-player-view.png"), fullPage: true });
  } finally {
    await electronApp.close();
  }
});
