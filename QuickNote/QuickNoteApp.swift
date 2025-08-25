//
//  QuickNoteApp.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI

@main
struct QuickNoteApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
