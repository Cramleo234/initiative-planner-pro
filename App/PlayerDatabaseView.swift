import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Öffnet einen synchronen Bild-Dialog und lädt die Auswahl als `NSImage`, ohne sie
/// bereits im PlayerImageStore abzulegen — der Bildausschnitt wird erst danach im
/// `PlayerImageCropDialog` festgelegt. `runModal()` blockiert den kompletten Event-Loop,
/// bis der Dialog geschlossen wird — eine zweite, überlappende Auswahl kann dadurch
/// architekturbedingt nicht starten (kein Pendant zur Windows-Race-Condition nötig).
@MainActor
func presentPlayerImageFilePicker() -> NSImage? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    // .heic bewusst dabei: das Standardformat von iPhone-Fotos — ohne es ließen sich
    // die meisten direkt vom Handy stammenden Spielerbilder gar nicht erst auswählen.
    panel.allowedContentTypes = [.png, .jpeg, .webP, .heic]
    panel.message = "Spielerbild auswählen"
    panel.prompt = "Auswählen"
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return NSImage(contentsOf: url)
}

/// Errechnet aus Zoom/Verschiebung im `PlayerImageCropDialog` den sichtbaren Ausschnitt
/// im eigenen Koordinatenraum des Quellbilds — als Eingabe für `NSImage.draw(in:from:)`.
///
/// SwiftUIs Offset-Raum hat den Ursprung oben links (y wächst nach unten); AppKits
/// `from`-Rect für `NSImage.draw` hat den Ursprung unten links (y wächst nach oben) — die
/// Y-Achse muss deshalb explizit gespiegelt werden, sonst zeigt das gespeicherte Bild einen
/// vertikal falsch positionierten Ausschnitt.
func playerImageCropRect(imageSize: CGSize, previewSide: CGFloat, zoom: CGFloat, offset: CGSize) -> CGRect {
    let baseScale = max(previewSide / imageSize.width, previewSide / imageSize.height)
    let scale = baseScale * zoom
    let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let imageOriginInPreview = CGPoint(
        x: (previewSide - displaySize.width) / 2 + offset.width,
        y: (previewSide - displaySize.height) / 2 + offset.height)
    let cropInDisplayTopLeft = CGRect(x: -imageOriginInPreview.x, y: -imageOriginInPreview.y,
                                       width: previewSide, height: previewSide)
    let cropInImageTopLeft = CGRect(x: cropInDisplayTopLeft.origin.x / scale,
                                     y: cropInDisplayTopLeft.origin.y / scale,
                                     width: cropInDisplayTopLeft.width / scale,
                                     height: cropInDisplayTopLeft.height / scale)
    let flippedY = imageSize.height - cropInImageTopLeft.origin.y - cropInImageTopLeft.height
    return CGRect(x: cropInImageTopLeft.origin.x, y: flippedY,
                   width: cropInImageTopLeft.width, height: cropInImageTopLeft.height)
}

/// Maximal erlaubte Verschiebung (in Vorschau-Punkten), damit der Bildausschnitt den
/// sichtbaren Kreis immer vollständig deckt.
func playerImageCropMaxOffset(imageSize: CGSize, previewSide: CGFloat, zoom: CGFloat) -> CGSize {
    let baseScale = max(previewSide / imageSize.width, previewSide / imageSize.height)
    let scale = baseScale * zoom
    let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGSize(width: max(0, (displaySize.width - previewSide) / 2),
                  height: max(0, (displaySize.height - previewSide) / 2))
}

/// Dialog zum Zuschneiden eines Spielerbilds: Der Nutzer wählt per Ziehen und Zoomen den
/// Bildausschnitt, der im runden Avatar erscheinen soll — statt eines automatischen,
/// nicht beeinflussbaren Zuschnitts. `onConfirm` liefert das fertig zugeschnittene
/// quadratische Bild in Originalqualität; die eigentliche Verkleinerung/Speicherung
/// übernimmt weiterhin `PlayerImageStore`.
struct PlayerImageCropDialog: View {
    @Environment(\.dismiss) private var dismiss
    var image: NSImage
    var onConfirm: (NSImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero

    private let previewSide: CGFloat = 280
    private let outputSide: CGFloat = 512

    private var maxOffset: CGSize {
        playerImageCropMaxOffset(imageSize: image.size, previewSide: previewSide, zoom: zoom)
    }

    private func clamp(_ proposed: CGSize) -> CGSize {
        let m = maxOffset
        return CGSize(width: min(max(proposed.width, -m.width), m.width),
                      height: min(max(proposed.height, -m.height), m.height))
    }

    private var displaySize: CGSize {
        let baseScale = max(previewSide / image.size.width, previewSide / image.size.height)
        let scale = baseScale * zoom
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Bildausschnitt wählen", subtitle: "Ziehen zum Verschieben, Regler zum Zoomen", icon: "crop")
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let proposed = CGSize(width: dragStartOffset.width + value.translation.width,
                                                       height: dragStartOffset.height + value.translation.height)
                                offset = clamp(proposed)
                            }
                            .onEnded { _ in dragStartOffset = offset }
                    )
            }
            .frame(width: previewSide, height: previewSide)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: 1...4)
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            }
            .onChange(of: zoom) { offset = clamp(offset) }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Übernehmen") {
                    if let cropped = renderCroppedImage() { onConfirm(cropped) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 360)
    }

    private func renderCroppedImage() -> NSImage? {
        let fromRect = playerImageCropRect(imageSize: image.size, previewSide: previewSide, zoom: zoom, offset: offset)
        let side = Int(outputSide)
        guard let out = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        out.size = NSSize(width: outputSide, height: outputSide)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        image.draw(in: NSRect(x: 0, y: 0, width: outputSide, height: outputSide),
                   from: fromRect, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: NSSize(width: outputSide, height: outputSide))
        result.addRepresentation(out)
        return result
    }
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
    @State private var imageToCrop: NSImage?
    @State private var showingCropDialog = false

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
                        if let picked = presentPlayerImageFilePicker() {
                            imageToCrop = picked
                            showingCropDialog = true
                        }
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
        .sheet(isPresented: $showingCropDialog) {
            if let imageToCrop {
                PlayerImageCropDialog(image: imageToCrop) { cropped in
                    if let newID = store.storePlayerImage(cropped) { pendingImageID = newID }
                }
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
