# Initiative Planner Pro

Initiative-Tracker für Tabletop-Rollenspiele (5e-kompatibel) — als **native macOS-App** (SwiftUI, Liquid Glass) und als **Windows-Version** mit identischen Funktionen und Design.

## Features

- **Kampf-Dashboard**: Initiative-Leiste mit Rundenzähler, Zugsteuerung (Leertaste/Pfeiltasten), manuelle Reihenfolge bei Gleichstand per Drag & Drop
- **Kämpferkarten**: Schnell-Schaden (−10/−5/−1/+1/+5), Würfelformeln (`2d6+3`, deutsche `2W6+3`-Notation), temporäre HP, Todesrettungswürfe mit abhakbaren Slots
- **Status-System**: 27 Zustände und Marker mit vollständigen Regeltexten, eigene Stati mit eigenen Regeln, **Statusdauer in Runden** (läuft beim Zugwechsel automatisch ab)
- **Konzentrations-Assistent**: Bei Schaden erscheint automatisch die fällige Probe mit korrektem SG (10 oder halber Schaden)
- **Monsterdatenbank**: Import aus Markdown-Dateien (einzeln, ganze Ordner rekursiv, Drag & Drop) inklusive vollständiger **Statblöcke** — Aktionen, Bonusaktionen, Reaktionen und legendäre Aktionen sind direkt im Kampf aufklappbar
- **Player View**: rotierender Initiative-Ring für Zweitbildschirm oder Beamer — ohne versteckte Spielleiter-Werte
- **5 Themes** (Bernstein, Obsidian, Pergament, Weiß, Mitternacht), Undo/Redo, Encounter-Spielstände, Kampf-Log, Auto-Save

Die App wird bewusst **ohne Monsterdaten** ausgeliefert — jeder importiert seine eigene Sammlung.

## Installation

### macOS (15 Sequoia oder neuer)

Am einfachsten über [Homebrew](https://brew.sh):

```bash
brew install --cask Cramleo234/tap/initiative-planner-pro
```

Oder manuell: das DMG von der [Releases-Seite](https://github.com/Cramleo234/initiative-planner-pro/releases) laden, öffnen und die App nach **Programme** ziehen.

> Die App ist derzeit nicht notarisiert. Beim ersten Start ggf. Rechtsklick auf die App → **„Öffnen“** — oder mit `brew install --cask --no-quarantine …` installieren.

### Windows (10/11, x64)

1. `InitiativePlannerPro-<version>-Windows-x64.zip` von der [Releases-Seite](https://github.com/Cramleo234/initiative-planner-pro/releases) laden
2. ZIP an einen beliebigen Ort entpacken (portabel, kein Installer)
3. **`Initiative Planner Pro.exe`** starten

> Beim ersten Start zeigt Windows SmartScreen eine Warnung (unsignierte App): **„Weitere Informationen“ → „Trotzdem ausführen“**.

Beide Versionen nutzen dasselbe Speicherformat: `planner-state.json` liegt auf dem Mac unter `~/Library/Application Support/InitiativePlannerProMac/`, unter Windows in `%APPDATA%\Initiative Planner Pro\` — die Datei lässt sich zwischen beiden Systemen kopieren.

## Monster importieren

Der Import liest `.md`-Dateien (z. B. aus einem Obsidian-Vault) mit YAML-Frontmatter — einzeln, als ganzer Ordner inklusive Unterordnern oder per Drag & Drop ins Fenster. Dateien ohne Monster-Werte (Notizen, Sitzungsprotokolle) werden automatisch übersprungen. Einmal importieren genügt: Alles wird dauerhaft in der App gespeichert.

Beispiel — ein selbst erfundenes Monster:

```markdown
---
name: Nebelweber
untertitel: Lauernder Jäger aus Dunst und Seide
typ: Monstrosität
größe: Mittelgroß
gesinnung: Neutral böse
rk: 14
tp: "39 (6W8+12)"
hg: 2
initiative: "+2 (12)"
bewegungsrate: "9 m, Klettern 9 m"
resistenzen: [Kälte]
sinne: [Dunkelsicht 18 m, Passive Wahrnehmung 13]
---

## Merkmale

**Nebelhülle:** Der Nebelweber ist in dichtem Nebel leicht verschleiert
und kann sich als Bonusaktion verstecken.

## Aktionen

**Biss:** *Nahkampfangriffswurf:* +4, Reichweite 1,5 m.
*Treffer:* 7 (1W8+2) Stichschaden plus 3 (1W6) Kälteschaden.

**Nebelfaden (Aufladung 5–6):** *Geschicklichkeitsrettungswurf:* SG 12;
eine Kreatur im Abstand von bis zu 9 m. *Misserfolg:* Das Ziel ist
festgesetzt (Flucht-SG 12).
```

Pflicht sind nur `name` und ein Wert für `rk`/`ac` oder `tp`/`hp` — alles Weitere (Attribute `stä` bis `cha` mit `_mod`/`_rw`, Resistenzen, Immunitäten, Fertigkeiten, Sprachen sowie die Abschnitte `## Merkmale`, `## Aktionen`, `## Bonusaktionen`, `## Reaktionen`, `## Legendäre Aktionen`) wird als vollständiger Statblock übernommen. Auch einfache Schlüssel/Wert-Blöcke ohne Frontmatter funktionieren (`Name: … / RK: … / TP: …`).

## Aus dem Quellcode bauen

**macOS** (Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
xcodegen generate
xcodebuild -project InitiativePlannerProMac.xcodeproj \
  -scheme InitiativePlannerProMac -destination 'platform=macOS' build test
```

Die Release-Routine (DMG, Homebrew-Tap) ist in [packaging/RELEASING.md](packaging/RELEASING.md) beschrieben.

**Windows-Version** (Electron, separates Projekt): mit `npm install` und `npm start` starten, Paketierung per `npx electron-packager . "Initiative Planner Pro" --platform=win32 --arch=x64 --out=dist`.

## Rechtliches

- **Inoffizielles Fan-Werkzeug.** Dieses Projekt steht in keiner Verbindung zu
  Wizards of the Coast. „Dungeons & Dragons“ und „D&D“ sind Marken von
  Wizards of the Coast LLC; die Nennung dient nur der Beschreibung der
  Kompatibilität.
- **Keine Regelwerks-Inhalte enthalten.** Die App wird ohne Monsterdaten
  ausgeliefert. Nutzer importieren ausschließlich eigene Dateien; für deren
  Inhalte sind sie selbst verantwortlich. Importierte Daten bleiben lokal auf
  dem eigenen Gerät und werden nicht weitergegeben.
- **Zustands-Kurzreferenzen.** Die in der Status-Bibliothek hinterlegten
  Kurzbeschreibungen zu Spielzuständen basieren auf frei nutzbaren
  Spielmechaniken, wie sie u. a. im System Reference Document 5.2 von
  Wizards of the Coast unter der Lizenz CC-BY-4.0 veröffentlicht sind
  (https://www.dndbeyond.com/srd).
- **Eigenes Artwork.** App-Icon und Oberfläche sind Eigenentwicklungen.

© 2026 Marc Erkens. Alle Rechte vorbehalten.
