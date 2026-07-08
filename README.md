# Initiative Planner Pro Mac

Native macOS/SwiftUI-Neubau der HTML-Version als Xcode-Projekt.

## Öffnen

```bash
open /Users/cramleo/Downloads/InitiativePlannerProMac/InitiativePlannerProMac.xcodeproj
```

Scheme: `InitiativePlannerProMac`

## Wichtige Entscheidungen

- macOS-only SwiftUI-App mit Liquid-Glass/Material-Oberfläche.
- Importierte Monster werden dauerhaft in `~/Library/Application Support/InitiativePlannerProMac/planner-state.json` gespeichert.
- Neue Monster kommen nur noch über den zentralen Import oder über `Monster > Neu` in die App.
- Keine sichtbaren JSON-/Backup-/Obsidian-Sonderimporte mehr.
- Das `X` auf Kämpferkarten entfernt Kämpfer sofort ohne Nachfrage.
- Encounter, Status, Log, Monsterdatenbank, HP-Modus, Initiative, Schaden/Heilung, Undo/Redo und Player View sind als native Funktionen umgesetzt.

## Importformat

Der Import akzeptiert `.txt`/`.md` oder eingefügten Text mit Feldern wie:

```markdown
---
name: Schattenwolf
rk: 14
tp: 45 (6d10+12)
hg: 3
initiative: +3
typ: Bestie
notizen: Rudeljäger
---
```

Auch einfache Schlüssel/Wert-Blöcke funktionieren:

```text
Name: Kristallspinne
AC: 16
HP: 58 (9d8+18)
CR: 4
Initiative: +2
Type: Konstrukt
```

## Verifikation

Nach der Korrektur der Info.plist-Versionstypen ausgeführt am 2026-07-08:

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild clean build test -scheme InitiativePlannerProMac \
  -project InitiativePlannerProMac.xcodeproj \
  -destination 'platform=macOS'
```

Ergebnis: `** TEST SUCCEEDED **`, 6 Tests, 0 Fehler.

Zusätzlich wurde die gebaute App gestartet. Sichtprüfung: Die native SwiftUI-Oberfläche ist sichtbar, kein Crashdialog. Die gebaute `Info.plist` enthält jetzt korrekt:

```text
CFBundleShortVersionString = "1.0"
CFBundleVersion = "1"
```

## Installation (Homebrew)

```bash
brew install --cask Cramleo234/tap/initiative-planner-pro
```

## Rechtliches

- **Inoffizielles Fan-Werkzeug.** Dieses Projekt steht in keiner Verbindung zu
  Wizards of the Coast. „Dungeons & Dragons" und „D&D" sind Marken von
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
