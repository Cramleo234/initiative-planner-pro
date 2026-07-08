import SwiftUI

@main
struct InitiativePlannerProMacApp: App {
    @StateObject private var store = PlannerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1180, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Spieler hinzufügen") { NotificationCenter.default.post(name: .focusAddPlayer, object: nil) }
                    .keyboardShortcut("n")
            }
            CommandMenu("Kampf") {
                Button("Nächster Zug") { store.nextTurn() }.keyboardShortcut(.space, modifiers: [])
                Button("Vorheriger Zug") { store.previousTurn() }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("Monster-Initiative würfeln") { store.rollAllMonsterInitiative() }.keyboardShortcut("r")
                Divider()
                Button("Rückgängig") { store.undo() }.keyboardShortcut("z")
                Button("Wiederholen") { store.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandMenu("Darstellung") {
                ForEach(PlannerTheme.all) { theme in
                    Button {
                        store.setTheme(theme.id, named: theme.name)
                    } label: {
                        if store.state.selectedTheme == theme.id {
                            Label(theme.name, systemImage: "checkmark")
                        } else {
                            Text(theme.name)
                        }
                    }
                }
                Divider()
                Button("Nächstes Theme") {
                    let ids = PlannerTheme.all.map(\.id)
                    let idx = ids.firstIndex(of: store.state.selectedTheme) ?? 0
                    let next = PlannerTheme.all[(idx + 1) % ids.count]
                    store.setTheme(next.id, named: next.name)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        WindowGroup("Player View", id: "player-view") {
            PlayerViewWindow()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

extension Notification.Name {
    static let focusAddPlayer = Notification.Name("focusAddPlayer")
}
