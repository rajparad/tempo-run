import SwiftUI

struct LiveRunView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var spotifyManager: SpotifyManager
    @StateObject private var runManager = RunManager()

    let runMode: RunMode
    let targetPace: Double?

    @State private var lastKnownSong: String = ""
    @State private var playedSongs: [(song: String, pace: Double)] = []
    @State private var navigateToSummary = false
    @State private var isLoading = true

    let primaryBlue = Color(red: 90/255, green: 191/255, blue: 211/255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // 🎧 Circle Section
                ZStack {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [primaryBlue, Color.white]),
                                             center: .center,
                                             startRadius: 0,
                                             endRadius: 300))
                        .frame(width: 280, height: 280)

                    VStack(spacing: 8) {
                        Image(systemName: "headphones")
                            .resizable()
                            .frame(width: 26, height: 26)
                            .foregroundColor(.white)

                        VStack(spacing: 2) {
                            Text(spotifyManager.currentSong.components(separatedBy: " - ").first ?? "Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .frame(width: 240)

                            Text(spotifyManager.currentSong.components(separatedBy: " - ").dropFirst().first ?? "")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: 240)
                        }

                        Text(String(format: "%.2f", runManager.currentPace))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)

                        Text("min/km")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                // 📊 2x2 Stats Grid
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        statBlock(title: "Time Elapsed", value: formatTime(runManager.elapsedTime))
                        statBlock(title: "Mode", value: modeDisplay)
                    }
                    HStack(spacing: 40) {
                        statBlock(title: "Distance", value: formatDistance(runManager.distance))
                        statBlock(title: "Avg Pace", value: String(format: "%.2f", runManager.averagePace))
                    }
                }

                Spacer()

                // 🛑 End Run Button
                Button("End Run") {
                    runManager.stopRun()
                    logRunSummary()
                    navigateToSummary = true
                }
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(16)
                .padding(.horizontal, 60)

                NavigationLink("", destination: RunSummaryView(playedSongs: playedSongs), isActive: $navigateToSummary)
                    .hidden()
            }
            .padding()
            .background(Color.white)
            .onAppear { loadPlaylist() }
            .onDisappear { runManager.stopRun() }
            .onChange(of: spotifyManager.currentSong) { newSong in
                let trimmedNewSong = newSong.trimmingCharacters(in: .whitespacesAndNewlines)
                if lastKnownSong != trimmedNewSong {
                    lastKnownSong = trimmedNewSong

                    // Track locally
                    playedSongs.append((song: trimmedNewSong, pace: runManager.currentPace))

                    // Firebase Logging
                    FirestoreHelper.logSongEvent(
                        userId: spotifyManager.userId,
                        songId: spotifyManager.currentTrackId,
                        paceBefore: runManager.currentPace,
                        paceDuring: runManager.currentPace,
                        runMode: runMode.rawValue
                    )

                    FirestoreHelper.updateSongStats(
                        userId: spotifyManager.userId,
                        songId: spotifyManager.currentTrackId,
                        newPace: runManager.currentPace,
                        metadata: [
                            "title": spotifyManager.currentTitle,
                            "artist": spotifyManager.currentArtist,
                            "bpm": spotifyManager.currentBPM ?? 0,
                            "genre": spotifyManager.currentGenre ?? "Unknown"
                        ]
                    )

                    if let target = targetPace {
                        spotifyManager.handleDynamicQueueing(currentPace: runManager.currentPace, targetPace: target)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Helper UI
    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.9))

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(UIColor.darkGray))
        }
    }

    private var modeDisplay: String {
        switch runMode {
        case .desiredPace:
            return "🎯 \(String(format: "%.2f", targetPace ?? 0))"
        case .fastRun:
            return "⚡ Fast"
        case .steadyRun:
            return "🌊 Steady"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDistance(_ distance: Double) -> String {
        return String(format: "%.2f km", distance / 1000)
    }

    private func logRunSummary() {
        let runId = UUID().uuidString
        let songs = playedSongs.map { song -> (String, Double, Double) in
            let trackId = spotifyManager.songIdCache[song.song] ?? "unknown"
            return (trackId, song.pace, song.pace)
        }

        FirestoreHelper.logRunSummary(
            userId: spotifyManager.userId,
            runId: runId,
            mode: runMode.rawValue,
            startTime: runManager.startTime ?? Date(),
            duration: runManager.elapsedTime,
            distance: runManager.distance,
            songs: songs
        )
    }

    private func loadPlaylist() {
        spotifyManager.fetchCurrentPlaybackInfo { detectedPlaylistId in
            guard let playlistId = detectedPlaylistId else {
                print("❗️ Could not detect playlist.")
                return
            }
            spotifyManager.fetchAllTracksAndFeatures(for: playlistId) {
                isLoading = false
                runManager.startRun()
                spotifyManager.startPollingPlayback()

                if let target = targetPace {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        spotifyManager.handleDynamicQueueing(currentPace: runManager.currentPace, targetPace: target)
                    }
                }
            }
        }
    }
}

