import XCTest
import AppKit

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
final class CombatLogicTests: XCTestCase {
    private func makeStore() -> PlannerStore {
        PlannerStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("combat_test_\(UUID().uuidString).json"), load: false)
    }

    func testStatusDurationTicksDownAndEnds() {
        let store = makeStore()
        store.addCreature(name: "Held", kind: .player, armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: 10)
        store.addCreature(name: "Ork", kind: .monster, armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: 5)
        let heldID = store.state.players[0].id
        store.toggleStatus("poisoned", for: heldID)
        store.setStatusDuration(heldID, statusID: "poisoned", duration: 1)
        XCTAssertEqual(store.state.players[0].statuses.first { $0.id == "poisoned" }?.duration, 1)
        // Held ist aktiv (höchste Initiative) → Zugwechsel tickt seine Dauer auf 0 → Status endet
        store.nextTurn()
        XCTAssertFalse(store.state.players[0].statuses.contains { $0.id == "poisoned" })
    }

    func testThreeFailedDeathSavesMarkDead() {
        let store = makeStore()
        store.addCreature(name: "Held", kind: .player, armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: nil)
        let id = store.state.players[0].id
        store.setDeathSaves(id, successes: 0, failures: 3)
        XCTAssertEqual(store.state.players[0].deathSaveFailures, 3)
        XCTAssertTrue(store.state.players[0].statuses.contains { $0.id == "dead" })
    }

    func testThreeSuccessfulDeathSavesMarkStableAndHealingResets() {
        let store = makeStore()
        store.addCreature(name: "Held", kind: .player, armorClass: 10, hpExpression: "10", initiativeBonus: 0, initiative: nil)
        let id = store.state.players[0].id
        store.applyDamage(id, expression: "10")
        store.setDeathSaves(id, successes: 3, failures: 1)
        XCTAssertTrue(store.state.players[0].statuses.contains { $0.id == "stable" })
        // Heilung über 0 setzt Todesrettungswürfe und Stabil-Marker zurück
        store.applyHealing(id, expression: "5")
        XCTAssertNil(store.state.players[0].deathSaveSuccesses)
        XCTAssertNil(store.state.players[0].deathSaveFailures)
        XCTAssertFalse(store.state.players[0].statuses.contains { $0.id == "stable" })
    }

    func testDamageWhileConcentratingQueuesCheckWithCorrectDC() {
        let store = makeStore()
        store.addCreature(name: "Magier", kind: .player, armorClass: 10, hpExpression: "30", initiativeBonus: 0, initiative: nil)
        let id = store.state.players[0].id
        store.toggleStatus("concentration", for: id)
        store.applyDamage(id, expression: "26")
        XCTAssertEqual(store.concentrationChecks.count, 1)
        XCTAssertEqual(store.concentrationChecks.first?.dc, 13, "SG = halber Schaden, wenn höher als 10")
        store.resolveConcentrationCheck(store.concentrationChecks[0], passed: false)
        XCTAssertFalse(store.state.players[0].statuses.contains { $0.id == "concentration" })
        XCTAssertTrue(store.concentrationChecks.isEmpty)
    }

    func testSmallDamageConcentrationDCIsTen() {
        let store = makeStore()
        store.addCreature(name: "Magier", kind: .player, armorClass: 10, hpExpression: "30", initiativeBonus: 0, initiative: nil)
        let id = store.state.players[0].id
        store.toggleStatus("concentration", for: id)
        store.applyDamage(id, expression: "7")
        XCTAssertEqual(store.concentrationChecks.first?.dc, 10, "SG 10, wenn halber Schaden darunter liegt")
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

    func testExtractsTokenFilenameFromObsidianEmbed() throws {
        let text = """
        ---
        name: Aboleth
        rk: 17
        tp: 150 (20W10+40)
        hg: 10
        ---

        ## Merkmale
        **Schleimwolke:** …

        ![[Aboleth.webp|755]]

        ![[Aboleth (Token).webp|378]]
        """
        let monsters = try MonsterImporter.importMonsters(from: text, sourceName: "Aboleth.md")
        XCTAssertEqual(monsters.count, 1)
        // Nur das (Token)-Bild wird erkannt, nicht das Vollbild.
        XCTAssertEqual(monsters[0].tokenFilename, "Aboleth (Token).webp")
    }

    func testIgnoresTokenlessDocuments() throws {
        let text = """
        ---
        name: Schattenwolf
        rk: 14
        tp: 45 (6d10+12)
        hg: 3
        ---

        ![[Schattenwolf.webp|755]]
        """
        let monsters = try MonsterImporter.importMonsters(from: text, sourceName: "Schattenwolf.md")
        XCTAssertNil(monsters[0].tokenFilename, "Ohne (Token)-Bild darf kein Token gesetzt werden")
    }

    /// End-to-End: Monster-.md mit Token-Einbettung + zugehöriges Bild im Nachbarordner
    /// werden importiert; der Token wird aufgelöst und im TokenStore-Cache abgelegt.
    func testFolderImportResolvesAndCachesToken() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let monDir = tmp.appendingPathComponent("Monster")
        let imgDir = tmp.appendingPathComponent("Bilder")
        try FileManager.default.createDirectory(at: monDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try """
        ---
        name: Testkobold
        rk: 12
        tp: 7 (2d6)
        hg: 1/4
        typ: Humanoid
        ---

        ## Aktionen
        **Dolch:** …

        ![[Testkobold (Token).png|378]]
        """.write(to: monDir.appendingPathComponent("Testkobold.md"), atomically: true, encoding: .utf8)

        // Ein echtes kleines PNG erzeugen (Token-Bild im „Nachbarordner“).
        let img = NSImage(size: NSSize(width: 40, height: 40))
        img.lockFocus(); NSColor.systemTeal.setFill(); NSRect(x: 0, y: 0, width: 40, height: 40).fill(); img.unlockFocus()
        let png = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try png.write(to: imgDir.appendingPathComponent("Testkobold (Token).png"))

        let store = PlannerStore(fileURL: tmp.appendingPathComponent("state.json"), load: false)
        store.importMonsterURLs([tmp])

        let template = store.state.monsterDatabase.first { $0.name == "Testkobold" }
        XCTAssertNotNil(template, "Monster muss importiert sein")
        XCTAssertEqual(template?.tokenFilename, "Testkobold (Token).png")
        XCTAssertNotNil(TokenStore.shared.image(for: template?.id), "Token muss aufgelöst und gecacht sein")

        if let id = template?.id { TokenStore.shared.remove(id) }  // Test-Token aus echtem Cache räumen
    }
}
