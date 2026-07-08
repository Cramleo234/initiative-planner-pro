import XCTest

final class MonsterImporterTests: XCTestCase {
    func testImportsObsidianStyleFrontmatterPermanentlyCompatibleMonster() throws {
        let text = """
        ---
        name: Schattenwolf
        rk: 14
        tp: 45 (6d10+12)
        hg: 3
        initiative: +3
        typ: Bestie
        notizen: Rudeljäger
        ---
        """
        let monsters = try MonsterImporter.importMonsters(from: text, sourceName: "Bestiarium.md")
        XCTAssertEqual(monsters.count, 1)
        XCTAssertEqual(monsters[0].name, "Schattenwolf")
        XCTAssertEqual(monsters[0].armorClass, 14)
        XCTAssertEqual(monsters[0].hpAverage, 45)
        XCTAssertEqual(monsters[0].hpDice, "6d10+12")
        XCTAssertEqual(monsters[0].challengeRating, "3")
        XCTAssertEqual(monsters[0].initiativeBonus, 3)
    }

    func testImportsKeyValueBlocks() throws {
        let text = """
        Name: Kristallspinne
        AC: 16
        HP: 58 (9d8+18)
        CR: 4
        Initiative: +2
        Type: Konstrukt
        """
        let monsters = try MonsterImporter.importMonsters(from: text, sourceName: "Paste")
        XCTAssertEqual(monsters.first?.name, "Kristallspinne")
        XCTAssertEqual(monsters.first?.type, "Konstrukt")
    }

    func testEmptyImportThrows() {
        XCTAssertThrowsError(try MonsterImporter.importMonsters(from: "   "))
    }

    func testFrontmatterFileYieldsSingleMonsterWithFullStatblock() throws {
        let text = """
        ---
        name: Testdrache
        untertitel: Drache der Prüfung
        typ: Drache (metallisch)
        größe: Riesig
        gesinnung: Rechtschaffen gut
        rk: 19
        tp: "243 (18W12+126)"
        initiative: "+14 (24)"
        bewegungsrate: "12 m, Fliegen 24 m"
        stä: 27
        stä_mod: "+8"
        stä_rw: "+8"
        ges: 14
        ges_mod: "+2"
        ges_rw: "+8"
        kon: 25
        kon_mod: "+7"
        kon_rw: "+7"
        int: 16
        int_mod: "+3"
        int_rw: "+3"
        wei: 15
        wei_mod: "+2"
        wei_rw: "+8"
        cha: 24
        cha_mod: "+7"
        cha_rw: "+7"
        hg: 17
        üb: "+6"
        fertigkeiten: [Heimlichkeit +8, Wahrnehmung +14]
        resistenzen: [Blitz, Kälte]
        immunitäten: [Feuer]
        sinne: [Blindsicht 18 m, Passive Wahrnehmung 24]
        sprachen: [Drakonisch, Gemeinsprache]
        ---

        ```dataviewjs
        const p = dv.current();
        // Dieser Obsidian-Block enthält Zahlen wie RK 5 und darf NICHT geparst werden.
        ```

        # Testdrache
        *Riesiger Drache, rechtschaffen gut*

        ## Hintergrund

        Lore-Text, der nicht importiert werden soll. Er erwähnt 45 (6d10+12) TP.

        ---

        ## Merkmale

        **Amphibisch:** Der Drache kann Luft und Wasser atmen.

        **Legendäre Resistenz (3-mal täglich):** Bei gescheitertem Rettungswurf bestehen.

        ## Aktionen

        **Mehrfachangriff:** Der Drache führt drei Zerfetzen-Angriffe aus.

        **Feuerodem (Aufladung 5–6):** *Geschicklichkeitsrettungswurf:* SG 21. *Misserfolg:* 66 (12W10) Feuerschaden.

        **Zauberwirken:** Der Drache wirkt Zauber (SG 21):
        - **Beliebig oft:** *Magie entdecken*, *Gestaltwandel*
        - **Je 1-mal täglich:** *Flammenschlag*

        ## Bonusaktionen

        **Teleportieren:** Bis zu 18 m in einen freien Bereich.

        ## Reaktionen

        **Parieren:** *Auslöser:* Nahkampftreffer. *Antwort:* +2 RK.

        ## Legendäre Aktionen

        *Anwendungen legendärer Aktionen: 3. Unmittelbar nach dem Zug einer anderen Kreatur.*

        **Anspringen:** Der Drache legt die Hälfte seiner Bewegungsrate zurück.
        """
        let monsters = try MonsterImporter.importMonsters(from: text, sourceName: "Testdrache.md")
        // Genau EIN Monster — keine Phantom-Einträge aus Body-Abschnitten
        XCTAssertEqual(monsters.count, 1)
        XCTAssertEqual(monsters[0].hpAverage, 243)

        let sb = try XCTUnwrap(monsters[0].statblock)
        XCTAssertEqual(sb.abilities.count, 6)
        XCTAssertEqual(sb.abilities.first?.label, "STÄ")
        XCTAssertEqual(sb.abilities.first?.score, 27)
        XCTAssertEqual(sb.resistances, "Blitz, Kälte")
        XCTAssertEqual(sb.immunities, "Feuer")
        XCTAssertEqual(sb.speed, "12 m, Fliegen 24 m")
        XCTAssertEqual(sb.traits.count, 2)
        XCTAssertTrue(sb.traits.contains { $0.name.hasPrefix("Legendäre Resistenz") })
        XCTAssertTrue(sb.actions.contains { $0.name == "Feuerodem (Aufladung 5–6)" })
        // Zauberlisten hängen am Zauberwirken-Eintrag, kein eigener Eintrag
        let spellcasting = try XCTUnwrap(sb.actions.first { $0.name == "Zauberwirken" })
        XCTAssertTrue(spellcasting.text.contains("Beliebig oft"))
        XCTAssertFalse(sb.actions.contains { $0.name == "Beliebig oft" })
        XCTAssertEqual(sb.bonusActions.first?.name, "Teleportieren")
        XCTAssertEqual(sb.reactions.first?.name, "Parieren")
        XCTAssertEqual(sb.legendaryActions.first?.name, "Anspringen")
        XCTAssertTrue(sb.legendaryIntro.contains("Anwendungen legendärer Aktionen"))
    }
}

@MainActor
final class FolderImportTests: XCTestCase {
    func testFolderImportRecursivelyImportsOnlyMatchingMarkdown() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("folder_import_\(UUID().uuidString)", isDirectory: true)
        let sub = tmp.appendingPathComponent("unterordner/tief", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try """
        ---
        name: Höhlentroll
        rk: 15
        tp: 84 (8d10+40)
        hg: 5
        ---
        """.write(to: tmp.appendingPathComponent("troll.md"), atomically: true, encoding: .utf8)

        // Monster in tief verschachteltem Unterordner wird gefunden
        try """
        ---
        name: Nebelgeist
        ac: 12
        hp: 22 (5d8)
        ---
        """.write(to: sub.appendingPathComponent("geist.md"), atomically: true, encoding: .utf8)

        // Notiz ohne Monster-Werte wird übersprungen (kein 1-HP-Phantommonster)
        try """
        ---
        name: Sitzung 12
        datum: 2026-07-08
        ---
        Heute haben wir den Markt besucht.
        """.write(to: sub.appendingPathComponent("sitzungsnotiz.md"), atomically: true, encoding: .utf8)

        // Nicht-.md-Dateien werden ignoriert
        try "name: Falsch\nrk: 10\ntp: 5".write(to: tmp.appendingPathComponent("ignoriert.txt"), atomically: true, encoding: .utf8)

        let store = PlannerStore(fileURL: tmp.appendingPathComponent("state.json"), load: false)
        store.importMonsterFolder(tmp)

        XCTAssertTrue(store.state.monsterDatabase.contains { $0.name == "Höhlentroll" })
        XCTAssertTrue(store.state.monsterDatabase.contains { $0.name == "Nebelgeist" }, "Unterordner müssen rekursiv durchsucht werden")
        XCTAssertFalse(store.state.monsterDatabase.contains { $0.name == "Sitzung 12" }, "Notizen ohne Monster-Werte dürfen nicht importiert werden")
        XCTAssertFalse(store.state.monsterDatabase.contains { $0.name == "Falsch" }, "Nur .md-Dateien werden gelesen")
        XCTAssertEqual(store.state.monsterDatabase.first { $0.name == "Höhlentroll" }?.hpDice, "8d10+40")
    }
}
