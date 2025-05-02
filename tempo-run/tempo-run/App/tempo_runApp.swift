import SwiftUI
import Firebase

@main
struct TempoRunApp: App {
    @StateObject var spotifyManager = SpotifyManager()


    init() {
        FirebaseApp.configure() 
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(spotifyManager)
        }
    }
}

