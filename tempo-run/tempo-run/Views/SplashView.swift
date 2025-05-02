import SwiftUI

struct SplashView: View {
    @EnvironmentObject var spotifyManager: SpotifyManager
    @State private var navigateToNext = false

    let primaryBlue = Color(red: 90/255, green: 191/255, blue: 211/255)
    let darkGray = Color(UIColor.darkGray)

    var body: some View {
        VStack {
            Spacer(minLength: 100)

            // 🔠 Title
            VStack(spacing: -45) {
                Text("TEMPO")
                    .font(.custom("Avenir-MediumOblique", size: 60))
                    .foregroundColor(darkGray)
                Text("RUN")
                    .font(.custom("Avenir-BlackOblique", size: 96))
                    .foregroundColor(darkGray)
            }
            .padding(.bottom, 30)

            // 🌀 Logo
            Image("tempo-run-logo") // <-- Add to Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(.bottom, 40)

            // 🔗 Buttons
            VStack(spacing: 15) {
                Button(action: {
                    spotifyManager.login()
                }) {
                    Text("Link Spotify")
                        .foregroundColor(.white)
                        .font(.custom("Avenir-Black", size: 20))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(primaryBlue)
                        .cornerRadius(25)
                        .padding(.horizontal, 50)
                }

                Button(action: {
                    // Future: how it works screen
                }) {
                    Text("How it Works")
                        .foregroundColor(.white)
                        .font(.custom("Avenir-Black", size: 20))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(darkGray)
                        .cornerRadius(25)
                        .padding(.horizontal, 50)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .onReceive(spotifyManager.$isLoggedIn) { loggedIn in
            if loggedIn {
                navigateToNext = true
            }
        }
        .fullScreenCover(isPresented: $navigateToNext) {
            HomeView()
                .environmentObject(spotifyManager)
        }
    }
}

