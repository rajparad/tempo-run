import SwiftUI

enum RunMode: String, Codable, CaseIterable {
    case desiredPace = "🎯 Desired Pace"
    case fastRun = "⚡ Fast Run"
    case steadyRun = "🌊 Steady Run"

    var description: String {
        switch self {
        case .desiredPace:
            return "Set a goal pace, and Tempo Run will adapt music to keep you on track."
        case .fastRun:
            return "Just go all out — we’ll queue your highest-performance songs."
        case .steadyRun:
            return "Maintain a consistent rhythm based on how you start the run."
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var spotifyManager: SpotifyManager
    @State private var selectedMode: RunMode? = nil
    @State private var targetPace: Double = 5.0
    @State private var navigateToRun = false

    let primaryBlue = Color(red: 90/255, green: 191/255, blue: 211/255)
    let darkGray = Color(UIColor.darkGray)

    var body: some View {
        NavigationStack {
            VStack(spacing: 36) {
                Spacer(minLength: 40)

                // 🎧 Now Playing (with reserved height)
                VStack(spacing: 8) {
                    if isPlaying {
                        Image(systemName: "headphones")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(primaryBlue)

                        Text("Now Playing")
                            .font(.caption)
                            .foregroundColor(.gray)

                        let components = spotifyManager.currentSong.components(separatedBy: " - ")
                        let songTitle = components.first ?? ""
                        let artist = components.dropFirst().first ?? ""

                        VStack(spacing: 2) {
                            Text(songTitle)
                                .font(.headline)
                                .foregroundColor(darkGray)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .frame(width: 240)

                            Text(artist)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: 240)
                        }
                    } else {
                        Color.clear.frame(height: 100)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isPlaying)

                // 🧭 Title & Info
                VStack(spacing: 10) {
                    Text("Choose Your Run Mode")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(darkGray)

                    Text("Your music will adapt based on this choice.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // 🟦 Mode Buttons + Descriptions
                VStack(spacing: 20) {
                    ForEach(RunMode.allCases, id: \.self) { mode in
                        Button(action: {
                            selectedMode = mode
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(mode.rawValue)
                                        .font(.system(size: 18, weight: .semibold))
                                    Spacer()
                                    Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                }
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(darkGray)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                }

                // 🎯 Desired Pace (Slider with reserved space)
                VStack(spacing: 12) {
                    if selectedMode == .desiredPace {
                        Text("Target Pace: \(String(format: "%.2f", targetPace)) min/km")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Slider(value: $targetPace, in: 3.0...8.0, step: 0.1)
                            .tint(primaryBlue)
                            .padding(.horizontal, 60)
                    } else {
                        Color.clear
                            .frame(height: 60)
                            .padding(.horizontal, 60)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedMode)

                // ▶️ Start Run
                Button(action: {
                    navigateToRun = true
                }) {
                    Text("Start Run")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isStartEnabled ? primaryBlue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.horizontal, 60)
                }
                .disabled(!isStartEnabled)

                // 🛑 Warning (with reserved space)
                ZStack {
                    if !isPlaying {
                        Text("Play a Spotify playlist before starting your run.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isPlaying)

                Spacer()
            }
            .navigationDestination(isPresented: $navigateToRun) {
                LiveRunView(
                    runMode: selectedMode ?? .fastRun,
                    targetPace: selectedMode == .desiredPace ? targetPace : nil
                )
                .environmentObject(spotifyManager)
            }
        }
    }

    var isPlaying: Bool {
        !spotifyManager.currentSong.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isStartEnabled: Bool {
        guard let selected = selectedMode else { return false }
        if selected == .desiredPace && targetPace == 0 { return false }
        return isPlaying
    }
}

