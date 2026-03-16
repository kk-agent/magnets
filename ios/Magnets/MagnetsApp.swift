import SwiftData
import SwiftUI

@main
struct MagnetsApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Magnets", systemImage: "sparkles.rectangle.stack.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
            }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}
