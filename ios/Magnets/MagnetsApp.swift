import Observation
import SwiftData
import SwiftUI

@main
struct MagnetsApp: App {
    @State private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            TabView(selection: Binding(
                get: { appRouter.selectedTab },
                set: { appRouter.selectedTab = $0 }
            )) {
                HomeView()
                    .tag(AppTab.magnets)
                    .tabItem {
                        Label("Magnets", systemImage: "sparkles.rectangle.stack.fill")
                    }

                SettingsView()
                    .tag(AppTab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
            }
            .environment(appRouter)
            .onOpenURL { url in
                appRouter.handle(url)
            }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

enum AppTab: Hashable {
    case magnets
    case settings
}

struct PendingMagnetsDeepLink: Identifiable, Equatable {
    let id = UUID()
    let link: MagnetsDeepLink
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .magnets
    var pendingLink: PendingMagnetsDeepLink?

    func handle(_ url: URL) {
        guard let deepLink = MagnetsDeepLink(url: url) else {
            return
        }

        selectedTab = .magnets
        pendingLink = PendingMagnetsDeepLink(link: deepLink)
    }

    func consumePendingLink() -> PendingMagnetsDeepLink? {
        defer { pendingLink = nil }
        return pendingLink
    }
}
