import Foundation
import SwiftUI

@MainActor
public final class PlannerStore: ObservableObject {
    @Published public private(set) var state: PlannerState
    @Published public var lastNotice: Notice? {
        didSet {
            // Meldungen unten rechts nach 5 Sekunden automatisch ausblenden.
            noticeDismissTask?.cancel()
            guard let current = lastNotice else { return }
            noticeDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                if self?.lastNotice?.id == current.id { self?.lastNotice = nil }
            }
        }
    }
    private var noticeDismissTask: Task<Void, Never>?

    public struct Notice: Identifiable, Equatable {
        public var id = UUID()
        public var message: String
        public var style: String
    }

    private let fileURL: URL
    private var undoStack: [PlannerState] = []
    private var redoStack: [PlannerState] = []
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var pendingSave: Task<Void, Never>?

    public init(fileURL: URL? = nil, load: Bool = true) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("InitiativePlannerProMac", isDirectory: true)
        self.fileURL = fileURL ?? support.appendingPathComponent("planner-state.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // Bewusst kein prettyPrinted/sortedKeys: bei großen Datenbanken (500+ Monster)
        // macht das die Kodierung um ein Mehrfaches teurer, ohne Nutzen für die App.
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        if load, let data = try? Data(contentsOf: self.fileURL), let decoded = try? decoder.decode(PlannerState.self, from: data) {
            self.state = decoded
        } else {
            self.state = PlannerState(log: [LogEntry(message: "App gestartet", kind: "system")])
        }
        // Migration abschließen: eine geladene Schema-1-Datei wird strukturell beim
        // nächsten Speichern ohnehin als Schema 2 geschrieben (playerDatabase ist
        // additiv leer) — die Versionsnummer selbst wird hier direkt nachgezogen.
        state.schemaVersion = PlannerState.currentSchemaVersion
        // Sortierung ist Invariante: einmal beim Laden, nie wieder pro Frame in der View.
        state.monsterDatabase.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // Offizielle Stati auf die vollständige Bibliothek (inkl. Regeltexten) heben;
        // eigene, vom Nutzer erstellte Stati bleiben unverändert erhalten.
        let customStatuses = state.statuses.filter { status in
            !status.isOfficial && !StatusDefinition.defaults.contains { $0.id == status.id }
        }
        state.statuses = StatusDefinition.defaults + customStatuses
        ensureActive()

        #if canImport(AppKit)
        // Beim Beenden ausstehende (gebündelte) Speicherungen sofort ausführen.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingSave() }
        }
        #endif
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Speichern ist entkoppelt: schnelle Klickfolgen werden gebündelt, damit das
    /// Kodieren großer Zustände nicht bei jeder Aktion die UI blockiert.
    public func save() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    public func flushPendingSave() {
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        pendingSave = nil
        performSave()
    }

    private func performSave() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            lastNotice = Notice(message: "Speichern fehlgeschlagen: \(error.localizedDescription)", style: "error")
        }
    }

    private func commit(_ message: String? = nil, style: String = "success", notify: Bool = true, body: (inout PlannerState) throws -> Void) {
        var next = state
        undoStack.append(state)
        if undoStack.count > 80 { undoStack.removeFirst() }
        redoStack.removeAll()
        do {
            try body(&next)
            // Log und aktive Auswahl VOR der Zuweisung einarbeiten:
            // genau ein Publish pro Commit statt drei → deutlich weniger Re-Renders.
            if let message {
                next.log.append(LogEntry(message: message, kind: style))
                if next.log.count > 220 { next.log = Array(next.log.suffix(220)) }
            }
            Self.ensureActive(in: &next)
            state = next
            if let message, notify {
                lastNotice = Notice(message: message, style: style)
            }
            save()
        } catch {
            _ = undoStack.popLast()
            lastNotice = Notice(message: error.localizedDescription, style: "error")
        }
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { notice("Nichts zum Rückgängigmachen", style: "warning"); return }
        redoStack.append(state)
        state = previous
        ensureActive()
        save()
        notice("Rückgängig", style: "success")
    }

    public func redo() {
        guard let next = redoStack.popLast() else { notice("Nichts zum Wiederholen", style: "warning"); return }
        undoStack.append(state)
        state = next
        ensureActive()
        save()
        notice("Wiederholt", style: "success")
    }

    public func notice(_ message: String, style: String = "success") {
        lastNotice = Notice(message: message, style: style)
    }

    private func ensureActive() {
        var next = state
        Self.ensureActive(in: &next)
        if next.activeID != state.activeID { state = next }
    }

    private static func ensureActive(in state: inout PlannerState) {
        let list = state.initiativeList
        if list.isEmpty {
            state.activeID = nil
        } else if state.activeID == nil || !list.contains(where: { $0.id == state.activeID }) {
            state.activeID = list.first?.id
        }
        // Ohne Kämpfer gibt es keinen laufenden Kampf mehr — Runden nicht in den
        // nächsten Kampf mitschleppen.
        if state.allCreatures.isEmpty {
            state.round = 1
        }
    }

    public func addCreature(name: String, kind: CreatureKind, armorClass: Int, hpExpression: String, initiativeBonus: Int, initiative: Int?) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { notice("Bitte Namen eingeben", style: "error"); return }
        let hp: Int
        do { hp = hpExpression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : max(0, try DiceRoller.roll(hpExpression).total) }
        catch { notice(error.localizedDescription, style: "error"); return }
        if kind == .monster && hp <= 0 { notice("Monster brauchen HP", style: "error"); return }
        commit("\(kind.label) \(cleanName) hinzugefügt") { state in
            let displayName = kind == .monster ? Self.nextMonsterName(base: cleanName, existing: state.monsters.map(\.name)) : cleanName
            let creature = Creature(name: displayName, kind: kind, armorClass: armorClass, hitPoints: hp, maxHitPoints: hp, initiativeBonus: initiativeBonus, currentInitiative: initiative)
            if kind == .player { state.players.append(creature) } else { state.monsters.append(creature) }
            if initiative != nil, state.activeID == nil { state.activeID = creature.id }
        }
    }

    public func deleteCreature(_ id: UUID) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        commit("\(creature.name) entfernt", style: "warning") { state in
            state.players.removeAll { $0.id == id }
            state.monsters.removeAll { $0.id == id }
            if state.activeID == id { state.activeID = nil }
        }
    }

    public func duplicateCreature(_ id: UUID) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        commit("\(creature.name) dupliziert") { state in
            var copy = creature
            copy.id = UUID()
            copy.currentInitiative = nil
            copy.name = creature.kind == .monster ? Self.nextMonsterName(base: creature.name.replacingOccurrences(of: #"\s\d+$"#, with: "", options: .regularExpression), existing: state.monsters.map(\.name)) : "\(creature.name) Kopie"
            if copy.kind == .player { state.players.append(copy) } else { state.monsters.append(copy) }
        }
    }

    public func setActive(_ id: UUID) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        commit("\(creature.name) ist aktiv", style: "info") { state in
            if let i = state.players.firstIndex(where: { $0.id == id }) {
                if state.players[i].currentInitiative == nil { state.players[i].currentInitiative = 0 }
            }
            if let i = state.monsters.firstIndex(where: { $0.id == id }) {
                if state.monsters[i].currentInitiative == nil { state.monsters[i].currentInitiative = 0 }
            }
            state.activeID = id
        }
    }

    public func setInitiative(_ id: UUID, initiative: Int?) {
        commit(nil) { state in
            mutateCreature(id, in: &state) { $0.currentInitiative = initiative }
            if initiative != nil, state.activeID == nil { state.activeID = id }
        }
    }

    public func rollInitiative(_ id: UUID) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        do {
            let result = try DiceRoller.roll("d20\(creature.initiativeBonus >= 0 ? "+" : "")\(creature.initiativeBonus)")
            commit("\(creature.name) würfelt Initiative: \(result.total)", style: "info") { state in
                mutateCreature(id, in: &state) { $0.currentInitiative = result.total }
                if state.activeID == nil { state.activeID = id }
            }
        } catch { notice(error.localizedDescription, style: "error") }
    }

    public func rollAllMonsterInitiative() {
        guard !state.monsters.isEmpty else { notice("Keine Monster vorhanden", style: "warning"); return }
        commit("Monster-Initiative gewürfelt", style: "info") { state in
            for index in state.monsters.indices {
                let bonus = state.monsters[index].initiativeBonus
                let result = try DiceRoller.roll("d20\(bonus >= 0 ? "+" : "")\(bonus)")
                state.monsters[index].currentInitiative = result.total
                state.log.append(LogEntry(message: "\(state.monsters[index].name): Initiative \(result.total) (\(result.detail))", kind: "roll"))
            }
        }
    }

    public func applyDamage(_ id: UUID, expression: String) {
        applyHPChange(id, expression: expression, healing: false)
    }

    public func applyHealing(_ id: UUID, expression: String) {
        applyHPChange(id, expression: expression, healing: true)
    }

    /// Ausstehende Konzentrationsproben — die UI zeigt dafür einen Dialog.
    public struct ConcentrationCheck: Identifiable, Equatable {
        public var id = UUID()
        public var creatureID: UUID
        public var creatureName: String
        public var damage: Int
        public var dc: Int
    }

    @Published public var concentrationChecks: [ConcentrationCheck] = []

    private func applyHPChange(_ id: UUID, expression: String, healing: Bool) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        let hadConcentration = creature.statuses.contains { $0.id == "concentration" }
        do {
            let amount = max(0, try DiceRoller.roll(expression).total)
            guard amount > 0 else { return }
            commit("\(creature.name): \(healing ? "\(amount) Heilung" : "\(amount) Schaden")", style: healing ? "success" : "warning") { state in
                mutateCreature(id, in: &state) { creature in
                    if healing {
                        creature.hitPoints = min(creature.maxHitPoints == 0 ? amount : creature.maxHitPoints, creature.hitPoints + amount)
                        // Wieder über 0 TP: Todesrettungswürfe und Stabil-Marker zurücksetzen.
                        if creature.hitPoints > 0 {
                            creature.deathSaveSuccesses = nil
                            creature.deathSaveFailures = nil
                            creature.statuses.removeAll { $0.id == "stable" }
                        }
                    } else {
                        var remaining = amount
                        let absorbed = min(creature.temporaryHitPoints, remaining)
                        creature.temporaryHitPoints -= absorbed
                        remaining -= absorbed
                        creature.hitPoints = max(0, creature.hitPoints - remaining)
                    }
                }
                if !healing && hadConcentration {
                    let dc = max(10, amount / 2)
                    state.log.append(LogEntry(message: "\(creature.name): Konzentrationsprobe SG \(dc) fällig", kind: "warning"))
                }
            }
            // Erinnerung an die Konzentrationsprobe: SG 10 oder halber Schaden —
            // je nachdem, was höher ist. Die UI zeigt dazu einen Dialog.
            if !healing && hadConcentration {
                concentrationChecks.append(ConcentrationCheck(creatureID: id, creatureName: creature.name,
                                                              damage: amount, dc: max(10, amount / 2)))
            }
        } catch { notice(error.localizedDescription, style: "error") }
    }

    public func resolveConcentrationCheck(_ check: ConcentrationCheck, passed: Bool) {
        concentrationChecks.removeAll { $0.id == check.id }
        guard let creature = state.allCreatures.first(where: { $0.id == check.creatureID }) else { return }
        if passed {
            commit(nil) { state in
                state.log.append(LogEntry(message: "\(creature.name): Konzentrationsprobe SG \(check.dc) bestanden", kind: "info"))
            }
        } else {
            commit(nil) { state in
                mutateCreature(check.creatureID, in: &state) { $0.statuses.removeAll { $0.id == "concentration" } }
                state.log.append(LogEntry(message: "\(creature.name): Konzentrationsprobe SG \(check.dc) verpatzt — Konzentration endet", kind: "warning"))
            }
        }
    }

    public func dismissConcentrationCheck(_ check: ConcentrationCheck) {
        concentrationChecks.removeAll { $0.id == check.id }
    }

    /// Todesrettungswürfe setzen (0–3); drei Misserfolge markieren „Tot“,
    /// drei Erfolge „Stabil“ — jeweils mit Log-Eintrag.
    public func setDeathSaves(_ id: UUID, successes: Int, failures: Int) {
        guard let creature = state.allCreatures.first(where: { $0.id == id }) else { return }
        let s = max(0, min(3, successes))
        let f = max(0, min(3, failures))
        commit(nil) { state in
            mutateCreature(id, in: &state) {
                $0.deathSaveSuccesses = s
                $0.deathSaveFailures = f
            }
            if f >= 3, !creature.statuses.contains(where: { $0.id == "dead" }) {
                mutateCreature(id, in: &state) { $0.statuses.append(StatusInstance(id: "dead")) }
                state.log.append(LogEntry(message: "\(creature.name) stirbt — dritter verpatzter Todesrettungswurf", kind: "warning"))
            }
            if s >= 3, !creature.statuses.contains(where: { $0.id == "stable" }) {
                mutateCreature(id, in: &state) { $0.statuses.append(StatusInstance(id: "stable")) }
                state.log.append(LogEntry(message: "\(creature.name) ist stabilisiert — drei erfolgreiche Todesrettungswürfe", kind: "success"))
            }
        }
    }

    /// Dauer eines aktiven Status in Runden setzen (nil = unbegrenzt).
    /// Das Herunterzählen übernimmt der Zugwechsel (tickDurations).
    public func setStatusDuration(_ creatureID: UUID, statusID: String, duration: Int?) {
        commit(nil) { state in
            mutateCreature(creatureID, in: &state) { creature in
                if let idx = creature.statuses.firstIndex(where: { $0.id == statusID }) {
                    creature.statuses[idx].duration = duration
                }
            }
        }
    }

    public func setTemporaryHP(_ id: UUID, amount: Int) {
        commit("Temporäre HP gesetzt", style: "info") { state in
            mutateCreature(id, in: &state) { $0.temporaryHitPoints = max(0, amount) }
        }
    }

    /// Schutz gegen Doppel-Auslösung: Menü-Shortcut + Button können denselben
    /// Tastendruck verarbeiten, und eine gehaltene Leertaste feuert per
    /// Autorepeat im Millisekundentakt — beides ließ die Runden davonlaufen.
    private var lastTurnAdvance: Date = .distantPast

    private func allowTurnAdvance() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTurnAdvance) > 0.2 else { return false }
        lastTurnAdvance = now
        return true
    }

    public func nextTurn() {
        guard !state.initiativeList.isEmpty else { notice("Keine Initiative eingetragen", style: "warning"); return }
        guard allowTurnAdvance() else { return }
        commit(nil) { state in
            if let active = state.activeID { Self.tickDurations(for: active, state: &state) }
            let list = state.initiativeList
            guard !list.isEmpty else { return }
            var index = list.firstIndex { $0.id == state.activeID } ?? -1
            index += 1
            if index >= list.count { index = 0; state.round += 1 }
            state.activeID = list[index].id
        }
    }

    public func previousTurn() {
        let list = state.initiativeList
        guard !list.isEmpty else { return }
        guard allowTurnAdvance() else { return }
        commit(nil) { state in
            let list = state.initiativeList
            var index = list.firstIndex { $0.id == state.activeID } ?? 0
            index -= 1
            if index < 0 { index = list.count - 1; state.round = max(1, state.round - 1) }
            state.activeID = list[index].id
        }
    }

    /// Rundenzähler manuell auf 1 zurücksetzen (Rechtsklick auf die Runden-Pille).
    public func resetRound() {
        guard state.round != 1 else { return }
        commit("Runde auf 1 zurückgesetzt", style: "info") { state in
            state.round = 1
        }
    }

    public func clearCombat() {
        commit("Kampf geleert", style: "warning") { state in
            state.players = []
            state.monsters = []
            state.round = 1
            state.activeID = nil
        }
    }

    /// Entfernt alle besiegten Monster (0 HP) mit einem Klick — per Undo rückholbar.
    public func removeDefeatedMonsters() {
        let defeated = state.monsters.filter(\.isDefeated)
        guard !defeated.isEmpty else { notice("Keine besiegten Monster im Kampf", style: "warning"); return }
        commit("\(defeated.count) besiegte Monster aufgeräumt", style: "warning") { state in
            state.monsters.removeAll(where: \.isDefeated)
        }
    }

    /// Manuelle Reihenfolge bei Initiative-Gleichstand: verschiebt `movedID`
    /// direkt vor `targetID` (nur innerhalb derselben Initiative-Gruppe).
    public func moveCreature(_ movedID: UUID, before targetID: UUID) {
        guard movedID != targetID,
              let moved = state.allCreatures.first(where: { $0.id == movedID }),
              let target = state.allCreatures.first(where: { $0.id == targetID }) else { return }
        guard let ini = moved.currentInitiative, target.currentInitiative == ini else {
            notice("Reihenfolge lässt sich nur bei gleicher Initiative ändern", style: "warning")
            return
        }
        commit("Reihenfolge bei Initiative \(ini) angepasst", style: "info") { state in
            var group = state.initiativeList.filter { $0.currentInitiative == ini }.map(\.id)
            group.removeAll { $0 == movedID }
            let insertAt = group.firstIndex(of: targetID) ?? group.count
            group.insert(movedID, at: insertAt)
            for (position, id) in group.enumerated() {
                mutateCreature(id, in: &state) { $0.tieBreak = position }
            }
        }
    }

    public func setHPMode(_ mode: HPMode) {
        commit("HP-Modus: \(mode.label)", style: "info") { state in
            state.hpMode = mode
        }
    }

    public func setTheme(_ id: String, named name: String) {
        commit(nil) { state in
            state.selectedTheme = id
        }
        notice("Theme: \(name)")
    }

    /// Schnell-Schaden/-Heilung aus dem Design (−10/−5/−1/+1/+5) —
    /// nutzt dieselbe Logik wie die Würfelformel-Eingabe (Temp-HP, Konzentration).
    public func applyQuickHP(_ id: UUID, delta: Int) {
        guard delta != 0 else { return }
        if delta < 0 { applyDamage(id, expression: "\(-delta)") }
        else { applyHealing(id, expression: "\(delta)") }
    }

    public func toggleKeepDatabaseOpen() {
        commit(nil) { state in
            state.keepDatabaseOpen.toggle()
        }
    }

    public func toggleStatus(_ statusID: String, for creatureID: UUID, duration: Int? = nil) {
        guard let status = state.statuses.first(where: { $0.id == statusID }), let creature = state.allCreatures.first(where: { $0.id == creatureID }) else { return }
        let isActive = creature.statuses.contains { $0.id == statusID }
        // Kein Toast pro Toggle (sonst blinkt es beim Setzen mehrerer Stati) — nur Log.
        commit("\(creature.name): \(status.label) \(isActive ? "entfernt" : "gesetzt")", style: "info", notify: false) { state in
            mutateCreature(creatureID, in: &state) { creature in
                if let idx = creature.statuses.firstIndex(where: { $0.id == statusID }) {
                    creature.statuses.remove(at: idx)
                } else {
                    creature.statuses.append(StatusInstance(id: statusID, duration: duration))
                }
            }
        }
    }

    public func addStatus(label: String, short: String, category: String, polarity: StatusPolarity, priority: Int, description: String, effects: [String] = []) {
        let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { notice("Status braucht einen Namen", style: "error"); return }
        commit("Status \(clean) erstellt") { state in
            let id = clean.slugifiedMonsterID
            state.statuses.removeAll { $0.id == id }
            state.statuses.append(StatusDefinition(id: id, label: clean, short: short.isEmpty ? String(clean.prefix(4)) : short, category: category, priority: priority, polarity: polarity, description: description, effects: effects))
        }
    }

    /// Eigene Stati bearbeiten (offizielle sind schreibgeschützt).
    public func updateStatus(_ definition: StatusDefinition) {
        guard let idx = state.statuses.firstIndex(where: { $0.id == definition.id }) else { return }
        guard !state.statuses[idx].isOfficial else {
            notice("Offizielle Status können nicht bearbeitet werden.", style: "warning")
            return
        }
        var updated = definition
        updated.isOfficial = false
        commit("Status \(updated.label) aktualisiert") { state in
            if let i = state.statuses.firstIndex(where: { $0.id == updated.id }) {
                state.statuses[i] = updated
            }
        }
    }

    public func deleteStatus(_ id: String) {
        guard let status = state.statuses.first(where: { $0.id == id }), !status.isOfficial else { notice("Offizielle Status können nicht gelöscht werden.", style: "warning"); return }
        commit("Status \(status.label) gelöscht", style: "warning") { state in
            state.statuses.removeAll { $0.id == id }
            for index in state.players.indices { state.players[index].statuses.removeAll { $0.id == id } }
            for index in state.monsters.indices { state.monsters[index].statuses.removeAll { $0.id == id } }
        }
    }

    public func addMonsterFromDatabase(_ template: MonsterTemplate, quantity: Int, mode: HPMode) {
        let qty = max(1, min(50, quantity))
        commit("\(qty)× \(template.name) hinzugefügt") { state in
            for _ in 0..<qty {
                let hp = mode == .roll ? max(1, try DiceRoller.roll(template.hpDice).total) : template.hpAverage
                let name = Self.nextMonsterName(base: template.name, existing: state.monsters.map(\.name))
                state.monsters.append(Creature(name: name, kind: .monster, armorClass: template.armorClass, hitPoints: hp, maxHitPoints: hp, initiativeBonus: template.initiativeBonus, sourceMonsterID: template.id))
            }
        }
    }

    public func saveMonsterTemplate(_ template: MonsterTemplate) {
        commit("\(template.name) in Datenbank gespeichert") { state in
            state.monsterDatabase.removeAll { $0.id == template.id }
            state.monsterDatabase.append(template)
            state.monsterDatabase.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    public func deleteMonsterTemplate(_ id: String) {
        guard let template = state.monsterDatabase.first(where: { $0.id == id }) else { return }
        commit("\(template.name) aus Datenbank gelöscht", style: "warning") { state in
            state.monsterDatabase.removeAll { $0.id == id }
        }
    }

    /// Leert die gesamte Monsterdatenbank (Rückfrage übernimmt die View; ⌘Z stellt wieder her).
    public func clearMonsterDatabase() {
        let count = state.monsterDatabase.count
        guard count > 0 else { notice("Die Datenbank ist bereits leer", style: "warning"); return }
        commit("\(count) Monster aus der Datenbank gelöscht", style: "warning") { state in
            state.monsterDatabase = []
        }
        TokenStore.shared.removeAll()
    }

    public func importMonsterText(_ text: String, sourceName: String) {
        do {
            let monsters = try MonsterImporter.importMonsters(from: text, sourceName: sourceName)
            commit("\(monsters.count) Monster dauerhaft importiert") { state in
                for var monster in monsters {
                    monster.source = sourceName.isEmpty ? "Import" : sourceName
                    monster.importedAt = Date()
                    state.monsterDatabase.removeAll { $0.id == monster.id }
                    state.monsterDatabase.append(monster)
                }
                state.monsterDatabase.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        } catch { notice(error.localizedDescription, style: "error") }
    }

    /// Rekursiver Ordner-Import: durchsucht den Ordner und alle Unterordner nach
    /// .md-Dateien mit erkennbaren Monster-Werten und importiert alle Treffer dauerhaft.
    public func importMonsterFolder(_ folderURL: URL) {
        importMonsterURLs([folderURL])
    }

    /// Gemeinsamer Import für Ordner-Dialog und Drag & Drop: akzeptiert eine
    /// Mischung aus Ordnern (rekursiv) und einzelnen .md-Dateien — in EINEM Commit.
    public func importMonsterURLs(_ urls: [URL]) {
        var collected: [MonsterTemplate] = []
        var matchedFiles = 0
        var skippedFiles = 0
        // Alle Bilddateien im Import-Baum indizieren, damit Token-Einbettungen
        // aus den .md-Dateien (die auf ein separates Bild verweisen) aufgelöst
        // werden können — auch wenn das Bild in einem Nachbarordner liegt.
        var imageIndex: [String: URL] = [:]   // NFC-Dateiname → URL
        func indexImage(_ url: URL) {
            let ext = url.pathExtension.lowercased()
            guard ["webp", "png", "jpg", "jpeg"].contains(ext) else { return }
            imageIndex[url.lastPathComponent.precomposedStringWithCanonicalMapping] = url
        }

        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
                while let item = enumerator?.nextObject() as? URL {
                    Self.collectMonsters(from: item, into: &collected, matched: &matchedFiles, skipped: &skippedFiles)
                    indexImage(item)
                }
            } else {
                Self.collectMonsters(from: url, into: &collected, matched: &matchedFiles, skipped: &skippedFiles)
                indexImage(url)
            }
        }

        // Tokens auflösen: Dateiname aus der .md gegen den Bild-Index, dann cachen.
        // Auch BESTEHENDE Datenbank-Einträge profitieren — wer erst die Monster
        // und später den Bilder-Ordner importiert, bekommt die Tokens nachgereicht.
        var tokenCount = 0
        func resolveToken(_ fn: String?, id: String) {
            guard let fn else { return }
            let key = fn.precomposedStringWithCanonicalMapping
            if let imgURL = imageIndex[key], TokenStore.shared.store(imageAt: imgURL, for: id) {
                tokenCount += 1
            }
        }
        for monster in collected { resolveToken(monster.tokenFilename, id: monster.id) }
        for monster in state.monsterDatabase where !TokenStore.shared.hasToken(monster.id) {
            resolveToken(monster.tokenFilename, id: monster.id)
        }

        guard !collected.isEmpty else {
            if tokenCount > 0 {
                notice("\(tokenCount) Monster-Tokens aus Bildern ergänzt", style: "success")
                objectWillChange.send()   // Ring/Zeilen neu zeichnen
            } else {
                notice("Keine passenden .md-Monster gefunden", style: "warning")
            }
            return
        }

        let summary = "\(collected.count) Monster dauerhaft importiert (\(matchedFiles) Dateien\(skippedFiles > 0 ? ", \(skippedFiles) übersprungen" : "")\(tokenCount > 0 ? ", \(tokenCount) Tokens" : ""))"
        commit(summary) { state in
            for var monster in collected {
                monster.importedAt = Date()
                state.monsterDatabase.removeAll { $0.id == monster.id }
                state.monsterDatabase.append(monster)
            }
            state.monsterDatabase.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// Liest eine einzelne Datei ein, sofern sie eine passende .md mit echten
    /// Monster-Werten ist — sonst würde jede Notiz als 1-HP-Monster landen.
    private static func collectMonsters(from url: URL, into collected: inout [MonsterTemplate], matched: inout Int, skipped: inout Int) {
        let statPattern = #"(?im)^\s*(rk|ac|armor class|tp|hp|trefferpunkte|hit points)\s*[:=]"#
        guard url.pathExtension.lowercased() == "md" else { return }
        let filename = url.lastPathComponent
        if filename.hasPrefix("._") || url.path.contains("__MACOSX") { return }
        guard let text = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else { skipped += 1; return }
        guard text.range(of: statPattern, options: .regularExpression) != nil else { skipped += 1; return }
        guard let monsters = try? MonsterImporter.importMonsters(from: text, sourceName: url.deletingPathExtension().lastPathComponent) else {
            skipped += 1
            return
        }
        matched += 1
        for monster in monsters {
            collected.removeAll { $0.id == monster.id }
            collected.append(monster)
        }
    }

    // MARK: - Spieler

    /// Legt eine neue Spielervorlage an oder aktualisiert eine bestehende (per `id`
    /// unterschieden). Bildänderungen werden VOR diesem Commit bereits per
    /// `storePlayerImage` in den PlayerImageStore geschrieben, sodass ein einzelner
    /// Commit Name/Werte/Bildverweis gemeinsam trägt — ein Undo nimmt alles zurück.
    public func savePlayerTemplate(_ template: PlayerTemplate) {
        let isNew = !state.playerDatabase.contains { $0.id == template.id }
        commit(isNew ? "\(template.name) als Spieler angelegt" : "\(template.name) aktualisiert") { state in
            state.playerDatabase.removeAll { $0.id == template.id }
            state.playerDatabase.append(template)
            state.playerDatabase.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            // Bildänderung wirkt sofort auch auf bereits aktive Kämpfer mit dieser Vorlage —
            // andere kampfspezifische Werte (HP, Initiative …) bleiben als eigener Snapshot unberührt.
            for index in state.players.indices where state.players[index].sourcePlayerID == template.id {
                state.players[index].sourcePlayerImageID = template.imageID
            }
        }
    }

    public func deletePlayerTemplate(_ id: UUID) {
        guard let template = state.playerDatabase.first(where: { $0.id == id }) else { return }
        commit("\(template.name) aus Spielerdatenbank gelöscht", style: "warning") { state in
            state.playerDatabase.removeAll { $0.id == id }
        }
    }

    /// Kopiert die Bilddatei an `source` unter einer neuen Bildversions-UUID in den
    /// PlayerImageStore (kanonisches Muster wie bei Monster-Tokens: erst kopieren,
    /// danach EIN Store-Commit über `savePlayerTemplate`). Schlägt die Kopie fehl,
    /// bleibt die aufrufende Ansicht ohne Bildänderung nutzbar.
    @discardableResult
    public func storePlayerImage(at source: URL) -> UUID? {
        let newID = UUID()
        guard PlayerImageStore.shared.store(imageAt: source, as: newID) else {
            notice("Bild konnte nicht gelesen werden — Spieler bleibt ohne Bildänderung", style: "warning")
            return nil
        }
        return newID
    }

    /// Übernimmt eine Spielervorlage als neuen Kämpfer in den aktuellen Kampf. Nicht
    /// gesetzte RK/TP/Ini-Werte erhalten hier sichere interne Startwerte (RK 10, TP 0,
    /// Ini 0) — die Vorlage selbst bleibt davon unberührt und zeigt weiterhin „nicht gesetzt“.
    public func spawnPlayerIntoCombat(_ templateID: UUID) {
        guard let template = state.playerDatabase.first(where: { $0.id == templateID }) else { return }
        commit("\(template.name) zum Kampf hinzugefügt") { state in
            let hp = template.maxHitPoints ?? 0
            state.players.append(Creature(
                name: template.name, kind: .player,
                armorClass: template.armorClass ?? 10,
                hitPoints: hp, maxHitPoints: hp,
                initiativeBonus: template.initiativeBonus ?? 0,
                notes: template.notes,
                sourcePlayerID: template.id, sourcePlayerImageID: template.imageID))
        }
    }

    /// Übernimmt eine Spielervorlage direkt in einen bereits gespeicherten Encounter,
    /// ohne den aktuellen Kampf zu verändern.
    public func spawnPlayer(_ templateID: UUID, intoEncounter encounterID: UUID) {
        guard let template = state.playerDatabase.first(where: { $0.id == templateID }),
              let targetName = state.encounters.first(where: { $0.id == encounterID })?.name else { return }
        commit("\(template.name) zu Encounter \(targetName) hinzugefügt") { state in
            guard let eIndex = state.encounters.firstIndex(where: { $0.id == encounterID }) else { return }
            let hp = template.maxHitPoints ?? 0
            state.encounters[eIndex].players.append(Creature(
                name: template.name, kind: .player,
                armorClass: template.armorClass ?? 10,
                hitPoints: hp, maxHitPoints: hp,
                initiativeBonus: template.initiativeBonus ?? 0,
                notes: template.notes,
                sourcePlayerID: template.id, sourcePlayerImageID: template.imageID))
        }
    }

    public func saveEncounter(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { notice("Bitte Encounter-Namen eingeben", style: "error"); return }
        commit("Encounter \(clean) gespeichert") { state in
            let encounter = Encounter(name: clean, round: state.round, activeID: state.activeID, players: state.players, monsters: state.monsters, log: state.log)
            state.encounters.removeAll { $0.name.caseInsensitiveCompare(clean) == .orderedSame }
            state.encounters.append(encounter)
            state.encounters.sort { $0.savedAt > $1.savedAt }
        }
    }

    public func loadEncounter(_ encounter: Encounter) {
        commit("Encounter \(encounter.name) geladen") { state in
            state.players = encounter.players
            state.monsters = encounter.monsters
            state.round = encounter.round
            state.activeID = encounter.activeID
            state.log = encounter.log
        }
    }

    public func deleteEncounter(_ id: UUID) {
        commit("Encounter gelöscht", style: "warning") { state in
            state.encounters.removeAll { $0.id == id }
        }
    }

    public func clearLog() {
        commit("Protokoll geleert", style: "warning") { state in
            state.log = []
        }
    }

    public func copyLogToPasteboard() {
        #if os(macOS)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let text = state.log.map { "[\(formatter.string(from: $0.date))] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice("Protokoll in die Zwischenablage kopiert")
        #endif
    }

    static func nextMonsterName(base: String, existing: [String]) -> String {
        let cleaned = base.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s\d+$"#, with: "", options: .regularExpression)
        var i = 1
        while existing.contains("\(cleaned) \(i)") { i += 1 }
        return "\(cleaned) \(i)"
    }

    private static func tickDurations(for activeID: UUID, state: inout PlannerState) {
        let labelsByID = Dictionary(uniqueKeysWithValues: state.statuses.map { ($0.id, $0.label) })
        var endedMessages: [String] = []
        mutateCreature(activeID, in: &state) { creature in
            for idx in creature.statuses.indices.reversed() {
                guard let duration = creature.statuses[idx].duration else { continue }
                let next = duration - 1
                if next <= 0 {
                    let label = labelsByID[creature.statuses[idx].id] ?? creature.statuses[idx].id
                    endedMessages.append("\(creature.name): Status \(label) endet")
                    creature.statuses.remove(at: idx)
                } else {
                    creature.statuses[idx].duration = next
                }
            }
        }
        for message in endedMessages {
            state.log.append(LogEntry(message: message, kind: "status"))
        }
    }
}

private func mutateCreature(_ id: UUID, in state: inout PlannerState, update: (inout Creature) -> Void) {
    if let idx = state.players.firstIndex(where: { $0.id == id }) {
        update(&state.players[idx])
        return
    }
    if let idx = state.monsters.firstIndex(where: { $0.id == id }) {
        update(&state.monsters[idx])
    }
}
