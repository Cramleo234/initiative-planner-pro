import Foundation

public enum CreatureKind: String, Codable, CaseIterable, Identifiable {
    case player
    case monster

    public var id: String { rawValue }
    public var label: String { self == .player ? "Spieler" : "Monster" }
    public var symbol: String { self == .player ? "person.fill" : "pawprint.fill" }
    public var emoji: String { self == .player ? "🧙" : "👹" }
}

public enum HPMode: String, Codable, CaseIterable, Identifiable {
    case average
    case roll

    public var id: String { rawValue }
    public var label: String { self == .average ? "Durchschnitt" : "Würfeln" }
}

public enum StatusPolarity: String, Codable, CaseIterable, Identifiable {
    case good
    case bad
    public var id: String { rawValue }
}

public struct StatusDefinition: Identifiable, Codable, Equatable {
    public var id: String
    public var label: String
    public var short: String
    public var category: String
    public var priority: Int
    public var polarity: StatusPolarity
    public var description: String
    public var effects: [String]
    public var isOfficial: Bool

    public init(id: String, label: String, short: String, category: String, priority: Int, polarity: StatusPolarity, description: String, effects: [String] = [], isOfficial: Bool = false) {
        self.id = id
        self.label = label
        self.short = short
        self.category = category
        self.priority = priority
        self.polarity = polarity
        self.description = description
        self.effects = effects
        self.isOfficial = isOfficial
    }
}

public struct StatusInstance: Identifiable, Codable, Equatable {
    public var id: String
    public var duration: Int?
    public var note: String

    public init(id: String, duration: Int? = nil, note: String = "") {
        self.id = id
        self.duration = duration
        self.note = note
    }
}

public struct Creature: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var kind: CreatureKind
    public var armorClass: Int
    public var hitPoints: Int
    public var maxHitPoints: Int
    public var temporaryHitPoints: Int
    public var initiativeBonus: Int
    public var currentInitiative: Int?
    /// Manuelle Reihenfolge bei Initiative-Gleichstand (kleiner = früher dran).
    public var tieBreak: Int?
    /// Todesrettungswürfe (nur relevant bei 0 TP): 0–3 Erfolge bzw. Misserfolge.
    public var deathSaveSuccesses: Int?
    public var deathSaveFailures: Int?
    public var statuses: [StatusInstance]
    public var notes: String
    public var sourceMonsterID: String?

    public init(id: UUID = UUID(), name: String, kind: CreatureKind, armorClass: Int = 10, hitPoints: Int = 0, maxHitPoints: Int? = nil, temporaryHitPoints: Int = 0, initiativeBonus: Int = 0, currentInitiative: Int? = nil, tieBreak: Int? = nil, deathSaveSuccesses: Int? = nil, deathSaveFailures: Int? = nil, statuses: [StatusInstance] = [], notes: String = "", sourceMonsterID: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.armorClass = armorClass
        self.hitPoints = max(0, hitPoints)
        self.maxHitPoints = max(0, maxHitPoints ?? hitPoints)
        self.temporaryHitPoints = max(0, temporaryHitPoints)
        self.initiativeBonus = initiativeBonus
        self.currentInitiative = currentInitiative
        self.tieBreak = tieBreak
        self.deathSaveSuccesses = deathSaveSuccesses
        self.deathSaveFailures = deathSaveFailures
        self.statuses = statuses
        self.notes = notes
        self.sourceMonsterID = sourceMonsterID
    }

    public var initiativeIsSet: Bool { currentInitiative != nil }
    public var isDefeated: Bool { maxHitPoints > 0 && hitPoints <= 0 }
    public var hpFraction: Double { maxHitPoints > 0 ? Double(hitPoints) / Double(maxHitPoints) : 0 }
}

/// Benannte Fähigkeit aus einem Statblock („Feuerodem (Aufladung 5–6)“ + Regeltext).
public struct NamedAbility: Codable, Equatable {
    public var name: String
    public var text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }
}

/// Attributswert mit Modifikator und Rettungswurf (STÄ 27, +8 / +8).
public struct AbilityValue: Codable, Equatable {
    public var label: String
    public var score: Int
    public var mod: String
    public var save: String

    public init(label: String, score: Int, mod: String, save: String) {
        self.label = label
        self.score = score
        self.mod = mod
        self.save = save
    }
}

/// Vollständiger Statblock aus dem Markdown-Import: Frontmatter-Werte plus
/// die Abschnitte Merkmale/Aktionen/Bonusaktionen/Reaktionen/Legendäre Aktionen.
public struct StatBlock: Codable, Equatable {
    public var subtitle: String = ""
    public var size: String = ""
    public var alignment: String = ""
    public var habitat: String = ""
    public var speed: String = ""
    public var senses: String = ""
    public var languages: String = ""
    public var skills: String = ""
    public var resistances: String = ""
    public var immunities: String = ""
    public var vulnerabilities: String = ""
    public var equipment: String = ""
    public var xp: String = ""
    public var proficiency: String = ""
    public var abilities: [AbilityValue] = []
    public var traits: [NamedAbility] = []
    public var actions: [NamedAbility] = []
    public var bonusActions: [NamedAbility] = []
    public var reactions: [NamedAbility] = []
    public var legendaryActions: [NamedAbility] = []
    public var legendaryIntro: String = ""

    public init() {}

    public var isEmpty: Bool {
        abilities.isEmpty && traits.isEmpty && actions.isEmpty && bonusActions.isEmpty
            && reactions.isEmpty && legendaryActions.isEmpty
            && [subtitle, size, alignment, speed, senses, languages, skills,
                resistances, immunities, vulnerabilities, equipment].allSatisfy(\.isEmpty)
    }

    public var hasSections: Bool {
        !traits.isEmpty || !actions.isEmpty || !bonusActions.isEmpty || !reactions.isEmpty || !legendaryActions.isEmpty
    }
}

public struct MonsterTemplate: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var armorClass: Int
    public var hpAverage: Int
    public var hpDice: String
    public var challengeRating: String
    public var initiativeBonus: Int
    public var type: String
    public var source: String
    public var notes: String
    public var importedAt: Date?
    /// Optionaler vollständiger Statblock — fehlt bei manuell angelegten Monstern.
    public var statblock: StatBlock?

    public init(id: String, name: String, armorClass: Int = 10, hpAverage: Int = 1, hpDice: String = "1d8", challengeRating: String = "?", initiativeBonus: Int = 0, type: String = "", source: String = "App", notes: String = "", importedAt: Date? = nil, statblock: StatBlock? = nil) {
        self.id = id
        self.name = name
        self.armorClass = armorClass
        self.hpAverage = max(1, hpAverage)
        self.hpDice = hpDice.isEmpty ? "1d8" : hpDice
        self.challengeRating = challengeRating.isEmpty ? "?" : challengeRating
        self.initiativeBonus = initiativeBonus
        self.type = type
        self.source = source
        self.notes = notes
        self.importedAt = importedAt
        self.statblock = statblock
    }
}

public struct Encounter: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var savedAt: Date
    public var round: Int
    public var activeID: UUID?
    public var players: [Creature]
    public var monsters: [Creature]
    public var log: [LogEntry]

    public init(id: UUID = UUID(), name: String, savedAt: Date = Date(), round: Int, activeID: UUID?, players: [Creature], monsters: [Creature], log: [LogEntry]) {
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.round = round
        self.activeID = activeID
        self.players = players
        self.monsters = monsters
        self.log = log
    }
}

public struct LogEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    public var date: Date
    public var message: String
    public var kind: String

    public init(id: UUID = UUID(), date: Date = Date(), message: String, kind: String = "info") {
        self.id = id
        self.date = date
        self.message = message
        self.kind = kind
    }
}

public struct PlannerState: Codable, Equatable {
    public var players: [Creature]
    public var monsters: [Creature]
    public var round: Int
    public var activeID: UUID?
    public var monsterDatabase: [MonsterTemplate]
    public var encounters: [Encounter]
    public var statuses: [StatusDefinition]
    public var hpMode: HPMode
    public var keepDatabaseOpen: Bool
    public var selectedTheme: String
    public var log: [LogEntry]

    // Die Monsterdatenbank ist ab Werk bewusst LEER: Die App wird ohne
    // Regelwerks-Inhalte ausgeliefert; Nutzer importieren ihre eigene Sammlung.
    public init(players: [Creature] = [], monsters: [Creature] = [], round: Int = 1, activeID: UUID? = nil, monsterDatabase: [MonsterTemplate] = [], encounters: [Encounter] = [], statuses: [StatusDefinition] = StatusDefinition.defaults, hpMode: HPMode = .average, keepDatabaseOpen: Bool = true, selectedTheme: String = "glass", log: [LogEntry] = []) {
        self.players = players
        self.monsters = monsters
        self.round = round
        self.activeID = activeID
        self.monsterDatabase = monsterDatabase
        self.encounters = encounters
        self.statuses = statuses
        self.hpMode = hpMode
        self.keepDatabaseOpen = keepDatabaseOpen
        self.selectedTheme = selectedTheme
        self.log = log
    }
}

public extension PlannerState {
    var allCreatures: [Creature] { players + monsters }

    var initiativeList: [Creature] {
        allCreatures
            .filter { $0.currentInitiative != nil }
            .sorted {
                if $0.currentInitiative != $1.currentInitiative { return ($0.currentInitiative ?? -999) > ($1.currentInitiative ?? -999) }
                // Manuell festgelegte Reihenfolge bei Gleichstand (per Drag & Drop)
                if ($0.tieBreak ?? 0) != ($1.tieBreak ?? 0) { return ($0.tieBreak ?? 0) < ($1.tieBreak ?? 0) }
                if $0.initiativeBonus != $1.initiativeBonus { return $0.initiativeBonus > $1.initiativeBonus }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var activeCreature: Creature? { allCreatures.first { $0.id == activeID } }
}

public extension StatusDefinition {
    /// Vollständige Bibliothek der Web-Version: alle offiziellen Zustände aus dem
    /// Regelglossar plus nützliche Kampfmarker, jeweils mit Regelwirkungen.
    static var defaults: [StatusDefinition] {
        [
            StatusDefinition(id: "concentration", label: "Konzentration", short: "Konz", category: "concentration", priority: 10, polarity: .good, description: "Ein Zauber oder Effekt wird aktiv aufrechterhalten.", effects: [
                "Bei Schaden: Konstitutionsrettungswurf, SG 10 oder halber erlittener Schaden, je nachdem was höher ist.",
                "Endet, wenn du einen weiteren Konzentrationseffekt beginnst.",
                "Endet, wenn du kampfunfähig wirst oder stirbst."
            ], isOfficial: true),
            StatusDefinition(id: "dodging", label: "Ausweichend", short: "Ausw", category: "good", priority: 5, polarity: .good, description: "Die Kreatur nutzt die Ausweichen-Aktion.", effects: [
                "Bis zum Beginn ihres nächsten Zugs sind Angriffswürfe gegen sie im Nachteil, sofern sie den Angreifer sehen kann.",
                "Geschicklichkeitsrettungswürfe sind im Vorteil.",
                "Der Vorteil endet, wenn sie kampfunfähig wird oder ihre Bewegungsrate 0 beträgt."
            ], isOfficial: true),
            StatusDefinition(id: "resistant", label: "Resistent", short: "Res", category: "physical", priority: 2, polarity: .good, description: "Resistenz gegen eine Schadensart.", effects: [
                "Schaden der angegebenen Art wird halbiert; pro Schadensinstanz nur einmal anwenden."
            ], isOfficial: true),
            StatusDefinition(id: "immune", label: "Immun", short: "Imm", category: "physical", priority: 3, polarity: .good, description: "Immunität gegen eine Schadensart oder einen Zustand.", effects: [
                "Die angegebene Schadensart oder der angegebene Zustand beeinflusst die Kreatur nicht."
            ], isOfficial: true),
            StatusDefinition(id: "blessed", label: "Gesegnet", short: "Seg", category: "good", priority: 2, polarity: .good, description: "Hilfreicher Bonus, z. B. durch den Zauber Segnen.", effects: [
                "Typische Erinnerung: +1W4 auf Angriffswürfe und Rettungswürfe, solange der Effekt gilt."
            ], isOfficial: true),
            StatusDefinition(id: "inspired", label: "Inspiriert", short: "Ins", category: "good", priority: 1, polarity: .good, description: "Hat Inspiration, Bardeninspiration oder einen vergleichbaren Bonus.", effects: [
                "Als Marker für einen später einsetzbaren Bonus gedacht; genaue Wirkung hängt von der Quelle ab."
            ], isOfficial: true),
            StatusDefinition(id: "stable", label: "Stabil", short: "Stab", category: "good", priority: 2, polarity: .good, description: "Die Kreatur hat 0 Trefferpunkte, muss aber keine Todesrettungswürfe ablegen.", effects: [
                "Marker für 0 HP ohne aktive Todesrettungswürfe.",
                "Weitere Treffer/Heilung wie gewohnt nach Regelquelle behandeln."
            ], isOfficial: true),
            StatusDefinition(id: "hidden", label: "Versteckt", short: "Vers", category: "movement", priority: 3, polarity: .good, description: "Die Kreatur hat sich erfolgreich versteckt.", effects: [
                "Nach erfolgreichem Verstecken ist sie unsichtbar, solange sie versteckt bleibt.",
                "Das Würfelergebnis dient als SG, um sie mit Wahrnehmung aufzuspüren.",
                "Endet u. a., wenn sie lauter als ein Flüstern ist, aufgespürt wird, angreift oder einen Zauber mit Verbalkomponente wirkt."
            ], isOfficial: true),
            StatusDefinition(id: "invisible", label: "Unsichtbar", short: "Uns", category: "movement", priority: 4, polarity: .good, description: "Die Kreatur ist nicht sichtbar, außer ein Effekt erlaubt es, sie trotzdem zu sehen.", effects: [
                "Bei Initiative im Vorteil, wenn sie beim Auswürfeln unsichtbar ist.",
                "Sie ist vor Effekten geschützt, die Sicht erfordern, sofern der Wirker sie nicht trotzdem sehen kann.",
                "Angriffe gegen sie sind im Nachteil; ihre Angriffswürfe sind im Vorteil, außer das Ziel kann sie sehen."
            ], isOfficial: true),
            StatusDefinition(id: "bloodied", label: "Blutig", short: "Blut", category: "physical", priority: 1, polarity: .bad, description: "Die Kreatur hat höchstens die Hälfte ihrer Trefferpunkte.", effects: [
                "Reiner Zustandsmarker für Übersicht, Blutrausch, Phasenwechsel oder Monsterfähigkeiten."
            ], isOfficial: true),
            StatusDefinition(id: "vulnerable", label: "Anfällig", short: "Anf", category: "physical", priority: 3, polarity: .bad, description: "Anfälligkeit gegen eine Schadensart.", effects: [
                "Schaden der angegebenen Art wird verdoppelt; pro Schadensinstanz nur einmal anwenden."
            ], isOfficial: true),
            StatusDefinition(id: "surprised", label: "Überrascht", short: "Über", category: "mental", priority: 4, polarity: .bad, description: "Die Kreatur hat nicht mit dem Kampf gerechnet.", effects: [
                "Beim Initiativewurf im Nachteil.",
                "Danach als Erinnerung entfernen, falls der Effekt nicht länger relevant ist."
            ], isOfficial: true),
            StatusDefinition(id: "stunned", label: "Betäubt", short: "Bet", category: "critical", priority: 8, polarity: .bad, description: "Schwerer Zustand; die Kreatur ist handlungsunfähig und leichter zu treffen.", effects: [
                "Hat den Zustand Kampfunfähig.",
                "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.",
                "Angriffswürfe gegen die Kreatur sind im Vorteil."
            ], isOfficial: true),
            StatusDefinition(id: "unconscious", label: "Bewusstlos", short: "Bew", category: "critical", priority: 9, polarity: .bad, description: "Die Kreatur nimmt ihre Umgebung nicht wahr und ist wehrlos.", effects: [
                "Hat Kampfunfähig und Liegend und lässt Gehaltenes fallen; nach Ende bleibt sie liegend.",
                "Bewegungsrate 0 und kann nicht erhöht werden.",
                "Angriffswürfe gegen sie sind im Vorteil.",
                "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.",
                "Treffer aus bis zu 1,5 m Entfernung sind kritische Treffer.",
                "Sie nimmt die Umgebung nicht wahr."
            ], isOfficial: true),
            StatusDefinition(id: "paralyzed", label: "Gelähmt", short: "Gel", category: "critical", priority: 7, polarity: .bad, description: "Die Kreatur ist bewegungsunfähig und Treffer aus nächster Nähe sind besonders gefährlich.", effects: [
                "Hat den Zustand Kampfunfähig.",
                "Bewegungsrate 0 und kann nicht erhöht werden.",
                "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.",
                "Angriffswürfe gegen sie sind im Vorteil.",
                "Treffer aus bis zu 1,5 m Entfernung sind kritische Treffer."
            ], isOfficial: true),
            StatusDefinition(id: "petrified", label: "Versteinert", short: "Verst", category: "incapacitated", priority: 6, polarity: .bad, description: "Die Kreatur ist in eine unbelebte Substanz verwandelt.", effects: [
                "Mit nichtmagischer Ausrüstung in eine feste unbelebte Substanz verwandelt; Gewicht verzehnfacht, Alterung stoppt.",
                "Hat den Zustand Kampfunfähig.",
                "Bewegungsrate 0 und kann nicht erhöht werden.",
                "Angriffswürfe gegen sie sind im Vorteil.",
                "Stärke- und Geschicklichkeitsrettungswürfe scheitern automatisch.",
                "Resistenz gegen alle Schadensarten.",
                "Immun gegen den Zustand Vergiftet."
            ], isOfficial: true),
            StatusDefinition(id: "incapacitated", label: "Kampfunfähig", short: "Kamp", category: "incapacitated", priority: 6, polarity: .bad, description: "Die Kreatur kann praktisch nicht handeln.", effects: [
                "Keine Aktionen, Bonusaktionen oder Reaktionen.",
                "Konzentration ist unterbrochen.",
                "Kann nicht sprechen.",
                "Bei Initiative im Nachteil, wenn sie beim Auswürfeln kampfunfähig ist."
            ], isOfficial: true),
            StatusDefinition(id: "restrained", label: "Festgesetzt", short: "Fest", category: "movement", priority: 5, polarity: .bad, description: "Die Kreatur ist stark in ihrer Bewegung eingeschränkt.", effects: [
                "Bewegungsrate 0 und kann nicht erhöht werden.",
                "Angriffswürfe gegen sie sind im Vorteil; ihre eigenen Angriffswürfe sind im Nachteil.",
                "Geschicklichkeitsrettungswürfe sind im Nachteil."
            ], isOfficial: true),
            StatusDefinition(id: "blinded", label: "Blind", short: "Blind", category: "physical", priority: 5, polarity: .bad, description: "Die Kreatur kann nicht sehen.", effects: [
                "Attributswürfe, die Sicht erfordern, scheitern automatisch.",
                "Angriffswürfe gegen sie sind im Vorteil; ihre eigenen Angriffswürfe sind im Nachteil."
            ], isOfficial: true),
            StatusDefinition(id: "frightened", label: "Verängstigt", short: "Ver", category: "mental", priority: 4, polarity: .bad, description: "Die Kreatur fürchtet eine Quelle.", effects: [
                "Attributs- und Angriffswürfe sind im Nachteil, solange die Quelle der Furcht in Sichtlinie ist.",
                "Sie kann sich nicht willentlich auf die Quelle der Furcht zubewegen."
            ], isOfficial: true),
            StatusDefinition(id: "poisoned", label: "Vergiftet", short: "Verg", category: "physical", priority: 3, polarity: .bad, description: "Gift oder ein ähnlicher Effekt beeinträchtigt die Kreatur.", effects: [
                "Angriffs- und Attributswürfe sind im Nachteil."
            ], isOfficial: true),
            StatusDefinition(id: "exhaustion", label: "Erschöpft", short: "Ersch", category: "physical", priority: 3, polarity: .bad, description: "Kumulativer Zustand mit Erschöpfungsstufen.", effects: [
                "Jedes Erleiden erhöht die Erschöpfungsstufe; bei 6 Stufen stirbt die Kreatur.",
                "W20-Prüfungen werden um das Doppelte der Erschöpfungsstufe verringert.",
                "Bewegungsrate sinkt um 1,5 m pro Erschöpfungsstufe.",
                "Eine lange Rast entfernt eine Stufe; bei 0 Stufen endet der Zustand."
            ], isOfficial: true),
            StatusDefinition(id: "deafened", label: "Taub", short: "Taub", category: "physical", priority: 3, polarity: .bad, description: "Die Kreatur kann nicht hören.", effects: [
                "Attributswürfe, die Hörvermögen erfordern, scheitern automatisch."
            ], isOfficial: true),
            StatusDefinition(id: "prone", label: "Liegend", short: "Lieg", category: "movement", priority: 3, polarity: .bad, description: "Die Kreatur liegt am Boden.", effects: [
                "Sie kann nur kriechen oder die Hälfte ihrer Bewegungsrate ausgeben, um aufzustehen; bei Bewegungsrate 0 kann sie nicht aufstehen.",
                "Ihre Angriffswürfe sind im Nachteil.",
                "Angriffe gegen sie sind im Vorteil, wenn der Angreifer höchstens 1,5 m entfernt ist; sonst im Nachteil."
            ], isOfficial: true),
            StatusDefinition(id: "grappled", label: "Gepackt", short: "Gep", category: "movement", priority: 2, polarity: .bad, description: "Die Kreatur wird festgehalten.", effects: [
                "Bewegungsrate 0 und kann nicht erhöht werden.",
                "Angriffe gegen Ziele außer der packenden Kreatur sind im Nachteil.",
                "Die packende Kreatur kann sie ziehen oder tragen; das kostet meist doppelte Bewegung."
            ], isOfficial: true),
            StatusDefinition(id: "charmed", label: "Bezaubert", short: "Bez", category: "mental", priority: 2, polarity: .bad, description: "Die Kreatur ist magisch oder anderweitig eingenommen.", effects: [
                "Sie kann den Zauberwirker nicht angreifen oder als Ziel schädigender Fähigkeiten und magischer Effekte wählen.",
                "Der Zauberwirker hat Vorteil bei Attributswürfen für soziale Interaktionen mit ihr."
            ], isOfficial: true),
            StatusDefinition(id: "dead", label: "Tot", short: "Tot", category: "critical", priority: 10, polarity: .bad, description: "Die Kreatur ist tot.", effects: [
                "Keine Trefferpunkte und keine Heilung möglich, bis ein passender Wiederbelebungseffekt greift.",
                "Als Encounter-Marker gedacht; ersetzt keine detaillierte Todes-/Wiederbelebungsregel."
            ], isOfficial: true)
        ]
    }
}

/// CR/HG als Zahl für Vergleiche („10+“-Filter): „1/4“ → 0.25, „17“ → 17, „?“ → -1.
public func challengeRatingValue(_ cr: String) -> Double {
    let s = cr.trimmingCharacters(in: .whitespaces)
    if s.isEmpty || s == "?" { return -1 }
    if s.contains("/") {
        let parts = s.split(separator: "/").compactMap { Double($0) }
        if parts.count == 2, parts[1] != 0 { return parts[0] / parts[1] }
        return -1
    }
    return Double(s.replacingOccurrences(of: "+", with: "")) ?? -1
}

public extension String {
    var slugifiedMonsterID: String {
        let folded = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
        let allowed = folded.map { char -> Character in
            if char.isLetter || char.isNumber { return Character(String(char).lowercased()) }
            if char == " " || char == "-" || char == "_" { return "_" }
            return "_"
        }
        let collapsed = String(allowed).split(separator: "_").joined(separator: "_")
        return collapsed.isEmpty ? "monster_\(Int(Date().timeIntervalSince1970))" : collapsed
    }
}
