import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Theme-System
// Design-Sprache aus dem Claude-Design-Handoff („Initiative Tracker.dc.html“):
// warmes Liquid Glass, UPPERCASE-Labels mit Letterspacing, Pill-Buttons,
// HP-Ampelfarben, Schnell-Schaden-Buttons. Vier Themes, live umschaltbar —
// der Funktionsumfang bleibt in jedem Theme identisch.

struct PlannerTheme: Identifiable, Equatable, Sendable {
    struct Glow: Equatable, Sendable {
        let color: Color
        let center: UnitPoint
        let radius: CGFloat
    }

    let id: String
    let name: String
    let icon: String
    let isDark: Bool
    let bgStops: [Color]
    let glows: [Glow]
    let accent: Color          // Primärakzent (Bernstein …)
    let accentBright: Color    // helle Akzentschrift
    let accentContrast: Color  // Text auf Akzent-Buttons
    let tertiary: Color        // Terrakotta/Violett für Sekundäres
    let cardTint: Color        // Grundton der Glasflächen
    let cardBorder: Color

    static func == (lhs: PlannerTheme, rhs: PlannerTheme) -> Bool { lhs.id == rhs.id }

    /// 🔥 Bernstein — das Claude-Design: warmer Amber/Terrakotta-Grund.
    static let ember = PlannerTheme(
        id: "ember", name: "Bernstein", icon: "flame.fill", isDark: true,
        bgStops: [Color(hex: 0x2b1a12), Color(hex: 0x43281a), Color(hex: 0x5c3620)],
        glows: [Glow(color: Color(hex: 0xf2a54a, alpha: 0.28), center: .init(x: 0.15, y: -0.05), radius: 620),
                Glow(color: Color(hex: 0xd96b43, alpha: 0.30), center: .init(x: 0.95, y: 1.05), radius: 560)],
        accent: Color(hex: 0xf2a54a), accentBright: Color(hex: 0xffd9a8),
        accentContrast: Color(hex: 0x241009), tertiary: Color(hex: 0xd96b43),
        cardTint: Color(hex: 0xfff6eb), cardBorder: Color(hex: 0xffebd7, alpha: 0.25))

    /// 🌑 Obsidian — Gold auf tiefem Violett-Schwarz.
    static let obsidian = PlannerTheme(
        id: "obsidian", name: "Obsidian", icon: "moon.stars.fill", isDark: true,
        bgStops: [Color(hex: 0x0f0c16), Color(hex: 0x171222), Color(hex: 0x211a31)],
        glows: [Glow(color: Color(hex: 0xd8ad54, alpha: 0.18), center: .init(x: 0.05, y: 0.08), radius: 520),
                Glow(color: Color(hex: 0x6e55b8, alpha: 0.16), center: .init(x: 0.94, y: 0.14), radius: 560)],
        accent: Color(hex: 0xd8ad54), accentBright: Color(hex: 0xf1d589),
        accentContrast: Color(hex: 0x201406), tertiary: Color(hex: 0x9b7cf0),
        cardTint: Color(hex: 0xf4eddf), cardBorder: Color(hex: 0x75669a, alpha: 0.45))

    /// 📜 Pergament — helle, warme Variante.
    static let parchment = PlannerTheme(
        id: "parchment", name: "Pergament", icon: "scroll.fill", isDark: false,
        bgStops: [Color(hex: 0xf2e7cb), Color(hex: 0xe7d3a7), Color(hex: 0xdcc28e)],
        glows: [Glow(color: Color(hex: 0x9d6b1f, alpha: 0.12), center: .init(x: 0.10, y: 0.05), radius: 520),
                Glow(color: Color(hex: 0xd96b43, alpha: 0.08), center: .init(x: 0.90, y: 1.05), radius: 480)],
        accent: Color(hex: 0x9d6b1f), accentBright: Color(hex: 0x6b4512),
        accentContrast: Color(hex: 0xfff8e7), tertiary: Color(hex: 0x6744a5),
        cardTint: Color(hex: 0xfff9e5), cardBorder: Color(hex: 0x9e7c45, alpha: 0.5))

    ///  Weiß — cleanes, helles Theme: neutraler Grund,
    /// System-Blau als Akzent, weiße Karten mit Hairline-Rändern.
    static let pure = PlannerTheme(
        id: "pure", name: "Weiß", icon: "sun.max.fill", isDark: false,
        bgStops: [Color(hex: 0xf8f8fa), Color(hex: 0xf2f2f6), Color(hex: 0xebebf0)],
        glows: [Glow(color: Color(hex: 0x007aff, alpha: 0.05), center: .init(x: 0.2, y: -0.05), radius: 600),
                Glow(color: Color(hex: 0x5e5ce6, alpha: 0.04), center: .init(x: 0.9, y: 1.05), radius: 560)],
        accent: Color(hex: 0x007aff), accentBright: Color(hex: 0x0057c2),
        accentContrast: Color(hex: 0xffffff), tertiary: Color(hex: 0xaf52de),
        cardTint: Color(hex: 0xffffff), cardBorder: Color(hex: 0x000000, alpha: 0.10))

    /// ❄️ Mitternacht — kühles Eisblau, nahe am bisherigen Look.
    static let midnight = PlannerTheme(
        id: "midnight", name: "Mitternacht", icon: "snowflake", isDark: true,
        bgStops: [Color(hex: 0x0a101c), Color(hex: 0x121f38), Color(hex: 0x1a2e50)],
        glows: [Glow(color: Color(hex: 0x6fa8f5, alpha: 0.22), center: .init(x: 0.12, y: -0.02), radius: 600),
                Glow(color: Color(hex: 0x8b7cf0, alpha: 0.18), center: .init(x: 0.95, y: 1.05), radius: 540)],
        accent: Color(hex: 0x6fa8f5), accentBright: Color(hex: 0xaecdff),
        accentContrast: Color(hex: 0x081120), tertiary: Color(hex: 0x8b7cf0),
        cardTint: Color(hex: 0xeaf2ff), cardBorder: Color(hex: 0xb4cdff, alpha: 0.22))

    static let all: [PlannerTheme] = [.ember, .obsidian, .parchment, .pure, .midnight]

    static func resolve(_ id: String) -> PlannerTheme {
        all.first { $0.id == id } ?? .ember
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

extension PlannerStore {
    var theme: PlannerTheme { PlannerTheme.resolve(state.selectedTheme) }
}

/// HP-Ampel aus dem Design: >55 % grün, >25 % Bernstein, sonst Lachs.
enum HPTint {
    static func color(for creature: Creature) -> Color {
        guard creature.maxHitPoints > 0 else { return .secondary }
        if creature.hitPoints <= 0 { return Color.primary.opacity(0.35) }
        let p = creature.hpFraction
        if p > 0.55 { return Color(hex: 0x8fd68a) }
        if p > 0.25 { return Color(hex: 0xf2a54a) }
        return Color(hex: 0xff8a70)
    }
}

/// Kategorische Statusfarben — semantisch, in allen Themes gleich.
func statusCategoryColor(_ category: String, polarity: StatusPolarity) -> Color {
    switch category {
    case "physical": return Color(hex: 0xf97316)
    case "mental": return Color(hex: 0xa855f7)
    case "movement": return Color(hex: 0x22c55e)
    case "critical", "incapacitated": return Color(hex: 0xef4444)
    case "concentration": return Color(hex: 0x8b5cf6)
    case "good": return Color(hex: 0x4fac78)
    default: return polarity == .good ? Color(hex: 0x4fac78) : Color(hex: 0xc34956)
    }
}

// MARK: - Haupt-Layout

struct ContentView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.openWindow) private var openWindow
    @State private var selection: PlannerTab = .combat
    @State private var showingImport = false
    @State private var showingMonsterEditor = false
    @State private var editingMonster: MonsterTemplate?
    @State private var showingStatusLibrary = false
    @State private var selectedStatusCreature: Creature?
    @State private var encounterName = ""

    var body: some View {
        ZStack {
            LiquidBackground(theme: store.theme)
            VStack(spacing: 0) {
                InitiativeRail(selection: $selection)
                Divider().opacity(0.18)
                HStack(spacing: 0) {
                    Sidebar(selection: $selection, showingImport: $showingImport)
                    mainPanel
                }
            }
        }
        .sheet(isPresented: $showingImport) { MonsterImportView() }
        .sheet(isPresented: $showingMonsterEditor) {
            MonsterEditorView(template: editingMonster) { template in
                store.saveMonsterTemplate(template)
                showingMonsterEditor = false
            }
        }
        .sheet(isPresented: $showingStatusLibrary) { StatusLibraryView() }
        .sheet(item: $selectedStatusCreature) { creature in StatusPickerView(creature: creature) }
        // Konzentrations-Erinnerung: erscheint automatisch, wenn ein konzentrierender
        // Kämpfer Schaden erleidet (SG 10 oder halber Schaden — der höhere Wert).
        .sheet(item: Binding(
            get: { store.concentrationChecks.first },
            set: { newValue in
                if newValue == nil, let first = store.concentrationChecks.first {
                    store.dismissConcentrationCheck(first)
                }
            })) { check in
            ConcentrationCheckView(check: check)
        }
        .overlay(alignment: .bottomTrailing) { ToastView() }
        .preferredColorScheme(store.theme.isDark ? .dark : .light)
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Picker("Theme", selection: Binding(
                        get: { store.state.selectedTheme },
                        set: { id in store.setTheme(id, named: PlannerTheme.resolve(id).name) })) {
                        ForEach(PlannerTheme.all) { theme in
                            Label(theme.name, systemImage: theme.icon).tag(theme.id)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Theme", systemImage: "paintpalette")
                }
                .help("Farbwelt wechseln — Funktionen bleiben identisch")
                Button { store.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }.disabled(!store.canUndo)
                Button { store.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }.disabled(!store.canRedo)
                Button { openWindow(id: "player-view") } label: { Label("Player View", systemImage: "eye") }
            }
        }
    }

    @ViewBuilder private var mainPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch selection {
                case .combat:
                    CombatDashboard(selectedStatusCreature: $selectedStatusCreature)
                case .database:
                    DatabaseView(showingImport: $showingImport, showingMonsterEditor: $showingMonsterEditor, editingMonster: $editingMonster)
                case .encounters:
                    EncounterView(encounterName: $encounterName)
                case .statuses:
                    StatusLibraryView(embedded: true)
                case .log:
                    LogView()
                }
            }
            .padding(22)
        }
    }
}

enum PlannerTab: String, CaseIterable, Identifiable {
    case combat, database, encounters, statuses, log
    var id: String { rawValue }
    var label: String {
        switch self {
        case .combat: return "Kampf"
        case .database: return "Monster"
        case .encounters: return "Encounters"
        case .statuses: return "Status"
        case .log: return "Protokoll"
        }
    }
    var icon: String {
        switch self {
        case .combat: return "bolt.fill"
        case .database: return "books.vertical.fill"
        case .encounters: return "tray.full.fill"
        case .statuses: return "sparkles.rectangle.stack.fill"
        case .log: return "scroll.fill"
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var selection: PlannerTab
    @Binding var showingImport: Bool

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 30, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                Text("Initiative Planner Pro")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.bottom, 8)

            ForEach(PlannerTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.label, systemImage: tab.icon)
                        .fontWeight(selection == tab ? .semibold : .regular)
                        .foregroundStyle(selection == tab ? theme.accentBright : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    selection == tab ? AnyShapeStyle(theme.accent.opacity(0.16)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(selection == tab ? theme.accent.opacity(0.45) : .clear, lineWidth: 1))
            }

            Spacer()

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Import ist dauerhaft", systemImage: "internaldrive.fill")
                        .font(.headline)
                    Text("Importierte Monster werden sofort in der App-Datenbank gespeichert. Kein erneutes Laden, keine JSON-Importwege.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button { showingImport = true } label: { Label("Monster importieren", systemImage: "square.and.arrow.down.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                }
            }

            // Nur die Version — der Copyright-Vermerk hat seinen macOS-üblichen
            // Platz im Über-Dialog (aus der Info.plist).
            Text("Version \(Bundle.main.appVersionString)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
                .padding(.leading, 4)
        }
        .padding(18)
        .frame(width: 270)
        .background(.ultraThinMaterial)
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

// MARK: - Initiative-Leiste

struct InitiativeRail: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var selection: PlannerTab

    var body: some View {
        let theme = store.theme
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Runden-Pille im Design-Stil
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("RUNDE")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Text("\(store.state.round)")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.cardBorder, lineWidth: 1))
                .help("Rechtsklick: Runde auf 1 zurücksetzen")
                .contextMenu {
                    Button("Runde auf 1 zurücksetzen") { store.resetRound() }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AM ZUG")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(theme.accent)
                    Text(store.state.activeCreature?.name ?? "Keine Initiative gesetzt")
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                }
                Spacer()
                Button { store.previousTurn() } label: { Label("Zurück", systemImage: "chevron.left") }
                // Kein eigener Space-Shortcut am Button: der Menüeintrag „Kampf →
                // Nächster Zug" hat ihn bereits — doppelte Registrierung löste
                // den Zug doppelt aus und ließ die Runden davonlaufen.
                Button { store.nextTurn() } label: { Label("Nächster Zug", systemImage: "chevron.right") }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                Button { store.rollAllMonsterInitiative() } label: { Label("Monster-Ini", systemImage: "dice.fill") }
                Button { selection = .database } label: { Label("Datenbank", systemImage: "books.vertical") }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 10) {
                        if store.state.initiativeList.isEmpty {
                            Text("Füge Kämpfer hinzu und setze Initiative. Initiative 0 und negative Werte funktionieren.")
                                .foregroundStyle(.secondary)
                                .frame(height: 82)
                                .padding(.horizontal)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            ForEach(store.state.initiativeList) { creature in
                                InitiativeMiniCard(creature: creature)
                                    .id(creature.id)
                                    .onTapGesture { store.setActive(creature.id) }
                                    // Bei Initiative-Gleichstand: Karte auf eine andere ziehen,
                                    // um die Reihenfolge innerhalb der Gruppe festzulegen.
                                    .draggable(creature.id.uuidString)
                                    .dropDestination(for: String.self) { ids, _ in
                                        guard let idString = ids.first, let movedID = UUID(uuidString: idString) else { return false }
                                        store.moveCreature(movedID, before: creature.id)
                                        return true
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .onChange(of: store.state.activeID) { _, newValue in
                        if let id = newValue {
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

struct InitiativeMiniCard: View {
    @EnvironmentObject private var store: PlannerStore
    var creature: Creature

    var body: some View {
        let theme = store.theme
        let isActive = creature.id == store.state.activeID
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("INIT")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text("\(creature.currentInitiative ?? 0)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(isActive ? theme.accent : .primary)
                }
                Spacer()
                Text(creature.kind.emoji)
                    .font(.title3)
            }
            Text(creature.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
            if creature.maxHitPoints > 0 {
                HPBarView(creature: creature)
                Text("RK \(creature.armorClass) · \(creature.hitPoints)/\(creature.maxHitPoints) TP\(creature.temporaryHitPoints > 0 ? " +\(creature.temporaryHitPoints)" : "")")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 172, height: 118)
        .background(
            isActive
                ? AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.24), theme.tertiary.opacity(0.10)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isActive ? theme.accent.opacity(0.75) : theme.cardBorder, lineWidth: isActive ? 1.5 : 1))
        .shadow(color: isActive ? theme.accent.opacity(0.35) : .black.opacity(0.12), radius: isActive ? 18 : 10, y: 7)
        .opacity(creature.isDefeated ? 0.45 : 1)
        .scaleEffect(isActive ? 1.02 : 1)
        .animation(.spring(duration: 0.3), value: isActive)
    }
}

struct HPBarView: View {
    var creature: Creature
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.32))
                Capsule()
                    .fill(HPTint.color(for: creature))
                    .frame(width: max(0, geo.size.width * creature.hpFraction))
                    .animation(.easeOut(duration: 0.4), value: creature.hpFraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Kampf-Übersicht

struct CombatDashboard: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var selectedStatusCreature: Creature?
    @State private var name = ""
    @State private var kind: CreatureKind = .player
    @State private var ac = 10
    @State private var hp = ""
    @State private var bonus = 0
    @State private var initiative = ""

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Kämpfer hinzufügen", subtitle: "Spieler oder Monster manuell erstellen", icon: "plus.circle.fill")
                        HStack {
                            TextField("Name", text: $name)
                            Picker("Typ", selection: $kind) {
                                ForEach(CreatureKind.allCases) { Text($0.label).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                        HStack {
                            Stepper("RK \(ac)", value: $ac, in: 1...40)
                            TextField("HP oder Würfel", text: $hp)
                            Stepper("Ini \(bonus >= 0 ? "+" : "")\(bonus)", value: $bonus, in: -10...20)
                            TextField("Initiative sofort", text: $initiative)
                        }
                        HStack {
                            Button("Hinzufügen") {
                                store.addCreature(name: name, kind: kind, armorClass: ac, hpExpression: hp, initiativeBonus: bonus, initiative: Int(initiative))
                                name = ""; hp = ""; initiative = ""; ac = 10; bonus = 0
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(store.theme.accent)
                            Button("Leeren") { name = ""; hp = ""; initiative = ""; ac = 10; bonus = 0 }
                        }
                    }
                }
                SummaryCard()
            }

            CreatureSection(title: "Spieler", creatures: store.state.players, selectedStatusCreature: $selectedStatusCreature)
            CreatureSection(title: "Monster", creatures: store.state.monsters.sorted { ($0.currentInitiative ?? -999) > ($1.currentInitiative ?? -999) }, selectedStatusCreature: $selectedStatusCreature)
        }
    }
}

struct SummaryCard: View {
    @EnvironmentObject private var store: PlannerStore
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Schnellsteuerung", subtitle: "Auto-Save aktiv", icon: "switch.2")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    StatTile(title: "Spieler", value: "\(store.state.players.count)")
                    StatTile(title: "Monster", value: "\(store.state.monsters.count)")
                    StatTile(title: "Konz.", value: "\(store.state.allCreatures.filter { $0.statuses.contains { $0.id == "concentration" } }.count)")
                    StatTile(title: "Besiegt", value: "\(store.state.monsters.filter(\.isDefeated).count)")
                }
                HStack {
                    Button {
                        store.removeDefeatedMonsters()
                    } label: {
                        Label("Besiegte aufräumen", systemImage: "sparkles")
                    }
                    .help("Alle Monster auf 0 HP aus dem Kampf entfernen (⌘Z holt sie zurück)")
                    Button("Kampf leeren", role: .destructive) { store.clearCombat() }
                    Button("Log kopieren") { store.copyLogToPasteboard() }
                }
            }
        }
        .frame(width: 360)
    }
}

struct CreatureSection: View {
    var title: String
    var creatures: [Creature]
    @Binding var selectedStatusCreature: Creature?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title, subtitle: "\(creatures.count) Einträge", icon: title == "Spieler" ? "person.3.fill" : "pawprint.fill")
                if creatures.isEmpty {
                    EmptyState(text: "Noch keine Einträge.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
                        ForEach(creatures) { creature in
                            CreatureCard(creature: creature, selectedStatusCreature: $selectedStatusCreature)
                        }
                    }
                }
            }
        }
    }
}

struct CreatureCard: View {
    @EnvironmentObject private var store: PlannerStore
    var creature: Creature
    @Binding var selectedStatusCreature: Creature?
    @State private var damage = ""
    @State private var temp = ""
    @State private var initiative = ""
    @State private var showStatblock = false

    var activeStatuses: [(def: StatusDefinition, instance: StatusInstance)] {
        creature.statuses
            .compactMap { instance in
                store.state.statuses.first { $0.id == instance.id }.map { (def: $0, instance: instance) }
            }
            .sorted { $0.def.priority > $1.def.priority }
    }

    /// Statblock des zugehörigen Datenbank-Monsters (falls von dort hinzugefügt).
    var sourceStatblock: StatBlock? {
        guard let sourceID = creature.sourceMonsterID else { return nil }
        return store.state.monsterDatabase.first { $0.id == sourceID }?.statblock
    }

    var body: some View {
        let theme = store.theme
        let isActive = creature.id == store.state.activeID
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(creature.kind.emoji) \(creature.name)")
                        .font(.system(size: 16, weight: .bold))
                    Text("RK \(creature.armorClass) · Ini \(creature.initiativeBonus >= 0 ? "+" : "")\(creature.initiativeBonus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.setActive(creature.id) } label: { Image(systemName: "scope") }
                    .help("Aktiv setzen")
                Button { store.duplicateCreature(creature.id) } label: { Image(systemName: "plus.square.on.square") }
                    .help("Duplizieren")
                Button(role: .destructive) { store.deleteCreature(creature.id) } label: { Image(systemName: "xmark") }
                    .help("Entfernt sofort ohne Nachfrage")
            }
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(creature.maxHitPoints > 0 ? "\(creature.hitPoints)" : "—")
                        .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(HPTint.color(for: creature))
                    if creature.maxHitPoints > 0 {
                        Text("/ \(creature.maxHitPoints) TP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if creature.temporaryHitPoints > 0 {
                        Text("+\(creature.temporaryHitPoints)")
                            .font(.caption.bold())
                            .foregroundStyle(theme.accent)
                    }
                }
                Spacer()
                StatTile(title: "Initiative", value: creature.currentInitiative.map(String.init) ?? "—")
                    .frame(width: 100)
            }
            if creature.maxHitPoints > 0 {
                HPBarView(creature: creature, height: 7)
            }
            // Schnell-Schaden aus dem Design: −10 −5 −1 | +1 +5
            HStack(spacing: 6) {
                QuickHPButton(label: "−10", tint: .damage) { store.applyQuickHP(creature.id, delta: -10) }
                QuickHPButton(label: "−5", tint: .damage) { store.applyQuickHP(creature.id, delta: -5) }
                QuickHPButton(label: "−1", tint: .damage) { store.applyQuickHP(creature.id, delta: -1) }
                QuickHPButton(label: "+1", tint: .heal) { store.applyQuickHP(creature.id, delta: 1) }
                QuickHPButton(label: "+5", tint: .heal) { store.applyQuickHP(creature.id, delta: 5) }
            }
            HStack {
                TextField("Schaden/Heilung (12 oder 2d6+3)", text: $damage)
                Button("Schaden") { store.applyDamage(creature.id, expression: damage); damage = "" }
                Button("Heilung") { store.applyHealing(creature.id, expression: damage); damage = "" }
            }
            HStack {
                TextField("Temp HP", text: $temp)
                Button("Temp setzen") { store.setTemporaryHP(creature.id, amount: Int(temp) ?? 0); temp = "" }
                TextField("Initiative", text: $initiative)
                    .onSubmit { store.setInitiative(creature.id, initiative: Int(initiative)) }
                Button("🎲") { store.rollInitiative(creature.id) }
            }
            HStack(spacing: 6) {
                Button {
                    selectedStatusCreature = creature
                } label: {
                    Label("Status", systemImage: "sparkles")
                }
                .tint(theme.tertiary)
                ForEach(activeStatuses.prefix(5), id: \.def.id) { entry in
                    let status = entry.def
                    let color = statusCategoryColor(status.category, polarity: status.polarity)
                    // Chip klicken = Status entfernen (per ⌘Z rückholbar); Rechtsklick zeigt Regeln.
                    Button {
                        store.toggleStatus(status.id, for: creature.id)
                    } label: {
                        HStack(spacing: 3) {
                            Text(status.short + (entry.instance.duration.map { " · \($0)R" } ?? ""))
                                .font(.system(size: 10.5, weight: .bold))
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.20), in: Capsule())
                        .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("\(statusRulesTooltip(status))\n\nKlicken zum Entfernen")
                    .contextMenu {
                        Button("„\(status.label)“ entfernen") {
                            store.toggleStatus(status.id, for: creature.id)
                        }
                        Divider()
                        Text(status.description)
                        ForEach(status.effects, id: \.self) { effect in
                            Text("• \(effect)")
                        }
                    }
                }
            }
            if creature.isDefeated {
                if creature.kind == .player {
                    DeathSaveView(creature: creature)
                } else {
                    Text("💀 Auf 0 HP — bleibt zur Kontrolle im Encounter.")
                        .font(.caption)
                        .foregroundStyle(theme.isDark ? Color(hex: 0xff8a70) : Color(hex: 0x9c2a1c))
                }
            }

            // Aktionen & Fähigkeiten aus der Monsterdatenbank — direkt im Kampf aufklappbar
            if let statblock = sourceStatblock {
                DisclosureGroup(isExpanded: $showStatblock) {
                    StatBlockView(statblock: statblock, sectionsInitiallyExpanded: true)
                        .padding(.top, 6)
                } label: {
                    Label("Aktionen & Statblock", systemImage: "book.closed.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .padding(14)
        .background(
            isActive
                ? AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.16), theme.tertiary.opacity(0.06)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isActive ? theme.accent.opacity(0.7) : theme.cardBorder, lineWidth: isActive ? 1.5 : 1))
        .shadow(color: isActive ? theme.accent.opacity(0.25) : .clear, radius: 16, y: 6)
        .opacity(creature.isDefeated ? 0.75 : 1)
        .onAppear { initiative = creature.currentInitiative.map(String.init) ?? "" }
    }
}

/// Dialog für fällige Konzentrationsproben nach erlittenem Schaden.
struct ConcentrationCheckView: View {
    @EnvironmentObject private var store: PlannerStore
    let check: PlannerStore.ConcentrationCheck

    var body: some View {
        let theme = store.theme
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34))
                .foregroundStyle(theme.tertiary)
            Text("Konzentrationsprobe!")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
            Text("\(check.creatureName) hat \(check.damage) Schaden erlitten und konzentriert sich auf einen Effekt.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 3) {
                Text("KONSTITUTIONSRETTUNGSWURF")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Text("SG \(check.dc)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(theme.accent)
                Text(check.dc > 10
                     ? "Halber Schaden (\(check.damage) ÷ 2 = \(check.dc)) — höher als SG 10"
                     : "SG 10 — höher als der halbe Schaden (\(check.damage) ÷ 2)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1))

            HStack(spacing: 8) {
                Button {
                    store.resolveConcentrationCheck(check, passed: false)
                } label: {
                    Label("Verpatzt — Konzentration endet", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: 0xd9503c))

                Button {
                    store.resolveConcentrationCheck(check, passed: true)
                } label: {
                    Label("Bestanden", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x4fac78))
                .keyboardShortcut(.defaultAction)
            }
            Button("Ignorieren") { store.dismissConcentrationCheck(check) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(22)
        .frame(width: 400)
        .background(LiquidBackground(theme: theme))
    }
}

/// Todesrettungswürfe bei 0 TP: je drei abhakbare Slots für Erfolge und Misserfolge.
struct DeathSaveView: View {
    @EnvironmentObject private var store: PlannerStore
    var creature: Creature

    var body: some View {
        let successes = creature.deathSaveSuccesses ?? 0
        let failures = creature.deathSaveFailures ?? 0
        let dead = failures >= 3
        let stable = successes >= 3
        let green = Color(hex: 0x4fac78)
        let red = Color(hex: 0xd9503c)

        VStack(alignment: .leading, spacing: 6) {
            Text("TODESRETTUNGSWÜRFE")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                slotRow(label: "Erfolge", count: successes, color: green) { newValue in
                    store.setDeathSaves(creature.id, successes: newValue, failures: failures)
                }
                slotRow(label: "Misserfolge", count: failures, color: red) { newValue in
                    store.setDeathSaves(creature.id, successes: successes, failures: newValue)
                }
                Spacer()
                if dead {
                    Text("💀 Gestorben")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(red)
                } else if stable {
                    Text("Stabilisiert")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(green)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(red.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(red.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private func slotRow(label: String, count: Int, color: Color, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(1...3, id: \.self) { slot in
                Button {
                    // Klick auf gefüllten Slot nimmt ihn zurück, sonst bis hierhin füllen.
                    onChange(count >= slot ? slot - 1 : slot)
                } label: {
                    Image(systemName: count >= slot ? "circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(count >= slot ? color : .secondary)
                }
                .buttonStyle(.plain)
                .help(count >= slot ? "Zurücknehmen" : "\(label): \(slot). abhaken")
            }
        }
    }
}

/// Schnell-HP-Buttons im Design-Stil (rot/grün getönte Pills).
/// Textfarben passen sich hell/dunkel an, damit sie in jedem Theme lesbar sind.
struct QuickHPButton: View {
    enum Tint { case damage, heal }
    @EnvironmentObject private var store: PlannerStore
    let label: String
    let tint: Tint
    let action: () -> Void

    var body: some View {
        let dark = store.theme.isDark
        let textColor: Color = tint == .damage
            ? (dark ? Color(hex: 0xffb9a6) : Color(hex: 0x8c2015))
            : (dark ? Color(hex: 0xbce8b0) : Color(hex: 0x1f5c22))
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    tint == .damage ? Color(hex: 0xbe372d, alpha: dark ? 0.22 : 0.12) : Color(hex: 0x50a050, alpha: dark ? 0.18 : 0.12),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint == .damage ? Color(hex: 0xd9503c, alpha: 0.5) : Color(hex: 0x78be6e, alpha: 0.5), lineWidth: 1))
                .foregroundStyle(textColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Monsterdatenbank (cleane Zeilen wie im Design 1c)

struct DatabaseView: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var showingImport: Bool
    @Binding var showingMonsterEditor: Bool
    @Binding var editingMonster: MonsterTemplate?
    @State private var search = ""
    @State private var crFilter = ""
    @State private var quantity = 1
    @State private var dropTargeted = false

    static let crOptions = ["", "0", "1/8", "1/4", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10+", "15+", "20+"]

    // Datenbank ist im Store dauerhaft sortiert — hier nur noch filtern.
    var filtered: [MonsterTemplate] {
        let query = search.lowercased()
        return store.state.monsterDatabase.filter { monster in
            let searchOK = query.isEmpty
                || monster.name.lowercased().contains(query)
                || monster.type.lowercased().contains(query)
                || monster.source.lowercased().contains(query)
                || monster.challengeRating.lowercased().contains(query)
                || monster.notes.lowercased().contains(query)
            let crOK: Bool
            if crFilter.isEmpty {
                crOK = true
            } else if crFilter.hasSuffix("+") {
                let threshold = Double(crFilter.dropLast()) ?? 0
                crOK = challengeRatingValue(monster.challengeRating) >= threshold
            } else {
                crOK = monster.challengeRating == crFilter
            }
            return searchOK && crOK
        }
    }

    var body: some View {
        let theme = store.theme
        // Kopf als kompakte Karte, die Zeilen als eigene LazyVStack darunter —
        // so bleibt bei 500+ Monstern kein riesiger Material-/Schattenblock zu rendern.
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Monster-Datenbank", subtitle: "Dauerhaft in der App gespeichert", icon: "books.vertical.fill")
                    HStack {
                        TextField("Suchen…", text: $search)
                        Picker("HG", selection: $crFilter) {
                            ForEach(Self.crOptions, id: \.self) { option in
                                Text(option.isEmpty ? "Alle HG" : "HG \(option)").tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        Stepper("Menge \(quantity)", value: $quantity, in: 1...50)
                        Picker("HP", selection: Binding(get: { store.state.hpMode }, set: { store.setHPMode($0) })) {
                            ForEach(HPMode.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented).frame(width: 220)
                        Button { showingImport = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                        Button { presentMonsterFolderPicker(store: store) } label: { Label("Ordner", systemImage: "folder.badge.plus") }
                            .help("Ordner wählen — alle passenden .md-Dateien aus dem Ordner und allen Unterordnern importieren")
                        Button { editingMonster = nil; showingMonsterEditor = true } label: { Label("Neu", systemImage: "plus") }
                        Button(role: .destructive) {
                            confirmClearDatabase()
                        } label: { Label("Alle löschen", systemImage: "trash") }
                            .help("Gesamte Monsterdatenbank leeren (mit Rückfrage; ⌘Z stellt wieder her)")
                            .disabled(store.state.monsterDatabase.isEmpty)
                    }
                    HStack {
                        Text("Neue Monster kommen über den Import, „Neu“ — oder per Drag & Drop: .md-Dateien oder ganze Ordner einfach hier fallen lassen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(filtered.count) von \(store.state.monsterDatabase.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if store.state.monsterDatabase.isEmpty {
                // Erststart: Die App wird bewusst ohne Monster ausgeliefert.
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Deine Monsterdatenbank ist noch leer.")
                        .font(.system(size: 14, weight: .bold))
                    Text("Importiere deine eigene Sammlung: Ordner oder .md-Dateien einfach hierher ziehen, über „Ordner“ auswählen oder mit „Neu“ manuell anlegen. Alles wird dauerhaft in der App gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                    Button { presentMonsterFolderPicker(store: store) } label: {
                        Label("Ordner importieren", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
            } else if filtered.isEmpty {
                EmptyState(text: "Keine Monster gefunden.")
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(filtered) { monster in
                        MonsterDBRow(monster: monster, quantity: quantity, showingMonsterEditor: $showingMonsterEditor, editingMonster: $editingMonster)
                    }
                }
            }
        }
        // Drag & Drop: .md-Dateien und Ordner aus dem Finder direkt hier ablegen.
        .dropDestination(for: URL.self) { urls, _ in
            store.importMonsterURLs(urls)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 2.5, dash: [10, 6]))
                    .background(theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        Label("Zum dauerhaften Importieren fallen lassen", systemImage: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.accent, lineWidth: 1))
                    }
                    .allowsHitTesting(false)
            }
        }
    }

    /// Destruktive Massenaktion → bewusst mit Rückfrage (⌘Z stellt trotzdem wieder her).
    private func confirmClearDatabase() {
        let count = store.state.monsterDatabase.count
        let alert = NSAlert()
        alert.messageText = "Alle \(count) Monster aus der Datenbank löschen?"
        alert.informativeText = "Kämpfer im aktuellen Kampf und gespeicherte Encounters bleiben unberührt. Mit ⌘Z lässt sich das Löschen rückgängig machen."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Alle löschen")
        alert.addButton(withTitle: "Abbrechen")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearMonsterDatabase()
        }
    }
}

/// Kompakte Datenbank-Zeile nach Design 1c: „TP 7 · RK 15 · HG 1/4“ + „+“-Button.
struct MonsterDBRow: View {
    @EnvironmentObject private var store: PlannerStore
    var monster: MonsterTemplate
    var quantity: Int
    @Binding var showingMonsterEditor: Bool
    @Binding var editingMonster: MonsterTemplate?
    @State private var hovering = false
    @State private var expanded = false

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 0) {
            // Kopfzeile — Klick irgendwo auf den Textbereich klappt Details auf
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(monster.name)
                            .font(.system(size: 13.5, weight: .bold))
                            .lineLimit(1)
                        if !monster.type.isEmpty {
                            Text(monster.type)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.13), in: Capsule())
                                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.35), lineWidth: 1))
                                .foregroundStyle(theme.accentBright)
                                .lineLimit(1)
                        }
                        if !monster.source.isEmpty {
                            Text(monster.source)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(theme.tertiary.opacity(0.14), in: Capsule())
                                .overlay(Capsule().strokeBorder(theme.tertiary.opacity(0.4), lineWidth: 1))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Text("TP \(monster.hpAverage) (\(monster.hpDice)) · RK \(monster.armorClass) · HG \(monster.challengeRating) · Ini \(monster.initiativeBonus >= 0 ? "+" : "")\(monster.initiativeBonus)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button { editingMonster = monster; showingMonsterEditor = true } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .help("Bearbeiten")
                    .opacity(hovering ? 1 : 0.35)
                Button(role: .destructive) { store.deleteMonsterTemplate(monster.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Aus Datenbank löschen")
                    .opacity(hovering ? 1 : 0.35)
                Button {
                    store.addMonsterFromDatabase(monster, quantity: quantity, mode: store.state.hpMode)
                } label: {
                    Label(quantity > 1 ? "\(quantity)×" : "", systemImage: store.state.hpMode == .roll ? "dice.fill" : "plus")
                        .labelStyle(quantity > 1 ? AnyLabelStyle(.titleAndIcon) : AnyLabelStyle(.iconOnly))
                        .font(.system(size: 13, weight: .bold))
                        .frame(minWidth: 30, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .help(store.state.hpMode == .roll ? "Mit gewürfelten HP (\(monster.hpDice)) zum Kampf hinzufügen" : "Mit Ø \(monster.hpAverage) HP zum Kampf hinzufügen")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
            }

            // Detailbereich: Statblock, Notizen und Import-Infos
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let statblock = monster.statblock {
                        StatBlockView(statblock: statblock, sectionsInitiallyExpanded: true)
                    }
                    if !monster.notes.isEmpty {
                        Text(monster.notes)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else if monster.statblock == nil {
                        Text("Keine weiteren Details hinterlegt. Erneuter Import der .md-Datei ergänzt den vollständigen Statblock.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Text("Würfel \(monster.hpDice)\(monster.source.isEmpty ? "" : " · Quelle: \(monster.source)")\(monster.importedAt.map { " · importiert am \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
                .padding(.leading, 21)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(store.theme.isDark ? 0.16 : 0.03), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(hovering ? theme.accent.opacity(0.45) : theme.cardBorder.opacity(0.6), lineWidth: 1))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Statblock-Ansicht (Datenbank & Kampf)

struct StatBlockView: View {
    @EnvironmentObject private var store: PlannerStore
    let statblock: StatBlock
    /// Im Kampf: Abschnitte standardmäßig eingeklappt, in der Datenbank offen.
    var sectionsInitiallyExpanded: Bool = true

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 8) {
            if !statblock.subtitle.isEmpty {
                Text(statblock.subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .italic()
                    .foregroundStyle(.secondary)
            }

            // Meta-Zeilen (nur nicht-leere)
            VStack(alignment: .leading, spacing: 2.5) {
                metaRow("🏷️", [statblock.size, statblock.alignment].filter { !$0.isEmpty }.joined(separator: " · "))
                metaRow("🏃", statblock.speed)
                metaRow("👁️", statblock.senses)
                metaRow("🗣️", statblock.languages)
                metaRow("📋", statblock.skills)
                metaRow("⚔️", statblock.equipment)
                metaRow("⭐", [statblock.xp.isEmpty ? "" : "EP \(statblock.xp)",
                               statblock.proficiency.isEmpty ? "" : "ÜB \(statblock.proficiency)"]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
            }

            // Attributs-Tabelle
            if !statblock.abilities.isEmpty {
                HStack(spacing: 5) {
                    ForEach(statblock.abilities, id: \.label) { ability in
                        VStack(spacing: 1) {
                            Text(ability.label)
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.secondary)
                            Text("\(ability.score)")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                            Text("\(ability.mod) / \(ability.save)")
                                .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(.black.opacity(theme.isDark ? 0.18 : 0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(theme.cardBorder.opacity(0.5), lineWidth: 1))
                    }
                }
            }

            // Abwehr-Chips
            let defenses: [(String, String, Color)] = [
                ("⚠️ Anfällig", statblock.vulnerabilities, Color(hex: 0xf97316)),
                ("🔰 Resistent", statblock.resistances, Color(hex: 0x22c55e)),
                ("🚫 Immun", statblock.immunities, Color(hex: 0x6fa8f5))
            ].filter { !$0.1.isEmpty }
            if !defenses.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(defenses, id: \.0) { label, value, color in
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(label)
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.16), in: Capsule())
                                .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
                            Text(value)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            abilitySection("Merkmale", icon: "star.fill", items: statblock.traits)
            abilitySection("Aktionen", icon: "burst.fill", items: statblock.actions)
            abilitySection("Bonusaktionen", icon: "plus.circle.fill", items: statblock.bonusActions)
            abilitySection("Reaktionen", icon: "arrowshape.turn.up.left.fill", items: statblock.reactions)
            abilitySection("Legendäre Aktionen", icon: "crown.fill", items: statblock.legendaryActions, intro: statblock.legendaryIntro)
        }
    }

    @ViewBuilder
    private func metaRow(_ icon: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(icon).font(.system(size: 9))
                Text(value)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func abilitySection(_ title: String, icon: String, items: [NamedAbility], intro: String = "") -> some View {
        if !items.isEmpty {
            StatBlockSection(title: title, icon: icon, items: items, intro: intro,
                             expanded: sectionsInitiallyExpanded)
        }
    }
}

/// Einzelner Statblock-Abschnitt mit eigenem Auf-/Zuklapp-Zustand.
struct StatBlockSection: View {
    @EnvironmentObject private var store: PlannerStore
    let title: String
    let icon: String
    let items: [NamedAbility]
    let intro: String
    @State var expanded: Bool

    var body: some View {
        let theme = store.theme
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 7) {
                if !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(item.name)
                            .font(.system(size: 11.5, weight: .bold))
                        Text(item.text)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.leading, 2)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text("\(title) (\(items.count))")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.4)
            }
            .foregroundStyle(theme.accent)
        }
    }
}

struct AnyLabelStyle: LabelStyle {
    private let apply: (Configuration) -> AnyView
    init(_ style: some LabelStyle) {
        apply = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        apply(configuration)
    }
}

// MARK: - Encounters

struct EncounterView: View {
    @EnvironmentObject private var store: PlannerStore
    @Binding var encounterName: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Encounter Management", subtitle: "Benannte Spielstände, intern gespeichert", icon: "tray.full.fill")
                HStack {
                    TextField("Encounter Name", text: $encounterName)
                    Button("Speichern") { store.saveEncounter(name: encounterName); encounterName = "" }
                        .buttonStyle(.borderedProminent)
                        .tint(store.theme.accent)
                }
                if store.state.encounters.isEmpty { EmptyState(text: "Noch keine Encounters gespeichert.") } else {
                    ForEach(store.state.encounters) { encounter in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(encounter.name).font(.headline)
                                Text("Runde \(encounter.round) · \(encounter.players.count) Spieler · \(encounter.monsters.count) Monster · \(encounter.savedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Laden") { store.loadEncounter(encounter) }
                            Button("Löschen", role: .destructive) { store.deleteEncounter(encounter.id) }
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(store.theme.cardBorder.opacity(0.6), lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - Protokoll

struct LogView: View {
    @EnvironmentObject private var store: PlannerStore
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: "Kampf-Log", subtitle: "Automatisch gespeichert", icon: "scroll.fill")
                    Spacer()
                    Button("Kopieren") { store.copyLogToPasteboard() }
                    Button("Leeren", role: .destructive) { store.clearLog() }
                }
                if store.state.log.isEmpty { EmptyState(text: "Noch keine Einträge.") } else {
                    ForEach(store.state.log.reversed()) { entry in
                        HStack(alignment: .top) {
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .monospacedDigit()
                                .foregroundStyle(store.theme.accent)
                            Text(entry.message)
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .padding(9)
                        .background(.black.opacity(store.theme.isDark ? 0.20 : 0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Status-Bibliothek & Picker

let STATUS_CATEGORY_OPTIONS: [(key: String, label: String)] = [
    ("physical", "physisch"), ("mental", "mental"), ("movement", "Bewegung"),
    ("critical", "kritisch"), ("incapacitated", "kampfunfähig"),
    ("concentration", "Konzentration"), ("good", "gut")
]

func statusCategoryLabel(_ key: String) -> String {
    STATUS_CATEGORY_OPTIONS.first { $0.key == key }?.label ?? key
}

struct StatusLibraryView: View {
    @EnvironmentObject private var store: PlannerStore
    var embedded: Bool = false
    @State private var search = ""
    @State private var formTarget: StatusFormTarget?

    struct StatusFormTarget: Identifiable {
        var status: StatusDefinition?   // nil = neuen Status anlegen
        var id: String { status?.id ?? "neu" }
    }

    var body: some View {
        Group {
            if embedded {
                libraryContent
            } else {
                ScrollView { libraryContent.padding(22) }
                    .frame(minWidth: 960, minHeight: 660)
                    .background(LiquidBackground(theme: store.theme))
            }
        }
        .sheet(item: $formTarget) { target in
            StatusFormView(existing: target.status)
        }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Status-Bibliothek",
                              subtitle: "\(store.state.statuses.count) Zustände & Marker · offizielle sind schreibgeschützt",
                              icon: "sparkles.rectangle.stack.fill")
                Spacer()
                Button { formTarget = StatusFormTarget(status: nil) } label: { Label("Neuer Status", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.accent)
            }
            TextField("Status suchen…", text: $search)
            HStack(alignment: .top, spacing: 14) {
                statusColumn(title: "🟢 Gute / hilfreiche Stati", polarity: .good)
                statusColumn(title: "🔴 Schlechte / hinderliche Stati", polarity: .bad)
            }
        }
    }

    private func filteredStatuses(_ polarity: StatusPolarity) -> [StatusDefinition] {
        let query = search.lowercased()
        return store.state.statuses
            .filter { $0.polarity == polarity }
            .filter { query.isEmpty
                || $0.label.lowercased().contains(query)
                || $0.short.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.label.localizedStandardCompare($1.label) == .orderedAscending
            }
    }

    @ViewBuilder
    private func statusColumn(title: String, polarity: StatusPolarity) -> some View {
        let items = filteredStatuses(polarity)
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
            if items.isEmpty {
                EmptyState(text: "Keine Treffer.")
            }
            ForEach(items, id: \.id) { status in
                StatusLibraryCard(status: status) {
                    formTarget = StatusFormTarget(status: status)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct StatusLibraryCard: View {
    @EnvironmentObject private var store: PlannerStore
    let status: StatusDefinition
    let onEdit: () -> Void

    var body: some View {
        let color = statusCategoryColor(status.category, polarity: status.polarity)
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(status.label).font(.system(size: 13.5, weight: .bold))
                Text(status.short)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
                Text(statusCategoryLabel(status.category))
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
                if status.isOfficial {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .help("Offizieller Zustand — schreibgeschützt")
                } else {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                        .help("Eigenen Status bearbeiten")
                    Button(role: .destructive) { store.deleteStatus(status.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Eigenen Status löschen")
                }
            }
            Text(status.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !status.effects.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(status.effects, id: \.self) { effect in
                            Text("• \(effect)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 3)
                } label: {
                    Text("Regeln (\(status.effects.count))")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(store.theme.accent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color.opacity(0.30), lineWidth: 1))
    }
}

/// Formular für neue und bestehende eigene Stati — im Stil des Monster-Editors.
struct StatusFormView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    var existing: StatusDefinition?

    @State private var label = ""
    @State private var short = ""
    @State private var category = "physical"
    @State private var polarity: StatusPolarity = .bad
    @State private var priority = 1
    @State private var descriptionText = ""
    @State private var rulesText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: existing == nil ? "Neuer Status" : "Status bearbeiten",
                          subtitle: "Eigene Stati mit Kurzform, Kategorie und Regelwirkungen",
                          icon: "sparkles")
            Form {
                TextField("Label", text: $label)
                TextField("Kurzform", text: $short)
                Picker("Kategorie", selection: $category) {
                    ForEach(STATUS_CATEGORY_OPTIONS, id: \.key) { option in
                        Text(option.label).tag(option.key)
                    }
                }
                Picker("Polung", selection: $polarity) {
                    Text("gut / hilfreich").tag(StatusPolarity.good)
                    Text("schlecht / hinderlich").tag(StatusPolarity.bad)
                }
                Stepper("Priorität \(priority)", value: $priority, in: 0...10)
                TextField("Beschreibung", text: $descriptionText, axis: .vertical)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Regelwirkungen — eine pro Zeile (optional)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $rulesText)
                    .font(.system(size: 12))
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(store.theme.cardBorder, lineWidth: 1))
            }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Speichern") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
        .background(LiquidBackground(theme: store.theme))
        .onAppear {
            guard let existing else { return }
            label = existing.label
            short = existing.short
            category = existing.category
            polarity = existing.polarity
            priority = existing.priority
            descriptionText = existing.description
            rulesText = existing.effects.joined(separator: "\n")
        }
    }

    private func save() {
        let effects = rulesText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let existing {
            var updated = existing
            updated.label = label.trimmingCharacters(in: .whitespaces)
            updated.short = short.isEmpty ? String(label.prefix(4)) : short
            updated.category = category
            updated.polarity = polarity
            updated.priority = priority
            updated.description = descriptionText
            updated.effects = effects
            store.updateStatus(updated)
        } else {
            store.addStatus(label: label, short: short, category: category,
                            polarity: polarity, priority: priority,
                            description: descriptionText, effects: effects)
        }
        dismiss()
    }
}

struct StatusPickerView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    var creature: Creature
    @State private var search = ""

    var body: some View {
        let theme = store.theme
        let active = activeDefs
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Status für \(creature.name)",
                              subtitle: "\(active.count) aktiv · Antippen zum Umschalten",
                              icon: "sparkles")
                Spacer()
                Button("Fertig") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .keyboardShortcut(.defaultAction)
            }

            // Aktive Stati immer oben — Klick entfernt direkt, Dauer wird angezeigt.
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AKTIV")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(theme.accent)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 6)], spacing: 6) {
                        ForEach(active, id: \.def.id) { entry in
                            let status = entry.def
                            let color = statusCategoryColor(status.category, polarity: status.polarity)
                            Button {
                                store.toggleStatus(status.id, for: creature.id)
                            } label: {
                                HStack(spacing: 5) {
                                    Text(status.label + (entry.instance.duration.map { " · \($0)R" } ?? ""))
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.20), in: Capsule())
                                .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("„\(status.label)“ entfernen")
                        }
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TextField("Status suchen…", text: $search)

            ScrollView {
                HStack(alignment: .top, spacing: 14) {
                    pickerColumn(title: "🟢 Gute / hilfreiche Stati", polarity: .good)
                    pickerColumn(title: "🔴 Schlechte / hinderliche Stati", polarity: .bad)
                }
            }
        }
        .padding(22)
        .frame(minWidth: 920, minHeight: 660)
        .background(LiquidBackground(theme: store.theme))
    }

    /// Immer den aktuellen Zustand aus dem Store lesen, damit Toggles sofort sichtbar sind.
    private var liveCreature: Creature {
        store.state.allCreatures.first { $0.id == creature.id } ?? creature
    }

    private var activeDefs: [(def: StatusDefinition, instance: StatusInstance)] {
        liveCreature.statuses
            .compactMap { instance in
                store.state.statuses.first { $0.id == instance.id }.map { (def: $0, instance: instance) }
            }
            .sorted { $0.def.priority > $1.def.priority }
    }

    @ViewBuilder
    private func pickerColumn(title: String, polarity: StatusPolarity) -> some View {
        let query = search.lowercased()
        let items = store.state.statuses
            .filter { $0.polarity == polarity }
            .filter { query.isEmpty
                || $0.label.lowercased().contains(query)
                || $0.short.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.label.localizedStandardCompare($1.label) == .orderedAscending
            }
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
            if items.isEmpty {
                EmptyState(text: "Keine Treffer.")
            }
            ForEach(items, id: \.id) { status in
                let instance = liveCreature.statuses.first { $0.id == status.id }
                StatusPickerRow(status: status,
                                active: instance != nil,
                                duration: instance?.duration,
                                onDurationChange: instance == nil ? nil : { newDuration in
                                    store.setStatusDuration(creature.id, statusID: status.id, duration: newDuration)
                                }) {
                    store.toggleStatus(status.id, for: creature.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct StatusPickerRow: View {
    @EnvironmentObject private var store: PlannerStore
    let status: StatusDefinition
    let active: Bool
    var duration: Int? = nil
    var onDurationChange: ((Int?) -> Void)? = nil
    let action: () -> Void

    var body: some View {
        let color = statusCategoryColor(status.category, polarity: status.polarity)
        VStack(alignment: .leading, spacing: 6) {
            // Kopf ist der Umschalter …
            Button(action: action) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(status.label).font(.system(size: 13.5, weight: .bold))
                        Spacer()
                        Image(systemName: active ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(active ? color : .secondary)
                    }
                    Text(status.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Dauer in Runden — zählt beim Zugwechsel automatisch herunter.
            if active, let onDurationChange {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Stepper(value: Binding(
                        get: { duration ?? 0 },
                        set: { newValue in onDurationChange(newValue <= 0 ? nil : newValue) }
                    ), in: 0...99) {
                        Text(duration.map { "Dauer: \($0) Runde\($0 == 1 ? "" : "n")" } ?? "Dauer: unbegrenzt")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .controlSize(.mini)
                }
                .help("Zählt bei jedem Zug dieses Kämpfers herunter; bei 0 endet der Status automatisch.")
            }

            // … die Regeln klappen separat auf, ohne den Status umzuschalten.
            if !status.effects.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(status.effects, id: \.self) { effect in
                            Text("• \(effect)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 3)
                } label: {
                    Text("Was bedeutet das?")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(store.theme.accent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? AnyShapeStyle(color.opacity(0.16)) : AnyShapeStyle(.thinMaterial), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(active ? color.opacity(0.6) : store.theme.cardBorder.opacity(0.5), lineWidth: 1))
    }
}

/// Vollständige Regelwirkung als Tooltip-Text (für Picker-Zeilen und Status-Chips).
func statusRulesTooltip(_ status: StatusDefinition) -> String {
    var parts = [status.label]
    if !status.description.isEmpty { parts.append(status.description) }
    parts.append(contentsOf: status.effects.map { "• \($0)" })
    return parts.joined(separator: "\n")
}

// MARK: - Monster-Editor & Import

struct MonsterEditorView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    var template: MonsterTemplate?
    var onSave: (MonsterTemplate) -> Void
    @State private var name = ""
    @State private var ac = 10
    @State private var cr = ""
    @State private var ini = 0
    @State private var hpAverage = 1
    @State private var hpDice = "1d8"
    @State private var type = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: template == nil ? "Neues Monster" : "Monster bearbeiten", subtitle: "Wird dauerhaft in der App-Datenbank gespeichert", icon: "pawprint.fill")
            Form {
                TextField("Name", text: $name)
                Stepper("RK \(ac)", value: $ac, in: 1...40)
                TextField("CR/HG", text: $cr)
                Stepper("Ini \(ini >= 0 ? "+" : "")\(ini)", value: $ini, in: -10...30)
                Stepper("Durchschnitts-HP \(hpAverage)", value: $hpAverage, in: 1...9999)
                TextField("HP-Würfel", text: $hpDice)
                TextField("Typ", text: $type)
                TextField("Notizen", text: $notes, axis: .vertical)
            }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Speichern") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.accent)
            }
        }
        .padding(22)
        .frame(width: 620)
        .background(LiquidBackground(theme: store.theme))
        .onAppear {
            if let template {
                name = template.name; ac = template.armorClass; cr = template.challengeRating; ini = template.initiativeBonus; hpAverage = template.hpAverage; hpDice = template.hpDice; type = template.type; notes = template.notes
            }
        }
    }

    private func save() {
        let id = template?.id ?? name.slugifiedMonsterID
        // statblock durchreichen — manuelles Bearbeiten darf den Import nicht verwerfen
        onSave(MonsterTemplate(id: id, name: name, armorClass: ac, hpAverage: hpAverage, hpDice: hpDice, challengeRating: cr, initiativeBonus: ini, type: type, source: template?.source ?? "App", notes: notes, importedAt: template?.importedAt, statblock: template?.statblock))
    }
}

/// Öffnet einen Ordner-Dialog und importiert rekursiv alle passenden .md-Dateien.
@MainActor
func presentMonsterFolderPicker(store: PlannerStore) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Ordner mit Monster-.md-Dateien auswählen — alle Unterordner werden durchsucht"
    panel.prompt = "Importieren"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    store.importMonsterFolder(url)
}

struct MonsterImportView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""
    @State private var sourceName = "Manueller Import"
    @State private var importingFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Monster importieren", subtitle: "Einmal importieren – danach dauerhaft in der App", icon: "square.and.arrow.down.fill")
            Text("Unterstützt .txt/.md mit Markdown-Frontmatter oder einfachen Schlüssel/Wert-Blöcken: name, rk/ac, tp/hp, hg/cr, initiative, typ.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Ordner-Import: rekursiv, nur Dateien mit passenden Monster-Werten
            HStack(spacing: 10) {
                Button {
                    presentMonsterFolderPicker(store: store)
                    dismiss()
                } label: {
                    Label("Ordner importieren (inkl. aller Unterordner)", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(store.theme.accent)
                Text("Zieht alle passenden .md-Dateien aus dem Ordner und seinen Unterordnern — Notizen ohne Monster-Werte werden übersprungen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(store.theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(store.theme.accent.opacity(0.3), lineWidth: 1))

            HStack { TextField("Quelle/Name", text: $sourceName); Button(".txt/.md wählen") { importingFile = true } }
            TextEditor(text: $importText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 320)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(store.theme.cardBorder, lineWidth: 1))
            HStack {
                Button("Beispiel einsetzen") { importText = """
---
name: Nebelweber
typ: Monstrosität
rk: 14
tp: "39 (6W8+12)"
hg: 2
initiative: +2
bewegungsrate: "9 m, Klettern 9 m"
resistenzen: [Kälte]
---

## Merkmale

**Nebelhülle:** Der Nebelweber ist in dichtem Nebel leicht verschleiert und kann sich als Bonusaktion verstecken.

## Aktionen

**Biss:** *Nahkampfangriffswurf:* +4, Reichweite 1,5 m. *Treffer:* 7 (1W8+2) Stichschaden plus 3 (1W6) Kälteschaden.

**Nebelfaden (Aufladung 5–6):** *Geschicklichkeitsrettungswurf:* SG 12; eine Kreatur im Abstand von bis zu 9 m. *Misserfolg:* Das Ziel ist festgesetzt (Flucht-SG 12).
""" }
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Dauerhaft importieren") { store.importMonsterText(importText, sourceName: sourceName); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.theme.accent)
            }
        }
        .padding(22)
        .frame(minWidth: 780, minHeight: 620)
        .background(LiquidBackground(theme: store.theme))
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.plainText, .utf8PlainText, .text, UTType(filenameExtension: "md") ?? .text]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                importText = try String(contentsOf: url, encoding: .utf8)
                sourceName = url.deletingPathExtension().lastPathComponent
            } catch { store.notice("Datei konnte nicht gelesen werden: \(error.localizedDescription)", style: "error") }
        }
    }
}

// MARK: - Player View: „Der Ring“ (Design-Variante 1b)
// Radiale Zugreihenfolge — der Ring dreht sich beim Zugwechsel, oben ▼ ist
// immer dran. In der Mitte eine Glas-Scheibe mit dem aktiven Kämpfer.
// Zeigt bewusst keine HP oder DM-Werte, nur Reihenfolge und Zustände.

struct PlayerViewWindow: View {
    @EnvironmentObject private var store: PlannerStore
    /// Kumulierte „virtuelle“ Position des aktiven Kämpfers — erlaubt weiche
    /// Rotation auf kürzestem Weg, auch beim Rundenwechsel (letzter → erster).
    @State private var virtualActive: Double = 0
    @State private var pulse = false
    @State private var decoSpin = false

    private var list: [Creature] { store.state.initiativeList }
    private var activeIndex: Int {
        list.firstIndex { $0.id == store.state.activeID } ?? 0
    }

    var body: some View {
        let theme = store.theme
        ZStack {
            LiquidBackground(theme: theme)
            if list.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dice")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Initiative gesetzt.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                GeometryReader { geo in
                    ringBody(in: geo, theme: theme)
                }
            }
            cornerChrome(theme: theme)
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .onAppear {
            virtualActive = Double(activeIndex)
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 140).repeatForever(autoreverses: false)) { decoSpin = true }
        }
        .onChange(of: store.state.activeID) { _, _ in syncRotation() }
        .onChange(of: list.count) { _, _ in
            withAnimation(.spring(duration: 0.6)) { virtualActive = nearestVirtual(to: activeIndex) }
        }
    }

    /// Dreht den Ring auf kürzestem Weg zum neuen aktiven Kämpfer.
    private func syncRotation() {
        withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
            virtualActive = nearestVirtual(to: activeIndex)
        }
    }

    private func nearestVirtual(to index: Int) -> Double {
        let n = Double(max(list.count, 1))
        let current = virtualActive
        // Einheitliche Drehrichtung: der Ring dreht immer vorwärts in Zugrichtung.
        // Einzige Ausnahme: genau ein Schritt zurück (= „Vorheriger Zug“).
        var delta = (Double(index) - current).truncatingRemainder(dividingBy: n)
        if delta < 0 { delta += n }              // → [0, n)
        if n > 2, delta == n - 1 { delta = -1 }  // Vorheriger Zug: bewusst rückwärts
        return current + delta
    }

    // MARK: Ring

    @ViewBuilder
    private func ringBody(in geo: GeometryProxy, theme: PlannerTheme) -> some View {
        let side = min(geo.size.width, geo.size.height)
        let radius = side / 2 - 118
        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let n = max(list.count, 1)
        let step = 360.0 / Double(n)

        ZStack {
            // Deko-Ringe, langsam rotierend
            Circle()
                .stroke(theme.cardBorder.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 9]))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(decoSpin ? 360 : 0))
            Circle()
                .stroke(theme.cardBorder.opacity(0.35), lineWidth: 1)
                .frame(width: radius * 2 + 76, height: radius * 2 + 76)
            Circle()
                .stroke(theme.accent.opacity(0.10), lineWidth: 22)
                .frame(width: radius * 2, height: radius * 2)
                .blur(radius: 10)

            // ▼-Markierung: oben ist immer am Zug
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 17))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accent.opacity(0.8), radius: 8)
                .offset(y: -radius - 66)

            // Kämpfer-Tokens auf dem Ring
            let nextIndex = list.count > 1 ? (activeIndex + 1) % list.count : -1
            ForEach(Array(list.enumerated()), id: \.element.id) { index, creature in
                // Vorzeichen bestimmt die Drehrichtung: Ring dreht im Uhrzeigersinn,
                // der nächste Kämpfer wandert von links oben zur ▼-Markierung.
                let angle = (virtualActive - Double(index)) * step
                let isActive = creature.id == store.state.activeID
                RingToken(creature: creature, isActive: isActive,
                          isNext: index == nextIndex && !isActive, pulse: pulse)
                    .rotationEffect(.degrees(-angle))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))
            }

            centerDisc(theme: theme, diameter: max(230, radius * 1.02))
        }
        .position(center)
    }

    @ViewBuilder
    private func centerDisc(theme: PlannerTheme, diameter: CGFloat) -> some View {
        let active = store.state.activeCreature
        VStack(spacing: 8) {
            Text("RUNDE \(store.state.round) · AM ZUG")
                .font(.system(size: 10.5, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(theme.accent)
            Text(active?.name ?? "—")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 26)
            if let active {
                Text(active.kind == .player ? "Spielercharakter" : "Gegner")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                if active.kind == .player && active.maxHitPoints > 0 {
                    HPBarView(creature: active, height: 5)
                        .frame(width: 150)
                        .padding(.top, 2)
                }
                if list.count > 1 {
                    let next = list[(activeIndex + 1) % list.count]
                    HStack(spacing: 6) {
                        Text("ALS NÄCHSTES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(theme.tertiary)
                        Text(next.name)
                            .font(.system(size: 12.5, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(theme.tertiary.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.tertiary.opacity(0.4), lineWidth: 1))
                    .padding(.top, 5)
                }
                let statuses = activeStatusDefs(for: active).prefix(4)
                if !statuses.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(statuses), id: \.id) { status in
                            let color = statusCategoryColor(status.category, polarity: status.polarity)
                            Text(status.label)
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.20), in: Capsule())
                                .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .background(
            LinearGradient(colors: [theme.cardTint.opacity(theme.isDark ? 0.17 : 0.7),
                                    theme.cardTint.opacity(theme.isDark ? 0.06 : 0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: Circle())
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(
            LinearGradient(colors: [theme.accent.opacity(0.55), theme.cardBorder, theme.tertiary.opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.45), radius: 34, y: 16)
        .shadow(color: theme.accent.opacity(pulse ? 0.20 : 0.08), radius: 44)
    }

    private func activeStatusDefs(for creature: Creature) -> [StatusDefinition] {
        creature.statuses
            .compactMap { instance in store.state.statuses.first { $0.id == instance.id } }
            .sorted { $0.priority > $1.priority }
    }

    @ViewBuilder
    private func cornerChrome(theme: PlannerTheme) -> some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("⚔️ Initiative")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                    Text("Spieleransicht · ohne versteckte DM-Werte")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(theme.cardBorder, lineWidth: 1))
                Spacer()
                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                } label: {
                    Label("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            }
            .padding(18)
            Spacer()
        }
    }
}

/// Einzelner Kämpfer-Token auf dem Initiative-Ring.
struct RingToken: View {
    @EnvironmentObject private var store: PlannerStore
    var creature: Creature
    var isActive: Bool
    var isNext: Bool = false
    var pulse: Bool

    var body: some View {
        let theme = store.theme
        let initial = String(creature.name.prefix(1)).uppercased()
        VStack(spacing: 5) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(LinearGradient(colors: [theme.accentBright, theme.accent, theme.tertiary],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Circle().fill(.thinMaterial)
                }
                Text(initial)
                    .font(.system(size: isActive ? 27 : 23, weight: .black, design: .rounded))
                    .foregroundStyle(isActive ? theme.accentContrast : .primary)
                // Typ-Symbol klein am Rand des Tokens
                Text(creature.kind.emoji)
                    .font(.system(size: 13))
                    .padding(3)
                    .background(.regularMaterial, in: Circle())
                    .offset(x: 22, y: 22)
            }
            .frame(width: isActive ? 72 : 60, height: isActive ? 72 : 60)
            .overlay(Circle().strokeBorder(
                isActive ? theme.accentBright.opacity(0.9) : theme.cardBorder,
                lineWidth: isActive ? 2 : 1))
            .overlay {
                // Als-Nächstes-Markierung: gestrichelter Ring in Sekundärfarbe
                if isNext {
                    Circle()
                        .strokeBorder(theme.tertiary.opacity(0.85),
                                      style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .padding(-5)
                }
            }
            .shadow(color: isActive ? theme.accent.opacity(pulse ? 0.75 : 0.4)
                        : isNext ? theme.tertiary.opacity(0.35) : .black.opacity(0.35),
                    radius: isActive ? (pulse ? 26 : 14) : 8, y: 5)

            Text(creature.name)
                .font(.system(size: 11.5, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: 104)
                .shadow(color: theme.isDark ? .black.opacity(0.5) : .clear, radius: 4)

            // HP-Balken nur für Spielercharaktere — und nur, wenn HP eingetragen sind.
            // Monster-HP bleiben in der Spieleransicht bewusst verborgen.
            if creature.kind == .player && creature.maxHitPoints > 0 {
                HPBarView(creature: creature, height: 4)
                    .frame(width: 56)
            }

            if isNext {
                Text("NÄCHSTER")
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(theme.tertiary.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.tertiary.opacity(0.55), lineWidth: 1))
                    .foregroundStyle(theme.isDark ? theme.accentBright : theme.tertiary)
            }

            if creature.isDefeated {
                Text("💀")
                    .font(.system(size: 11))
            } else {
                let statuses = creature.statuses
                    .compactMap { instance in store.state.statuses.first { $0.id == instance.id } }
                    .sorted { $0.priority > $1.priority }
                    .prefix(2)
                if !statuses.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(Array(statuses), id: \.id) { status in
                            let color = statusCategoryColor(status.category, polarity: status.polarity)
                            Text(status.short)
                                .font(.system(size: 8.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.28), in: Capsule())
                                .overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 0.8))
                        }
                    }
                }
            }
        }
        .frame(width: 112)
        .scaleEffect(isActive ? 1.12 : 1)
        .opacity(creature.isDefeated ? 0.45 : 1)
    }
}

// MARK: - Bausteine

struct GlassCard<Content: View>: View {
    @EnvironmentObject private var store: PlannerStore
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let theme = store.theme
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .padding(18)
            .background {
                // Schatten liegt auf der Hintergrundform, nicht auf dem Inhalt —
                // Core Animation kann ihn cachen; bei großen Karten spart das viel Renderzeit.
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        shape.fill(LinearGradient(colors: [theme.cardTint.opacity(theme.isDark ? 0.12 : 0.55),
                                                           theme.cardTint.opacity(theme.isDark ? 0.04 : 0.30)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(theme.isDark ? 0.28 : 0.10), radius: 22, y: 12)
            }
    }
}

struct LiquidBackground: View {
    var theme: PlannerTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.bgStops, startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(Array(theme.glows.enumerated()), id: \.offset) { _, glow in
                RadialGradient(colors: [glow.color, .clear], center: glow.center,
                               startRadius: 0, endRadius: glow.radius)
            }
        }
        .ignoresSafeArea()
    }
}

/// Sektionsüberschrift im Design-Stil: kleines UPPERCASE-Label mit Letterspacing.
struct SectionHeader: View {
    @EnvironmentObject private var store: PlannerStore
    var title: String
    var subtitle: String
    var icon: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(store.theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(store.theme.accent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatTile: View {
    @EnvironmentObject private var store: PlannerStore
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(store.theme.accentBright)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(store.theme.isDark ? 0.18 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(store.theme.cardBorder.opacity(0.55), lineWidth: 1))
    }
}

struct EmptyState: View {
    var text: String
    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
    }
}

struct ToastView: View {
    @EnvironmentObject private var store: PlannerStore
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let notice = store.lastNotice {
                let color: Color = notice.style == "error" ? Color(hex: 0xff8a70)
                    : notice.style == "warning" ? Color(hex: 0xe8934a)
                    : store.theme.accent
                Text(notice.message)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(color.opacity(0.7), lineWidth: 1))
                    .shadow(color: color.opacity(0.25), radius: 14, y: 5)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(notice.id)
            }
        }
        .animation(.spring(duration: 0.35), value: store.lastNotice)
    }
}
