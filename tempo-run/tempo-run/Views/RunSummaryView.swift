import SwiftUI

struct RunSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let playedSongs: [(song: String, pace: Double)]  // passed from LiveRunView

    // Computed stats
    var averagePace: Double {
        let total = playedSongs.map(\.pace).reduce(0, +)
        return playedSongs.isEmpty ? 0 : total / Double(playedSongs.count)
    }

    var highlightSong: (song: String, pace: Double)? {
        playedSongs.sorted(by: { $0.pace < $1.pace }).first
    }

    var totalTime: TimeInterval {
        Double(playedSongs.count) * 180  // estimate ~3min per song
    }

    var totalDistance: Double {
        averagePace > 0 ? (totalTime / 60) / averagePace : 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Text("🏁 Run Summary")
                    .font(.title)
                    .fontWeight(.bold)

                // 📊 Summary Stats
                VStack(spacing: 12) {
                    summaryItem(label: "Total Time", value: formatTime(totalTime))
                    summaryItem(label: "Distance", value: String(format: "%.2f km", totalDistance))
                    summaryItem(label: "Avg Pace", value: String(format: "%.2f min/km", averagePace))
                }

                Divider()

                // 🏅 Highlight Song
                if let highlight = highlightSong {
                    VStack(spacing: 6) {
                        Text("Highlight Song 🎧")
                            .font(.headline)
                        Text(highlight.song)
                            .font(.subheadline)
                        Text(String(format: "%.2f min/km", highlight.pace))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Divider()

                // 🎵 Song List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Songs Played")
                        .font(.headline)

                    ForEach(playedSongs.indices, id: \.self) { i in
                        let entry = playedSongs[i]
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.song)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(String(format: "%.2f min/km", entry.pace))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // ✅ Done Button
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(16)
                .padding(.horizontal, 60)
            }
            .padding()
            .navigationBarBackButtonHidden(true)
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 40)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

