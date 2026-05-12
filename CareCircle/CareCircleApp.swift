//
//  CareCircleApp.swift
//  CareCircle
//
//  Created by naman yadav on 2/5/26.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct CareCircleApp: App {
    // Configure Firebase when the app initializes; run journal cleanup (remove entries older than 7 days).
    init() {
        FirebaseApp.configure()
        JournalStore.shared.runCleanupIfNeeded()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
