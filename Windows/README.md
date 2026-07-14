# Initiative Planner Pro for Windows

Electron/React implementation of Initiative Planner Pro 0.9.0 for Windows 10/11 x64.

## Requirements

- Node.js 22 or newer
- npm 10 or newer
- Windows 10/11 x64 for the native runtime gate

## Install and verify

```powershell
npm ci
npm test
npm run typecheck
npm run build
npm run test:e2e
```

`npm run test:e2e` starts the packaged Electron main/preload/renderer stack on the current host with the shared fixture at `../Fixtures/planner-state-v1.json`.

## Development

Run `npm run dev`, then start the compiled Electron main process with `VITE_DEV_SERVER_URL` pointing at the Vite URL. Production windows keep `contextIsolation`, the Chromium sandbox and disabled Node integration enabled.

## Windows x64 ZIP and installer

```powershell
npm run package:win
```

The unsigned ZIP and standalone NSIS installer are written to `release/InitiativePlannerPro-0.9.0-Windows-x64.zip` and `release/InitiativePlannerPro-0.9.0-Windows-x64-Setup.exe`. Signing is intentionally not part of this repository workflow.

## Data

The application stores `planner-state.json` below Electron's Windows `userData` directory (normally `%APPDATA%\Initiative Planner Pro`). Writes are debounced and atomic. Invalid or unsupported state files are copied to a timestamped `planner-state.incompatible-*.json` backup before a default state is opened.

Production packages use an explicit file allowlist (`dist`, `dist-electron` and package metadata). They start with an empty player, monster and encounter state and do not contain `Fixtures`, tests, test user-data or a prebuilt `planner-state.json`.

The versioned golden fixture accepts the legacy unversioned Swift/macOS format. Optional Swift `Codable` values may be omitted or `null`; the TypeScript decoder normalizes both representations. A native Windows 10/11 run and a real macOS → Windows → macOS data roundtrip remain required before release.
