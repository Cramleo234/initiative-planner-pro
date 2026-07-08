cask "initiative-planner-pro" do
  version "0.8.9"
  sha256 "4e79db24732be038d0e84eb7a47139ae9bdd4d72751b881db93b0131044d4521"

  # Cramleo234 anpassen, sobald das Release-Repo existiert.
  url "https://github.com/Cramleo234/initiative-planner-pro/releases/download/v#{version}/InitiativePlannerPro-#{version}.dmg"
  name "Initiative Planner Pro"
  desc "Initiative-Tracker für Tabletop-Rollenspiele (5e-kompatibel) — Kampf, Monsterdatenbank, Status, Player View"
  homepage "https://github.com/Cramleo234/initiative-planner-pro"

  depends_on macos: :sequoia

  app "Initiative Planner Pro.app"

  zap trash: [
    "~/Library/Application Support/InitiativePlannerProMac",
  ]

  caveats <<~EOS
    Die App wird ohne Monsterdaten ausgeliefert — eigene Sammlungen lassen sich
    über den Import (Markdown-Dateien/Ordner) in die App laden.

    Die App ist derzeit nicht notarisiert. Beim ersten Start ggf.:
    Rechtsklick auf die App → „Öffnen“ — oder Installation mit:
      brew install --cask --no-quarantine Cramleo234/tap/initiative-planner-pro
  EOS
end
