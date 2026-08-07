# Veröffentlichung über Homebrew (eigener Tap)

Der einfachste Weg, die App per `brew install` verteilbar zu machen, ohne die
strengen Aufnahme-Kriterien von homebrew/cask erfüllen zu müssen:
ein **eigener Tap** (ein kleines GitHub-Repo mit der Cask-Formel) plus
**GitHub Releases** als Download-Quelle für das DMG.

## Einmalige Einrichtung

1. **App-Repo anlegen** (öffentlich), z. B. `github.com/Cramleo234/initiative-planner-pro`
   — dieses Projektverzeichnis pushen (ohne `build/`).
2. **Tap-Repo anlegen**: `github.com/Cramleo234/homebrew-tap`
   — Namenskonvention `homebrew-…` ist Pflicht, damit `brew tap Cramleo234/tap` funktioniert.
   Inhalt: der Ordner `Casks/` mit `initiative-planner-pro.rb`
   (Vorlage liegt hier unter `packaging/homebrew-tap/Casks/`).
3. In der Cask-Datei `Cramleo234` durch den echten GitHub-Benutzernamen ersetzen.

## Pro Release (z. B. 0.8.8)

1. Version in `App/Info.plist` und `project.yml` setzen; Icon-Badge neu generieren.
2. Release bauen und DMG erstellen (`InitiativePlannerPro-<version>.dmg`).
3. SHA-256 berechnen: `shasum -a 256 InitiativePlannerPro-<version>.dmg`
4. GitHub-Release erstellen und DMG anhängen:
   `gh release create v<version> InitiativePlannerPro-<version>.dmg --title "v<version>"`
5. Im Tap-Repo `version` und `sha256` in der Cask-Datei aktualisieren und pushen.

## Installation für Nutzer

```bash
brew tap Cramleo234/tap
brew trust Cramleo234/tap
brew install --cask initiative-planner-pro
```

**`brew trust` ist ab Homebrew 6 zwingend.** Taps von Drittanbietern werden ohne
ausdrückliche Freigabe kommentarlos übersprungen — die App ist dann für Nutzer
schlicht nicht auffindbar, ohne verwertbare Fehlermeldung. Bei älteren
Homebrew-Versionen existiert der Befehl noch nicht und wird weggelassen.

## Hinweise

- **Leere Datenbank ist Absicht:** Die App wird ohne Monsterdaten ausgeliefert
  (`PlannerState.monsterDatabase = []`). Nutzer importieren eigene
  Markdown-Sammlungen über den Import (Ordner, Dateien, Drag & Drop).
- **Gatekeeper:** Ohne Apple-Developer-Zertifikat + Notarisierung zeigt macOS
  beim ersten Start eine Warnung (Rechtsklick → „Öffnen“ umgeht sie, ebenso
  `--no-quarantine`). Für eine reibungslose Verteilung lohnt sich später ein
  Apple-Developer-Account (99 €/Jahr): `codesign` mit Developer-ID +
  `notarytool` — das DMG bleibt dasselbe, nur signiert/notarisiert.
- **Später in homebrew/cask (offiziell):** erst sinnvoll, wenn das Projekt
  öffentlich etabliert ist (GitHub-Metriken); bis dahin ist der eigene Tap
  der übliche Weg.
