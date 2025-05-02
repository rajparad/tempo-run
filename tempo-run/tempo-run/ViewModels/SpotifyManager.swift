import Foundation
import Combine
import AuthenticationServices
import UIKit

class SpotifyManager: NSObject, ObservableObject {
    @Published var accessToken: String? = nil
    @Published var isLoggedIn: Bool = false
    @Published var username: String = "Loading..."
    @Published var playlists: [Playlist] = []
    @Published var selectedPlaylist: Playlist? = nil
    @Published var currentSong: String = ""
    @Published var playlistTracks: [SpotifyTrack] = []
    @Published var queuedSongs: [SpotifyTrack] = []
    
    @Published var userId: String = "demo-user"  // Replace after login or anonymous auth
    @Published var currentTrackId: String = ""
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentBPM: Double? = nil
    @Published var currentGenre: String? = nil

    var songIdCache: [String: String] = [:]  // Optional: to cache song ID lookups

    
    private var playbackTimer: Timer?
    
    struct Playlist: Identifiable {
        let id: String
        let name: String
    }
    
    struct SpotifyTrack: Identifiable, Codable {
        let id: String
        let name: String
        let artist: String
        var bpm: Double?
    }
    
    private let clientId = Env.spotifyClientId
    private let clientSecret = Env.spotifyClientSecret
    private let redirectUri = Env.spotifyRedirectUri
    private let groqApiKey = Env.groqApiKey
    
    // MARK: - Login
    func login() {
        let scopes = "user-read-currently-playing user-read-playback-state user-modify-playback-state"
        guard let authURL = URL(string: "https://accounts.spotify.com/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)") else {
            print("Invalid auth URL")
            return
        }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "sportify") { callbackURL, error in
            guard let callbackURL = callbackURL,
                  let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                  let code = queryItems.first(where: { $0.name == "code" })?.value else {
                print("Failed to get auth code")
                return
            }
            self.exchangeCodeForToken(code: code)
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    func fetchSpotifyUserId() {
        guard let token = accessToken else { return }

        let url = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String else {
                print("❌ Failed to get Spotify user ID")
                return
            }

            DispatchQueue.main.async {
                self.userId = id
                print("✅ Set userId from Spotify: \(id)")
            }
        }.resume()
    }

    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectUri)&client_id=\(clientId)&client_secret=\(clientSecret)".data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.isLoggedIn = true
                    self.startPollingPlayback()
                    self.fetchSpotifyUserId()
                }
            }
        }.resume()
    }
    
    // MARK: - Playback Polling
    func startPollingPlayback() {
        stopPollingPlayback()
        DispatchQueue.main.async {
            self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self.fetchCurrentPlaybackInfo()
            }
            RunLoop.main.add(self.playbackTimer!, forMode: .common)
        }
    }
    
    func stopPollingPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func fetchCurrentPlaybackInfo(completion: ((String?) -> Void)? = nil) {
        guard let token = accessToken else {
            completion?(nil)
            return
        }
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                completion?(nil)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let item = json["item"] as? [String: Any],
               let name = item["name"] as? String,
               let artists = item["artists"] as? [[String: Any]],
               let artistName = artists.first?["name"] as? String {
                
                DispatchQueue.main.async {
                    self.currentTitle = name
                    self.currentArtist = artistName
                    self.currentTrackId = item["id"] as? String ?? ""
                    self.currentBPM = self.playlistTracks.first(where: { $0.name == name && $0.artist == artistName })?.bpm ?? 0
                    self.currentGenre = nil  // you can enrich this later if you pull genre
                    self.currentSong = "\(name) - \(artistName)"
                    self.songIdCache[self.currentSong] = self.currentTrackId

                    print("🎵 Now Playing: \(self.currentSong)")
                }
                
                if let context = json["context"] as? [String: Any],
                   let uri = context["uri"] as? String,
                   uri.contains("playlist") {
                    let playlistId = uri.replacingOccurrences(of: "spotify:playlist:", with: "")
                    completion?(playlistId)
                } else {
                    completion?(nil)
                }
            } else {
                completion?(nil)
            }
        }.resume()
    }
    
    
    // MARK: - Fetch playlist tracks + features
    func fetchAllTracksAndFeatures(for playlistId: String, completion: @escaping () -> Void) {
        guard let token = accessToken else { return }
        let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?limit=100")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                var tracks: [SpotifyTrack] = []
                let group = DispatchGroup()
                
                for item in items {
                    if let track = item["track"] as? [String: Any],
                       let id = track["id"] as? String,
                       let name = track["name"] as? String,
                       let artists = track["artists"] as? [[String: Any]],
                       let artistName = artists.first?["name"] as? String {
                        
                        var newTrack = SpotifyTrack(id: id, name: name, artist: artistName)
                        
                        group.enter()
                        self.fetchBPMForTrack(artist: artistName, title: name) { bpm in
                            newTrack.bpm = bpm
                            tracks.append(newTrack)
                            group.leave()
                        }                    }
                }
                
                group.notify(queue: .main) {
                    self.playlistTracks = tracks
                    for track in tracks {
                        print("🎶 \(track.name) by \(track.artist) - BPM: \(track.bpm ?? 0)")
                    }
                    completion()
                }
            }
        }.resume()
    }
    
    
    
    func fetchGroqFeaturesDirectly(for songTitle: String, artist: String, retriesLeft: Int = 3, completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            completion(nil)
            return
        }
        
        let prompt = """
        You are an expert music analyst. Given the following song:
        - Song Title: "\(songTitle)"
        - Artist: "\(artist)"
        
        Please respond ONLY with a JSON object:
        { "bpm": number }
        
        If unsure, guess a realistic BPM between 90 and 140.
        No explanation. Only output pure JSON.
        """
        
        let body: [String: Any] = [
            "model": "llama3-8b-8192",
            "messages": [["role": "user", "content": prompt]]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(groqApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                if retriesLeft > 0 {
                    print("🔄 Retrying fetch for \(songTitle) (\(retriesLeft-1) retries left)... [no data]")
                    self.fetchGroqFeaturesDirectly(for: songTitle, artist: artist, retriesLeft: retriesLeft-1, completion: completion)
                } else {
                    print("⚠️ Failed to fetch bpm for \(songTitle) after retries.")
                    completion(nil)
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    if let start = content.firstIndex(of: "{"),
                       let end = content.lastIndex(of: "}") {
                        let jsonString = String(content[start...end])
                        if let jsonData = jsonString.data(using: .utf8),
                           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let bpm = parsed["bpm"] as? Double, bpm > 0 {
                            completion(parsed)
                            return
                        }
                    }
                }
                if retriesLeft > 0 {
                    print("🔄 Retrying fetch for \(songTitle) (\(retriesLeft-1) retries left)... [bad bpm]")
                    self.fetchGroqFeaturesDirectly(for: songTitle, artist: artist, retriesLeft: retriesLeft-1, completion: completion)
                } else {
                    print("⚠️ Failed to fetch bpm for \(songTitle) after retries.")
                    completion(nil)
                }
            } catch {
                print("❌ JSON parsing error for \(songTitle): \(error)")
                if retriesLeft > 0 {
                    self.fetchGroqFeaturesDirectly(for: songTitle, artist: artist, retriesLeft: retriesLeft-1, completion: completion)
                } else {
                    print("⚠️ Failed to fetch bpm for \(songTitle) after retries.")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func fetchBPMFromSongBPMDirect(artist: String, title: String, completion: @escaping (Double?) -> Void) {
        func slugify(_ text: String) -> String {
            var cleaned = text.lowercased()
                .replacingOccurrences(of: "&", with: "and")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "’", with: "") // fancy apostrophes
                .replacingOccurrences(of: "–", with: "-") // fancy dash
                .replacingOccurrences(of: "—", with: "-") // long dash
            
            // Remove (feat. ...) and (with ...) and any parentheses
            cleaned = cleaned.replacingOccurrences(of: "\\(feat\\..*?\\)", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "\\(with.*?\\)", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "[()]", with: "", options: .regularExpression)
            
            cleaned = cleaned
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression) // remove special chars
            
            return cleaned
        }
        
        let artistSlug = slugify(artist)
        let titleSlug = slugify(title)
        let urlString = "https://songbpm.com/@\(artistSlug)/\(titleSlug)"
        
        print("🔎 Fetching BPM from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let bpmRange = html.range(of: #"[0-9]{2,3} BPM"#, options: .regularExpression) {
                let bpmText = String(html[bpmRange])
                let bpmNumber = bpmText.replacingOccurrences(of: " BPM", with: "")
                if let bpm = Double(bpmNumber) {
                    DispatchQueue.main.async {
                        print("🎯 Scraped BPM for \(title): \(bpm)")
                        completion(bpm)
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                print("⚠️ BPM not found for \(title)")
                completion(nil)
            }
        }.resume()
    }
    
    func fetchBPMForTrack(artist: String, title: String, completion: @escaping (Double?) -> Void) {
        fetchBPMFromSongBPMDirect(artist: artist, title: title) { bpm in
            if let bpm = bpm {
                completion(bpm)
            } else {
                print("⚠️ Falling back to Groq for \(title)")
                self.fetchGroqFeaturesDirectly(for: title, artist: artist) { features in
                    if let bpm = features?["bpm"] as? Double {
                        completion(bpm)
                    } else {
                        print("❌ Failed to fetch BPM from both SongBPM and Groq for \(title)")
                        completion(nil)
                    }
                }
            }
        }
    }
    
    private func queueTrack(trackId: String) {
        guard let token = accessToken else { return }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/queue?uri=spotify:track:\(trackId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ Failed to queue song: \(error)")
            } else {
                print("🎵 Successfully queued!")
            }
        }.resume()
    }
    
    func handleDynamicQueueing(currentPace: Double, targetPace: Double) {
        guard !playlistTracks.isEmpty else {
            print("❗️ No playlist tracks loaded for queueing")
            return
        }

        let currentSongName = currentSong.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTrack = playlistTracks.first { track in
            let fullName = "\(track.name) - \(track.artist)"
            return fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentSongName.lowercased()
        }

        let currentBPM = currentTrack?.bpm ?? 115.0
        let paceDelta = currentPace - targetPace
        let idealBPM = paceDelta > 0 ? currentBPM + 10 : currentBPM - 10

        print("🎯 Current BPM: \(currentBPM) | Current Pace: \(currentPace) | Target Pace: \(targetPace)")

        // 🔍 Filter unplayed, eligible songs
        let unplayed = playlistTracks.filter { track in
            !queuedSongs.contains(where: { $0.id == track.id }) &&
            track.id != currentTrack?.id
        }

        guard !unplayed.isEmpty else {
            print("❌ No unplayed songs left to queue.")
            return
        }

        // 🧠 Score songs by closeness to ideal BPM
        let scored = unplayed.compactMap { track -> (SpotifyTrack, Double)? in
            guard let bpm = track.bpm else { return nil }
            let score = abs(bpm - idealBPM)
            return (track, score)
        }

        let sorted = scored.sorted { $0.1 < $1.1 }
        let topCandidates = Array(sorted.prefix(5)).map { $0.0 }

        guard let nextTrack = topCandidates.randomElement() else {
            print("❌ Couldn't pick a top track to queue.")
            return
        }

        // 🎵 Queue it!
        queueTrack(trackId: nextTrack.id)
        queuedSongs.append(nextTrack)

        print("✅ Queued: \(nextTrack.name) by \(nextTrack.artist) (BPM: \(nextTrack.bpm ?? 0))")
    }


    
    // Store the last known song
    private var lastKnownSong: String = ""
    
    /// Call this every few seconds to detect playback changes
    func detectPlaybackAndQueueIfNeeded(currentPace: Double, targetPace: Double) {
        guard let token = accessToken else { return }

        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let item = json["item"] as? [String: Any],
               let name = item["name"] as? String,
               let artists = item["artists"] as? [[String: Any]],
               let artistName = artists.first?["name"] as? String {

                let newSong = "\(name) - \(artistName)"

                DispatchQueue.main.async {
                    self.currentSong = newSong

                    // ✨ Fix: compare to lastKnownSong, NOT currentSong
                    if self.lastKnownSong != newSong {
                        print("🎶 Detected new song: \(newSong)")
                        print("🧠 Song changed! Queuing next best song...")
                        
                        self.handleDynamicQueueing(currentPace: currentPace, targetPace: targetPace)
                        
                        self.lastKnownSong = newSong
                    }
                }
            }
        }.resume()
    }
    
}

extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

