# 🔐 OAuth 2.0 + PKCE for iOS: A Real-World Security Guide

**For iOS developers building secure authentication without ending up in Spotify's shoes.**

This guide tells the story of how authentication works in practice, using Spotify as our running example. We'll focus on the *why* and *when*, with code references for the curious.

---

## 📖 The Story: Why We Need OAuth

### The Problem (2010s)

Your app needs user data from another service. Spotify, for example, wants access to your Spotify library.

**Old way (❌ Dangerous):**
```
1. You ask user: "Give me your Spotify password"
2. User types password into your app
3. Your app stores password in its database
4. Your app uses password to access Spotify
5. If your app gets hacked → attacker has user's Spotify password
6. User can't revoke access without changing their password
```

**New way (✅ OAuth):**
```
1. Your app redirects to Spotify
2. User logs into Spotify directly (you never see the password)
3. User clicks "Allow" to give your app permission
4. Spotify gives your app a token (like a temporary, limited credential)
5. Your app uses token to access Spotify
6. If your app gets hacked → attacker has a token, not the password
7. User can revoke access anytime without changing password
```

That's OAuth. Your app never touches the password. Ever.

---

## 🚀 The Real-World Flow: Spotify Login

Let's walk through exactly what happens when a user taps "Login with Spotify" in your app.

### Step 1: User Taps "Login with Spotify"

Your app generates a cryptographic puzzle called **PKCE** (more on this later).

**Why?** Because mobile apps are on user-controlled devices. If someone intercepts the OAuth flow, they could steal the authorization code. PKCE makes that code useless without the puzzle piece.

```swift
// Generate: verifier (128 random chars) + challenge (hash of verifier)
// Save verifier locally (you'll need it in 5 minutes)
// Send challenge to Spotify (Spotify stores it)
// 
// Implementation: See Authentication/Services/PKCEGenerator.swift
```

### Step 2: Spotify Login Page Opens

Your app opens a secure browser session (not Safari, not a WebView—a special isolated browser provided by iOS).

```swift
// Use ASWebAuthenticationSession (Apple's secure browser)
// NOT: UIApplication.open() or WebView
// Why? iOS prevents app impersonation and URL scheme hijacking
//
// Implementation: See Authentication/Services/OAuthService.swift
```

User sees Spotify's real login page. They type their password directly into Spotify—your app never sees it.

### Step 3: Spotify Redirects Back to Your App

After user clicks "Allow," Spotify redirects to:
```
myapp://callback?code=xyz123&state=abc
```

Your app catches this redirect via the custom URL scheme `myapp://`.

### Step 4: Exchange Code for Tokens (The Critical Moment)

Your app sends the authorization `code` back to Spotify **along with the verifier**:

```
POST https://accounts.spotify.com/api/token

code: xyz123
code_verifier: [the 128-char string you generated earlier]
client_id: [your app's ID]
```

Spotify validates:
```
Does SHA256(verifier) match the challenge I received earlier?
YES → Issue tokens
NO → Reject (code is worthless without verifier)
```

**Why this matters:** If an attacker intercepted the code, they'd need the verifier to exchange it. They don't have it. The code is useless.

### Step 5: You Get Tokens

Spotify responds:
```json
{
  "access_token": "long_string_here",
  "refresh_token": "another_string",
  "expires_in": 3600
}
```

**Access token:** Use this to call Spotify's API for 1 hour.
**Refresh token:** Use this later to get a new access token (lasts months or years).

### Step 6: Store Tokens (Securely)

```swift
// NEVER: UserDefaults, files, or memory
// ALWAYS: Keychain (encrypted by device)
//
// Implementation: See Authentication/Storage/SecureTokenStore.swift
```

Keychain is a secure database. It's encrypted. Each app is sandboxed. Only your app can read your app's tokens.

### Step 7: Use the Token

```
GET https://api.spotify.com/v1/me
Header: Authorization: Bearer [access_token]
```

You get user data. You never saw their password.

---

## 🔑 The Three Key Concepts

### 1. PKCE: The Puzzle That Saves You

**Analogy:** You want to give someone your house keys. But the postman might intercept the package.

**PKCE solution:**
- You create a jigsaw puzzle (the verifier—128 random characters)
- You send the picture of the completed puzzle (the challenge—SHA256 hash)
- The postman sees the picture, but without the actual puzzle pieces, they can't reconstruct it
- When you verify, you send both: the picture AND the puzzle pieces
- If they don't match perfectly, the key exchange fails

**In code:**
```swift
// Generate: verifier (random), challenge (hash of verifier)
// Send challenge to OAuth provider initially
// Send verifier when exchanging code for token
// Provider validates: SHA256(verifier) == challenge
//
// Full implementation: Authentication/Services/PKCEGenerator.swift
```

**Real consequence:** If Spotify's server gets hacked and attackers get your authorization code, they can't use it. They'd need the verifier, which was never sent to Spotify—only the hash.

---

### 2. Keychain: Fort Knox for Your Tokens

**Analogy:** Tokens are like credit cards. Would you leave a credit card in a text file? No.

**Keychain:**
- Encrypted by device passcode / Face ID / Touch ID
- Each app can only access its own items
- Survives app uninstall and reinstall
- Backed by Secure Enclave on modern phones

**In code:**
```swift
// Save:
// tokenStore.saveTokens(accessToken: "...", refreshToken: "...")

// Read:
// let token = tokenStore.getAccessToken()

// Implementation: See Authentication/Storage/SecureTokenStore.swift
```

**Real consequence:** Even if your app gets hacked, tokens stay encrypted. If a device gets stolen, tokens are locked behind Face ID.

---

### 3. ASWebAuthenticationSession: Apple's Safe Browser

**Why not just open Safari or a WebView?**

| Approach | Problem |
|----------|---------|
| `UIApplication.open()` | Insecure. Another app could register the same URL scheme and intercept your OAuth callback. |
| `WKWebView` | Your app controls it. User might think they're logging into your fake Spotify page. |
| `ASWebAuthenticationSession` | Apple controls it. Isolated. Secure. User's browsing history is separate. |

**In code:**
```swift
// ✅ Correct:
let session = ASWebAuthenticationSession(
    url: spotifyAuthURL,
    callbackURLScheme: "myapp"
) { callbackURL, error in
    // Handle callback
}
session.presentationContextProvider = self
session.start()

// Full implementation: See Authentication/Services/OAuthService.swift

// ❌ Wrong:
UIApplication.shared.open(spotifyAuthURL) // Anyone can intercept!
```

---

## 📱 How It Actually Works: Timeline

**User perspective:**
```
1. Taps "Login with Spotify"
2. Browser opens (Spotify's secure login page)
3. Types Spotify password
4. Clicks "Allow"
5. App is logged in
6. Done
```

**Your app's perspective (behind the scenes):**
```
Before user taps:
  → Generate PKCE puzzle (verifier + challenge)
  → Save verifier in Keychain
  → Build Spotify OAuth URL with challenge

After user clicks "Allow":
  → Catch redirect with authorization code
  → Send code + verifier to Spotify
  → Spotify validates: SHA256(verifier) == stored_challenge? YES!
  → Receive access_token + refresh_token
  → Save tokens in Keychain
  → Delete verifier (no longer needed)

When app wants to fetch user data:
  → Read access_token from Keychain
  → Make API call with Bearer token
  → Receive user data (no password involved)

Later, when access_token expires (1 hour later):
  → Read refresh_token from Keychain
  → Send refresh_token to Spotify
  → Receive new access_token
  → Save new token, discard old one
  → Continue working seamlessly
```

**See implementation flow:** `Authentication/Services/OAuthService.swift` + `Authentication/Services/TokenService.swift`

---

## 🎵 Real Example: Spotify Integration

### What Spotify Requires

1. **Register at:** developer.spotify.com
2. **Get:** Client ID (Client Secret stays server-side only)
3. **Set:** Redirect URI to `myapp://callback`
4. **Endpoints:**
   - Auth: `https://accounts.spotify.com/authorize`
   - Token: `https://accounts.spotify.com/api/token`
   - API: `https://api.spotify.com/v1/...`

### Your App's Implementation (Conceptually)

```swift
// 1. Generate PKCE
let (verifier, challenge) = generatePKCE()
save(verifier) // Save for later

// 2. Build Spotify URL
var spotifyAuthURL = URLComponents(string: "https://accounts.spotify.com/authorize")
spotifyAuthURL.queryItems = [
    .init(name: "client_id", value: "your_client_id"),
    .init(name: "response_type", value: "code"),
    .init(name: "redirect_uri", value: "myapp://callback"),
    .init(name: "code_challenge", value: challenge),
    .init(name: "code_challenge_method", value: "S256")
]

// 3. Open browser
let session = ASWebAuthenticationSession(url: spotifyAuthURL.url!, callbackURLScheme: "myapp") { url, error in
    guard let code = extractCode(from: url) else { return }
    
    // 4. Exchange code for token
    let verifier = retrieve(verifier)
    exchangeCodeForToken(code: code, verifier: verifier)
}
session.start()

// See full flow: Authentication/Services/OAuthService.swift
// PKCE generation: Authentication/Services/PKCEGenerator.swift
// Token storage: Authentication/Storage/SecureTokenStore.swift
```

**Key point:** This flow is identical for Google, GitHub, Auth0, or any OAuth provider. Only the URLs and endpoints change.

---

## ⚠️ Common Mistakes (And Why They Bite You)

### Mistake 1: Storing Tokens in UserDefaults

```swift
// ❌ NEVER:
UserDefaults.standard.set(token, forKey: "access_token")

// Why it's bad:
// - Plaintext, synced to iCloud
// - Backed up to computer
// - If device is stolen, attacker can read it
// - If your code is decompiled, token is visible

// ✅ DO:
// Use SecureTokenStore (see Authentication/Storage/SecureTokenStore.swift)
```

### Mistake 2: Not Using PKCE

```swift
// ❌ If you do this:
POST https://spotify.com/token
code: abc123
client_id: ...
// (no code_verifier)

// An attacker who intercepts the code can exchange it
// They know your client_id (it's in your app binary)

// ✅ DO:
POST https://spotify.com/token
code: abc123
code_verifier: [128-char string you generated]
client_id: ...
// Now they need both code AND verifier
// Even intercepting code is useless

// Implementation: Authentication/Services/PKCEGenerator.swift
```

### Mistake 3: Using WebView Instead of ASWebAuthenticationSession

```swift
// ❌ NEVER:
let webView = WKWebView()
webView.load(URLRequest(url: spotifyAuthURL))

// Problems:
// - Your app controls it (looks like a phishing page)
// - Shared cookies with other sessions
// - User might type password into fake page

// ✅ DO:
// Use ASWebAuthenticationSession
// Implementation: Authentication/Services/OAuthService.swift
```

### Mistake 4: Taking Too Long to Exchange Code

```swift
// ❌ If you do this:
let code = extractCode(from: callbackURL)
// User closes app
// 2 hours later...
exchangeCodeForToken(code: code) // Too late!

// Why: Most providers expire codes in 10 minutes

// ✅ DO:
let code = extractCode(from: callbackURL)
exchangeCodeForToken(code: code) // Immediately

// Implementation: Authentication/Services/OAuthService.swift
```

---

## 🔄 Token Refresh: Staying Logged In

After 1 hour, your access token expires. What now?

**Bad approach:**
```
User taps "Login" again
→ Spotify login page opens
→ User taps "Allow" again
→ Repeat every hour (terrible UX)
```

**Good approach (using refresh token):**
```
Access token expires
→ App detects 401 error
→ App sends refresh_token to Spotify
→ Spotify gives new access_token (valid for 1 more hour)
→ App continues seamlessly
→ User never notices
```

**In code:**
```swift
// When API call fails with 401:
if httpResponse.statusCode == 401 {
    let newAccessToken = refreshAccessToken()
    // Retry original request with new token
}

// Implementation: See Authentication/Services/TokenService.swift
// or the refreshAccessToken() method in OAuthService.swift
```

**Key point:** Users stay logged in for days/weeks/months without re-authenticating.

---

## 🎯 Production Checklist

Before shipping your app:

- [ ] Using PKCE (verifier + challenge)? → See `PKCEGenerator.swift`
- [ ] Storing tokens in Keychain (not UserDefaults)? → See `SecureTokenStore.swift`
- [ ] Using ASWebAuthenticationSession (not WebView)? → See `OAuthService.swift`
- [ ] Redirect URI registered at OAuth provider?
- [ ] Custom URL scheme in Info.plist? → Check project settings
- [ ] Handling 401 → auto-refresh → retry? → See `TokenService.swift`
- [ ] Tokens never printed in logs?
- [ ] Test logout (clear Keychain)? → See `SecureTokenStore.clearTokens()`

---

## 🚨 When Things Go Wrong

### "WebAuthenticationSession error 1"
Your redirect URI doesn't match. In your OAuth dashboard, make sure it's exactly `myapp://callback`. In your code, make sure it's exactly `myapp`.

**Fix:** See `OAuthService.swift` - check the `callbackURLScheme` parameter

### "Invalid code_verifier"
You generated a new verifier instead of using the saved one. Save it the first time, retrieve it later.

**Fix:** See `PKCEGenerator.swift` and how it's used in `OAuthService.swift`

### "Authorization code has expired"
You waited too long before exchanging. Don't delay—exchange immediately after callback.

**Fix:** In `OAuthService.swift`, exchange code immediately in the callback closure

### "401 Unauthorized" on API call
Your access token expired. Use the refresh token to get a new one.

**Fix:** See `TokenService.swift` - implement automatic token refresh on 401

---

## 🏗️ Architecture: How It Fits Together

```
Views/
  └─ LoginView.swift
      ↓ (user taps "Login")
ViewModels/
  └─ AuthViewModel.swift
      ↓
Services/
  ├─ OAuthService.swift (main flow)
  ├─ TokenService.swift (refresh logic)
  └─ PKCEGenerator.swift (PKCE utilities)
      ↓
Storage/
  └─ SecureTokenStore.swift (Keychain wrapper)

Models/
  ├─ TokenResponse.swift
  ├─ UserProfile.swift
  └─ OAuthError.swift

Later, API calls:
  ↓
APIService/ (or Network/)
  ├─ Read token from SecureTokenStore
  ├─ Make API call with Bearer token
  ├─ If 401: Call TokenService.refreshAccessToken()
  └─ Retry request
```

---

## 🔐 Security Deep Dive (Optional)

### Why PKCE Matters

**Scenario:** Alice's device is on public WiFi. An attacker (Eve) runs a packet sniffer.

Without PKCE:
```
1. Alice's app generates authorization URL
2. Eve intercepts: https://spotify.com/authorize?client_id=...
3. User logs in, Spotify redirects: myapp://callback?code=ABC123
4. Eve intercepts: code=ABC123
5. Eve crafts: POST /token with code=ABC123&client_id=... (from URL)
6. Eve gets access_token
7. Eve accesses Alice's Spotify account
```

With PKCE:
```
1. Alice's app generates verifier (128 chars) + challenge (SHA256 hash)
2. Alice's app sends challenge to Spotify (Eve sees this, but it's just a hash)
3. Eve intercepts code=ABC123
4. Eve tries: POST /token with code=ABC123&client_id=...
5. Spotify asks: "Where's the code_verifier that matches this challenge?"
6. Eve doesn't have it (it was never sent to Spotify, only the hash)
7. Spotify rejects
```

**Key insight:** PKCE protects against authorization code interception on public networks.

**See implementation:** `Authentication/Services/PKCEGenerator.swift`

---

## 📚 What We Haven't Covered (But Should Know Exist)

- **State parameter:** Prevents CSRF attacks (sent with code challenge, returned with code)
- **Scope limits:** Your app asks for specific permissions ("read playlists" not "full access")
- **Token expiration:** Different providers use different lifetimes (1 hour, 1 day, 1 year)
- **Biometric auth:** LAContext to require Face ID before accessing tokens
- **Token rotation:** Some providers give new refresh tokens each time
- **Logout:** Delete tokens from Keychain, invalidate at OAuth provider

---

## 🎓 The Mental Model

Think of OAuth like a restaurant valet system:

```
You (the app) wants to valet your car (access user data)

Old way:
  You: "Here's my car keys" (password)
  Valet: "Thanks, I'll park it"
  Problem: Valet has your house keys too, you can't revoke just car access

OAuth way:
  Valet company: "Here's a temporary parking ticket" (OAuth code)
  You: "I'm trading this ticket + my fingerprint (PKCE verifier) for a parking pass"
  Company: "Fingerprint matches ticket? Yes! Here's your pass (access token)"
  You: "Now I can pick up my car with this pass"
  
  Later: Pass expires
  You: "I have this old pass, can I get a new one?" (refresh token)
  Company: "Yes, here's a new pass"
  
  Anytime: "Revoke my parking pass"
  Company: "Done"
  
Now the valet only has a temporary parking pass. No house keys. You control everything.
```

---

## ✨ Final Thought

OAuth isn't magic. It's:
1. **User authenticates directly** with the service that knows their password
2. **Service issues a token** (temporary, limited credential)
3. **Your app uses the token** (never sees password)
4. **User can revoke anytime** (without changing password)

That's it. Everything else (PKCE, Keychain, token refresh) is just securing the process.

---

## 📂 Repository Structure Reference

```
rejaparad/temp-run/
├── Authentication/
│   ├── Services/
│   │   ├── OAuthService.swift          ← Main OAuth flow + token exchange
│   │   ├── TokenService.swift          ← Token refresh + validation
│   │   ├── PKCEGenerator.swift         ← PKCE verifier + challenge generation
│   │   └── OAuthConfig.swift           ← Configuration (endpoints, client_id)
│   │
│   ├── Storage/
│   │   └── SecureTokenStore.swift      ← Keychain wrapper for token storage
│   │
│   ├── Models/
│   │   ├── TokenResponse.swift         ← API response models
│   │   ├── UserProfile.swift           ← User data model
│   │   └── OAuthError.swift            ← Error types
│   │
│   └── ViewModels/
│       └── AuthViewModel.swift         ← SwiftUI integration
│
├── Views/
│   ├── LoginView.swift
│   ├── ProfileView.swift
│   └── ProtectedView.swift
│
└── docs/
    └── oauth-real-world.md            ← This guide
```

**Quick Links by Task:**

| Task | File |
|------|------|
| Implement PKCE | `Authentication/Services/PKCEGenerator.swift` |
| Store tokens securely | `Authentication/Storage/SecureTokenStore.swift` |
| Handle OAuth flow | `Authentication/Services/OAuthService.swift` |
| Refresh expired tokens | `Authentication/Services/TokenService.swift` |
| SwiftUI integration | `Authentication/ViewModels/AuthViewModel.swift` |
| Configure endpoints | `Authentication/Services/OAuthConfig.swift` |
| Handle errors | `Authentication/Models/OAuthError.swift` |

---

**Last Updated:** November 2025  
**For specific provider setup:** See OAuth Provider Integration Guide  
**For code details:** Check files listed above in your repository structure
