import FirebaseFirestore

struct FirestoreHelper {
    static let db = Firestore.firestore()

    // 🔹 Log song event
    static func logSongEvent(userId: String, songId: String, paceBefore: Double, paceDuring: Double, runMode: String) {
        let data: [String: Any] = [
            "timestamp": Timestamp(date: Date()),
            "songId": songId,
            "paceBefore": paceBefore,
            "paceDuring": paceDuring,
            "runMode": runMode
        ]
        db.collection("users").document(userId)
            .collection("songEvents")
            .addDocument(data: data)
    }

    // 🔹 Log full run summary
    static func logRunSummary(userId: String, runId: String, mode: String, startTime: Date, duration: TimeInterval, distance: Double, songs: [(String, Double, Double)]) {
        let summary: [String: Any] = [
            "runId": runId,
            "mode": mode,
            "startTime": Timestamp(date: startTime),
            "duration": duration,
            "distance": distance,
            "songsPlayed": songs.map { (id, before, during) in
                [
                    "songId": id,
                    "paceBefore": before,
                    "paceDuring": during
                ]
            }
        ]
        db.collection("users").document(userId)
            .collection("runSummaries")
            .document(runId)
            .setData(summary)
    }

    // 🔹 Update song pace history
    static func updateSongStats(userId: String, songId: String, newPace: Double, metadata: [String: Any]) {
        let songRef = db.collection("users").document(userId).collection("songs").document(songId)

        songRef.getDocument { snapshot, error in
            var paces: [Double] = []

            if let data = snapshot?.data(), let existing = data["paces"] as? [Double] {
                paces = existing
            }

            paces.append(newPace)
            let avg = paces.reduce(0, +) / Double(paces.count)

            var update = metadata
            update["paces"] = paces
            update["average_pace"] = avg

            songRef.setData(update, merge: true)
        }
    }
}

