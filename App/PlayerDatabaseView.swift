import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Öffnet einen synchronen Bild-Dialog und kopiert die Auswahl sofort unter einer neuen
/// Bildversions-UUID in den PlayerImageStore. `runModal()` blockiert den kompletten
/// Event-Loop, bis der Dialog geschlossen wird — eine zweite, überlappende Auswahl kann
/// dadurch architekturbedingt nicht starten (kein Pendant zur Windows-Race-Condition nötig).
@MainActor
func presentPlayerImagePicker(store: PlannerStore) -> UUID? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.png, .jpeg, .webP]
    panel.message = "Spielerbild auswählen"
    panel.prompt = "Auswählen"
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return store.storePlayerImage(at: url)
}

struct PlayerDatabaseView: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var showingPlayerEditor: Bool
    @Binding var editingPlayer: PlayerTemplate?

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Spielerdatenbank", subtitle: "Dauerhaft in der App gespeichert", icon: "person.crop.circle.fill")
                    HStack {
                        Text("Nur der Name ist Pflicht. RK, TP, Initiative-Bonus, Bild und Notizen dürfen leer bleiben.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { editingPlayer = nil; showingPlayerEditor = true } label: { Label("Neuer Spieler", systemImage: "plus") }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                    }
                }
            }
            if store.state.playerDatabase.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Spieler angelegt.")
                        .font(.system(size: 14, weight: .bold))
                    Text("Lege deine Spielercharaktere einmal an — danach lassen sie sich per Klick in jeden Kampf oder Encounter übernehmen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                    Button { editingPlayer = nil; showingPlayerEditor = true } label: {
                        Label("Neuer Spieler", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                    ForEach(store.state.playerDatabase) { template in
                        PlayerCard(template: template, showingPlayerEditor: $showingPlayerEditor, editingPlayer: $editingPlayer)
                    }
                }
            }
        }
    }
}

struct PlayerCard: View {
    @EnvironmentObject private var store: PlannerStore
    var template: PlayerTemplate
    @Binding var showingPlayerEditor: Bool
    @Binding var editingPlayer: PlayerTemplate?
    @State private var selectedEncounterID: UUID?

    var body: some View {
        let theme = store.theme
        let image = PlayerImageStore.shared.image(for: template.imageID)
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Circle().fill(.thinMaterial)
                                .frame(width: 44, height: 44)
                            Text(String(template.name.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .black, design: .rounded))
                        }
                    }
                    .overlay(Circle().strokeBorder(theme.cardBorder, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name).font(.system(size: 15, weight: .bold))
                        HStack(spacing: 10) {
                            Text("RK \(template.armorClass.map(String.init) ?? "—")")
                            Text("TP \(template.maxHitPoints.map(String.init) ?? "—")")
                            Text("Ini \(template.initiativeBonus.map { ($0 >= 0 ? "+" : "") + String($0) } ?? "—")")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { editingPlayer = template; showingPlayerEditor = true } label: { Image(systemName: "pencil") }
                        .help("Bearbeiten")
                    Button(role: .destructive) { store.deletePlayerTemplate(template.id) } label: { Image(systemName: "xmark") }
                        .help("Entfernt sofort — ⌘Z stellt wieder her")
                }
                if !template.notes.isEmpty {
                    Text(template.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Divider().opacity(0.2)
                Button { store.spawnPlayerIntoCombat(template.id) } label: {
                    Label("Zum Kampf", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                HStack(spacing: 8) {
                    Picker("Encounter", selection: $selectedEncounterID) {
                        Text("Encounter wählen…").tag(UUID?.none)
                        ForEach(store.state.encounters) { encounter in
                            Text(encounter.name).tag(Optional(encounter.id))
                        }
                    }
                    .labelsHidden()
                    .layoutPriority(1)
                    Button {
                        if let id = selectedEncounterID { store.spawnPlayer(template.id, intoEncounter: id) }
                    } label: { Image(systemName: "tray.and.arrow.down.fill") }
                        .buttonStyle(.bordered)
                        .disabled(selectedEncounterID == nil)
                        .help("Zu ausgewähltem Encounter hinzufügen")
                }
            }
        }
    }
}

struct PlayerEditorDialog: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    var template: PlayerTemplate?
    var onSave: (PlayerTemplate) -> Void

    @State private var name = ""
    @State private var armorClassText = ""
    @State private var maxHitPointsText = ""
    @State private var initiativeBonusText = ""
    @State private var notes = ""
    @State private var pendingImageID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: template == nil ? "Neuer Spieler" : "Spieler bearbeiten", subtitle: "Nur der Name ist Pflicht", icon: "person.crop.circle.fill")
            HStack(spacing: 14) {
                ZStack {
                    if let image = PlayerImageStore.shared.image(for: pendingImageID) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    } else {
                        Circle().fill(.thinMaterial).frame(width: 64, height: 64)
                        Text(String(name.isEmpty ? "?" : name.prefix(1)).uppercased())
                            .font(.system(size: 24, weight: .black, design: .rounded))
                    }
                }
                .overlay(Circle().strokeBorder(store.theme.cardBorder, lineWidth: 1))
                VStack(alignment: .leading, spacing: 6) {
                    Button("Bild wählen…") {
                        if let newID = presentPlayerImagePicker(store: store) { pendingImageID = newID }
                    }
                    if pendingImageID != nil {
                        Button("Bild entfernen", role: .destructive) { pendingImageID = nil }
                    }
                }
            }
            Form {
                TextField("Name", text: $name)
                TextField("RK (optional)", text: $armorClassText)
                TextField("TP (optional)", text: $maxHitPointsText)
                TextField("Initiative-Bonus (optional)", text: $initiativeBonusText)
                TextField("Notizen", text: $notes, axis: .vertical)
            }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Speichern") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(LiquidBackground(theme: store.theme))
        .onAppear {
            if let template {
                name = template.name
                armorClassText = template.armorClass.map(String.init) ?? ""
                maxHitPointsText = template.maxHitPoints.map(String.init) ?? ""
                initiativeBonusText = template.initiativeBonus.map(String.init) ?? ""
                notes = template.notes
                pendingImageID = template.imageID
            }
        }
    }

    private func save() {
        onSave(PlayerTemplate(
            id: template?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            armorClass: Int(armorClassText.trimmingCharacters(in: .whitespaces)),
            maxHitPoints: Int(maxHitPointsText.trimmingCharacters(in: .whitespaces)),
            initiativeBonus: Int(initiativeBonusText.trimmingCharacters(in: .whitespaces)),
            notes: notes,
            imageID: pendingImageID))
    }
}
