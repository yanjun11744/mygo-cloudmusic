import SwiftUI

@main
struct MyGoCloudMusicApp: App {
    @StateObject private var store = MusicStore()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            MusicRootView()
                .environmentObject(store)
                .environmentObject(player)
                .tint(.myGoAccent)
                .task {
                    await store.restore()
                }
        }
    }
}
