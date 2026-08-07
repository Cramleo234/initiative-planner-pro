import XCTest

@MainActor
final class PlayerDatabaseTests: XCTestCase {
    private func makeStore() -> PlannerStore {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        return PlannerStore(fileURL: tmp, load: false)
    }

    // MARK: Schema-Migration

    func testSchema1FileWithoutPlayerDatabaseDecodesWithEmptyDefaults() throws {
        // Simuliert eine Schema-1-Datei: kein `schemaVersion`, kein `playerDatabase`-Schlüssel.
        let json = """
        {"players":[],"monsters":[],"round":1,"monsterDatabase":[],"encounters":[],
         "statuses":[],"hpMode":"average","keepDatabaseOpen":true,"selectedTheme":"glass","log":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(PlannerState.self, from: Data(json.utf8))
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.playerDatabase, [])
    }

    func testSchema2RoundtripPreservesPlayerDatabaseAndSourceLinks() throws {
        let template = PlayerTemplate(name: "Elyndra", armorClass: 16, maxHitPoints: 30, initiativeBonus: 2, notes: "Waldläuferin")
        let imageID = UUID()
        var creature = Creature(name: "Elyndra", kind: .player, sourcePlayerID: template.id, sourcePlayerImageID: imageID)
        creature.maxHitPoints = 30
        let state = PlannerState(players: [creature], playerDatabase: [template])

        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let roundtripped = try decoder.decode(PlannerState.self, from: encoder.encode(state))

        XCTAssertEqual(roundtripped.schemaVersion, PlannerState.currentSchemaVersion)
        XCTAssertEqual(roundtripped.playerDatabase, [template])
        XCTAssertEqual(roundtripped.players.first?.sourcePlayerID, template.id)
        XCTAssertEqual(roundtripped.players.first?.sourcePlayerImageID, imageID)
    }

    // MARK: Store-Operationen

    func testSavePlayerTemplateAddsEntryAndUndoRemovesIt() {
        let store = makeStore()
        let template = PlayerTemplate(name: "Boric")
        store.savePlayerTemplate(template)
        XCTAssertEqual(store.state.playerDatabase.map(\.name), ["Boric"])
        store.undo()
        XCTAssertTrue(store.state.playerDatabase.isEmpty)
    }

    func testDeletePlayerTemplateIsUndoable() {
        let store = makeStore()
        let template = PlayerTemplate(name: "Boric")
        store.savePlayerTemplate(template)
        store.deletePlayerTemplate(template.id)
        XCTAssertTrue(store.state.playerDatabase.isEmpty)
        store.undo()
        XCTAssertEqual(store.state.playerDatabase.map(\.name), ["Boric"])
    }

    func testSpawnPlayerIntoCombatAppliesSafeDefaultsWithoutChangingTemplate() {
        let store = makeStore()
        // Vorlage ohne RK/TP/Ini — Werte bleiben in der Vorlage "nicht gesetzt".
        let template = PlayerTemplate(name: "Nameloser Held")
        store.savePlayerTemplate(template)
        store.spawnPlayerIntoCombat(template.id)

        guard let combatant = store.state.players.first(where: { $0.sourcePlayerID == template.id }) else {
            return XCTFail("Kämpfer wurde nicht erzeugt")
        }
        XCTAssertEqual(combatant.armorClass, 10)
        XCTAssertEqual(combatant.maxHitPoints, 0)
        XCTAssertEqual(combatant.initiativeBonus, 0)
        XCTAssertNil(store.state.playerDatabase.first?.armorClass)
    }

    func testUpdatingTemplateImagePropagatesToActiveCombatant() {
        let store = makeStore()
        var template = PlayerTemplate(name: "Sera")
        store.savePlayerTemplate(template)
        store.spawnPlayerIntoCombat(template.id)

        let newImageID = UUID()
        template.imageID = newImageID
        store.savePlayerTemplate(template)

        let combatant = store.state.players.first { $0.sourcePlayerID == template.id }
        XCTAssertEqual(combatant?.sourcePlayerImageID, newImageID)
        // Andere Kampfwerte bleiben unberührt (kein Reset durch die Bildaktualisierung).
        XCTAssertEqual(combatant?.armorClass, 10)
    }

    func testSpawnIntoEncounterDoesNotAffectCurrentCombat() {
        let store = makeStore()
        let template = PlayerTemplate(name: "Toran")
        store.savePlayerTemplate(template)
        store.saveEncounter(name: "Hinterhalt am Fluss")
        guard let encounter = store.state.encounters.first else { return XCTFail("Encounter fehlt") }

        store.spawnPlayer(template.id, intoEncounter: encounter.id)

        XCTAssertTrue(store.state.players.isEmpty, "aktueller Kampf darf unverändert bleiben")
        let updated = store.state.encounters.first { $0.id == encounter.id }
        XCTAssertEqual(updated?.players.first?.sourcePlayerID, template.id)
    }
}
