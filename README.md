# Tempo Run – Technical Overview 🏃‍♀️🎶

Tempo Run is an AI-powered iOS app that dynamically adjusts your Spotify playlist queue based on your real-time pace to help you run smarter and stay in the zone.
![tempo-run-screens](https://github.com/user-attachments/assets/7b48ae25-be9a-4081-88d9-75422c133850)

---

## 📲 User Flow & Spotify Integration

1. **Spotify Authentication**
   - Users authenticate via OAuth 2.0 using the Spotify iOS SDK.
   - A custom redirect URI (`temperun://callback`) completes the auth loop.

2. **Establishing Connection**
   - Once authenticated, the app connects to the Spotify App Remote SDK to fetch live playback and control queue.

3. **Fetching Current Playlist**
   - The currently playing playlist is identified.
   - All songs from this playlist are retrieved via the Spotify Web API.

4. **Enriching Song Metadata**
   - Each song is enriched with:
     - BPM and other audio features (via Spotify API)
     - If unavailable, fallback methods:
       - **Groq AI** model generates estimated features.
       - **SongBPM.com** is scraped as a last resort.

---

## 🧠 Machine Learning Model (Google Cloud Hosted)

- A custom ML model is hosted on **Google Cloud Run**.
- Trained on each user's **run history** + **song metadata**.
- Predicts the best next song to queue based on:
  - Target pace
  - Current pace
  - Past performance with similar songs

**With every run, the model retrains**, becoming more personalized and accurate over time.

---

## 🔥 Real-Time Queueing

Once the user starts a run:

1. The app monitors pace in real-time.
2. After each song, the pace is logged.
3. The backend fetches the best next track using the ML model.
4. That track is added to the Spotify queue instantly.

---

## ☁️ Firebase Integration

- **Firestore** stores:
  - Song performance logs
  - Run summaries (distance, pace, time)
  - Metadata enrichment
- **Functions** may be used to trigger retraining after each run.

---

## 🧪 Tech Stack

### Frontend
- SwiftUI (iOS)
- Spotify iOS SDK (App Remote + Auth)

### Backend
- FastAPI + Python
- Hosted on Google Cloud Run

### ML & Metadata
- Custom ML model using scikit-learn
- Groq API + SongBPM scraping
- Firebase Firestore for structured data storage

---

## 🚀 Setup

Clone the repository:
```bash
git clone https://github.com/sanyachaw1a/tempo-run.git
```

Open in Xcode and fill in your credentials in `Env.swift`:
```swift
struct Env {
    static let spotifyClientId = "<YOUR_SPOTIFY_CLIENT_ID>"
    static let spotifyClientSecret = "<YOUR_SPOTIFY_CLIENT_SECRET>"
    static let spotifyRedirectUri = "<YOUR_SPOTIFY_REDIRECT_URI>"
    static let groqApiKey = "<YOUR_GROQ_API_KEY>"
}
```

Build and run on a real iOS device (location tracking requires hardware).

---

For questions or access, contact: **sanyachawla75@gmail.com**
