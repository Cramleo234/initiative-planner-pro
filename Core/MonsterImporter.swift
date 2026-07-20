import Foundation

public enum MonsterImporterError: LocalizedError, Equatable {
    case empty
    case noMonstersFound

    public var errorDescription: String? {
        switch self {
        case .empty: return "Der Import ist leer."
        case .noMonstersFound: return "Keine Monsterdaten erkannt. Unterstützt werden Markdown-Frontmatter, Schlüssel/Wert-Listen und kompakte Textblöcke."
        }
    }
}

public enum MonsterImporter {
    public static func importMonsters(from text: String, sourceName: String = "Import") throws -> [MonsterTemplate] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MonsterImporterError.empty }

        // Datei mit Frontmatter = genau EIN Monster. Der Body gehört als Statblock
        // dazu und wird NICHT nach weiteren Monstern durchsucht (verhindert
        // Phantom-Einträge aus Aktionsbeschreibungen).
        if let frontmatterMonster = parseFrontmatterDocument(trimmed, filename: sourceName) {
            return [frontmatterMonster]
        }

        var imported: [MonsterTemplate] = []
        let blocks = splitIntoBlocks(trimmed)
        for block in blocks {
            if let monster = parseKeyValueBlock(block, sourceName: sourceName) ?? parseCompactBlock(block, sourceName: sourceName) {
                if !imported.contains(where: { $0.id == monster.id }) { imported.append(monster) }
            }
        }

        guard !imported.isEmpty else { throw MonsterImporterError.noMonstersFound }
        return imported
    }

    private static func splitIntoBlocks(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = #"\n\s*(?:---|===|###|##)\s*\n|\n\s*\n\s*\n"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [normalized] }
        var blocks: [String] = []
        var cursor = normalized.startIndex
        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        for match in regex.matches(in: normalized, range: nsRange) {
            guard let range = Range(match.range, in: normalized) else { continue }
            let piece = String(normalized[cursor..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { blocks.append(piece) }
            cursor = range.upperBound
        }
        let tail = String(normalized[cursor..<normalized.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { blocks.append(tail) }
        return blocks
    }

    private static func parseFrontmatterDocument(_ text: String, filename: String) -> MonsterTemplate? {
        guard text.hasPrefix("---"), let endRange = text.range(of: "\n---", options: [], range: text.index(text.startIndex, offsetBy: min(3, text.count))..<text.endIndex) else { return nil }
        let fm = String(text[text.index(text.startIndex, offsetBy: 3)..<endRange.lowerBound])
        let values = yamlishDictionary(from: fm)
        guard var monster = buildMonster(values: values, fallbackName: filename.replacingOccurrences(of: #"\.(md|txt)$"#, with: "", options: .regularExpression), sourceName: filename) else { return nil }
        let body = String(text[endRange.upperBound...])
        let statblock = buildStatBlock(values: values, body: body)
        monster.statblock = statblock.isEmpty ? nil : statblock
        monster.tokenFilename = extractTokenFilename(from: body)
        return monster
    }

    /// Liest den Token-Dateinamen aus einer Obsidian-Einbettung des Body:
    /// `![[Aboleth (Token).webp|378]]` → „Aboleth (Token).webp“. Nur Token-Bilder
    /// (mit „(Token)“ im Namen), nicht das Vollbild.
    static func extractTokenFilename(from body: String) -> String? {
        let pattern = #"!\[\[([^\]\|]*\(Token\)[^\]\|]*\.(?:webp|png|jpe?g))(?:\|[^\]]*)?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let m = regex.firstMatch(in: body, range: ns),
              let r = Range(m.range(at: 1), in: body) else { return nil }
        return String(body[r]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Statblock (Frontmatter-Zusatzfelder + Body-Abschnitte)

    /// Entfernt YAML-Listen-Klammern und Anführungszeichen: "[Blitz, Kälte]" → "Blitz, Kälte".
    private static func cleanListValue(_ raw: String?) -> String {
        var value = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("[") && value.hasSuffix("]") {
            value = String(value.dropFirst().dropLast())
        }
        return value.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'")))
    }

    /// Markdown-Auszeichnung entfernen und Leerraum glätten.
    private static func cleanMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func buildStatBlock(values: [String: String], body: String) -> StatBlock {
        var sb = StatBlock()
        sb.subtitle = cleanListValue(values["untertitel"])
        sb.size = cleanListValue(values["größe"])
        sb.alignment = cleanListValue(values["gesinnung"])
        sb.habitat = cleanListValue(values["habitat"])
        sb.speed = cleanListValue(values["bewegungsrate"])
        sb.senses = cleanListValue(values["sinne"])
        sb.languages = cleanListValue(values["sprachen"])
        sb.skills = cleanListValue(values["fertigkeiten"])
        sb.resistances = cleanListValue(values["resistenzen"])
        sb.immunities = cleanListValue(values["immunitäten"])
        sb.vulnerabilities = cleanListValue(values["anfälligkeiten"])
        sb.equipment = cleanListValue(values["ausrüstung"])
        sb.xp = cleanListValue(values["ep"])
        sb.proficiency = cleanListValue(values["üb"])

        for (key, label) in [("stä", "STÄ"), ("ges", "GES"), ("kon", "KON"), ("int", "INT"), ("wei", "WEI"), ("cha", "CHA")] {
            guard let scoreRaw = values[key], let score = Int(scoreRaw.trimmingCharacters(in: .whitespaces)) else { continue }
            sb.abilities.append(AbilityValue(label: label, score: score,
                                             mod: cleanListValue(values[key + "_mod"]),
                                             save: cleanListValue(values[key + "_rw"])))
        }

        parseBodySections(body, into: &sb)
        return sb
    }

    /// Zerlegt den Markdown-Body in die bekannten Abschnitte und extrahiert
    /// `**Name:** Text`-Einträge. Codeblöcke (dataviewjs) und Tabellen werden übersprungen.
    private static func parseBodySections(_ body: String, into sb: inout StatBlock) {
        let withoutCode = body.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        let entryPattern = try? NSRegularExpression(pattern: #"^\*\*(.+?):?\*\*:?\s*(.*)$"#)
        // Zauberlisten-Zeilen („Beliebig oft:", „Je 1-mal täglich:") gehören zum vorherigen Eintrag.
        let spellListPattern = try? NSRegularExpression(pattern: #"^(je\s+)?(beliebig oft|\d+[\-‑–]?\s?mal täglich.*|\d+\s?×\s?/?\s?tag)$"#, options: [.caseInsensitive])

        var currentSection: WritableKeyPath<StatBlock, [NamedAbility]>? = nil
        var currentEntry: NamedAbility? = nil

        func flush() {
            if let entry = currentEntry, let section = currentSection {
                sb[keyPath: section].append(entry)
            }
            currentEntry = nil
        }

        for rawLine in withoutCode.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                flush()
                switch line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased() {
                case "merkmale": currentSection = \.traits
                case "aktionen": currentSection = \.actions
                case "bonusaktionen": currentSection = \.bonusActions
                case "reaktionen": currentSection = \.reactions
                case "legendäre aktionen": currentSection = \.legendaryActions
                default: currentSection = nil
                }
                continue
            }
            if line.hasPrefix("# ") { flush(); currentSection = nil; continue }
            guard let section = currentSection else { continue }
            if line.isEmpty || line == "---" || line.hasPrefix("|") { continue }

            // Kursive Einleitung (z. B. „Anwendungen legendärer Aktionen: 3 …")
            if line.hasPrefix("*"), !line.hasPrefix("**") {
                let cleaned = cleanMarkdown(line)
                if section == \StatBlock.legendaryActions, sb.legendaryIntro.isEmpty, currentEntry == nil {
                    sb.legendaryIntro = cleaned
                } else if var entry = currentEntry {
                    entry.text += (entry.text.isEmpty ? "" : "\n") + cleaned
                    currentEntry = entry
                }
                continue
            }

            // Listenpunkte und nummerierte Unterpunkte → Fortsetzung des Eintrags
            if line.hasPrefix("- ") {
                if currentEntry != nil {
                    currentEntry?.text += "\n• " + cleanMarkdown(String(line.dropFirst(2)))
                }
                continue
            }
            if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                if currentEntry != nil {
                    currentEntry?.text += "\n" + cleanMarkdown(line)
                }
                continue
            }

            // Neuer Eintrag: **Name:** Text
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = entryPattern?.firstMatch(in: line, range: nsRange),
               let nameRange = Range(match.range(at: 1), in: line),
               let restRange = Range(match.range(at: 2), in: line) {
                let name = cleanMarkdown(String(line[nameRange]))
                let rest = cleanMarkdown(String(line[restRange]))
                let nameFull = NSRange(name.startIndex..<name.endIndex, in: name)
                if spellListPattern?.firstMatch(in: name, range: nameFull) != nil, currentEntry != nil {
                    currentEntry?.text += "\n• " + name + ": " + rest
                } else {
                    flush()
                    currentEntry = NamedAbility(name: name, text: rest)
                }
                continue
            }

            // Normale Fortsetzungszeile
            if currentEntry != nil {
                currentEntry?.text += " " + cleanMarkdown(line)
            }
        }
        flush()
    }

    private static func parseKeyValueBlock(_ block: String, sourceName: String) -> MonsterTemplate? {
        let values = yamlishDictionary(from: block)
        guard values.keys.contains(where: { ["name", "Name", "rk", "ac", "hp", "tp", "cr", "hg"].contains($0) }) else { return nil }
        return buildMonster(values: values, fallbackName: nil, sourceName: sourceName)
    }

    private static func parseCompactBlock(_ block: String, sourceName: String) -> MonsterTemplate? {
        let lines = block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let name = lines.first else { return nil }
        let joined = lines.joined(separator: " ")
        let ac = firstInt(in: joined, patterns: [#"(?:RK|AC|Armor Class)\s*[:=]?\s*(\d+)"#])
        let hp = hpPair(from: joined)
        guard ac != nil || hp.average > 0 else { return nil }
        let cr = firstString(in: joined, patterns: [#"(?:CR|HG|Challenge)\s*[:=]?\s*([0-9]+\/[0-9]+|[0-9]+\+?)"#]) ?? "?"
        let ini = firstInt(in: joined, patterns: [#"(?:Ini|Initiative|Initiative Bonus)\s*[:=]?\s*([+-]?\d+)"#]) ?? 0
        let type = firstString(in: joined, patterns: [#"(?:Typ|Type)\s*[:=]?\s*([^.;]+)"#]) ?? ""
        return MonsterTemplate(id: name.slugifiedMonsterID, name: name, armorClass: ac ?? 10, hpAverage: max(1, hp.average), hpDice: hp.dice, challengeRating: cr, initiativeBonus: ini, type: type, source: sourceName, notes: "Importiert aus Text", importedAt: Date())
    }

    private static func yamlishDictionary(from text: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("---") else { continue }
            if let range = line.range(of: #"^([A-Za-zÄÖÜäöüß_ -]+)\s*[:=]\s*(.*)$"#, options: .regularExpression) {
                let pair = String(line[range])
                let split = pair.split(separator: pair.contains(":") ? ":" : "=", maxSplits: 1).map(String.init)
                if split.count == 2 {
                    let key = split[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let value = split[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'")))
                    values[key] = value
                }
            }
        }
        return values
    }

    private static func buildMonster(values: [String: String], fallbackName: String?, sourceName: String) -> MonsterTemplate? {
        let name = firstValue(values, keys: ["name", "titel"]) ?? fallbackName
        guard let finalName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !finalName.isEmpty else { return nil }
        let ac = Int(firstValue(values, keys: ["rk", "ac", "armor class"]) ?? "") ?? 10
        let hpRaw = firstValue(values, keys: ["tp", "hp", "hit points", "trefferpunkte"]) ?? ""
        let hp = hpPair(from: hpRaw)
        guard hp.average > 0 || values["name"] != nil else { return nil }
        let cr = firstValue(values, keys: ["hg", "cr", "challenge", "challenge rating"]) ?? "?"
        let iniRaw = firstValue(values, keys: ["initiative", "ini", "initiativebonus", "initiative bonus"]) ?? "0"
        let ini = firstInt(in: iniRaw, patterns: [#"([+-]?\d+)"#]) ?? 0
        let type = firstValue(values, keys: ["typ", "type", "art"]) ?? ""
        let notes = firstValue(values, keys: ["notizen", "notes", "beschreibung", "description"]) ?? ""
        return MonsterTemplate(id: finalName.slugifiedMonsterID, name: finalName, armorClass: ac, hpAverage: max(1, hp.average), hpDice: hp.dice, challengeRating: cr, initiativeBonus: ini, type: type, source: sourceName, notes: notes, importedAt: Date())
    }

    private static func firstValue(_ dict: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key.lowercased()], !value.isEmpty { return value }
        }
        return nil
    }

    private static func hpPair(from text: String) -> (average: Int, dice: String) {
        let average = firstInt(in: text, patterns: [#"(\d+)\s*(?:\(([^\)]+)\))?"#]) ?? 0
        let dice = firstString(in: text, patterns: [#"\(([^\)]*[dDwW][^\)]*)\)"#, #"(\d+\s*[dDwW]\s*\d+\s*(?:[+-]\s*\d+)?)"#])?.replacingOccurrences(of: "W", with: "d").replacingOccurrences(of: "w", with: "d").replacingOccurrences(of: " ", with: "")
        return (average, dice ?? (average > 0 ? "\(max(1, average / 5))d8" : "1d8"))
    }

    private static func firstInt(in text: String, patterns: [String]) -> Int? {
        guard let s = firstString(in: text, patterns: patterns) else { return nil }
        return Int(s.replacingOccurrences(of: "+", with: ""))
    }

    private static func firstString(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsRange), match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }
}
