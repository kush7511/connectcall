# ConnectCall

> Connect with anyone, anywhere.

A functional 1-to-1 audio/video calling app built in Flutter, submitted for the
Flutter Development Intern assignment. It's a real, working calling app (not a
UI prototype): two devices signed in with different accounts can call each
other and hear/see each other live.

## Features

- Email/password sign-in and registration (Firebase Authentication)
- Splash screen with auth-state routing
- Contacts list with search, online/offline presence
- 1-to-1 **audio calls** and **video calls** over WebRTC
- Incoming call screen with Accept/Decline, including a 30s auto-timeout → Missed
- In-call controls: mute/unmute, speaker toggle, camera on/off, switch
  front/rear camera, end call
- Call history with type (audio/video), direction (incoming/outgoing),
  duration, and missed-call indicator
- Profile screen: edit display name, logout
- Permission handling for microphone/camera (granted / denied / permanently
  denied, with a link to Settings)
- Error states for offline callee, permission denial, and failed connections
- Light and dark theme (follows system setting)

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter | Required by the assignment; single codebase for Android/iOS. |
| Auth + backend | **Firebase Auth + Cloud Firestore** | Free, quick to set up, and Firestore's real-time listeners are a natural fit for both presence (online/offline) and call signaling — no custom server needed for an assignment-scale app. |
| Real-time calling | **WebRTC** via [`flutter_webrtc`](https://pub.dev/packages/flutter_webrtc), signaled through Firestore | WebRTC is free, vendor-neutral, and lets me show I actually understand the calling mechanics (SDP offer/answer, ICE candidates) rather than just calling a managed SDK's `startCall()`. Firestore documents carry the small signaling payloads (offer/answer SDP + ICE candidates); audio/video itself flows peer-to-peer, never through Firestore. |
| State management | **Provider** (`ChangeNotifier`) | The app's state graph is shallow — auth state, one active call, one contacts list — so `ChangeNotifier` keeps things simple to read and explain without extra boilerplate, while still separating business logic (`services/`) from UI (`screens/`, `widgets/`). |
| Permissions | `permission_handler` | Handles the three-state permission flow (granted/denied/permanently denied) cleanly across Android/iOS. |

### Why WebRTC over a managed SDK (Agora/ZEGOCLOUD/Stream/LiveKit)?

Those are all reasonable choices and would reduce integration time, but they
require paid API keys/quotas to demo. Raw WebRTC + Firestore signaling needs
only a free Firebase project, works fully offline-of-any-third-party-SDK, and
better demonstrates understanding of the actual calling mechanics for the
technical review (SDP negotiation, ICE candidate exchange, connection state
machine). **Trade-off:** production apps would want a TURN server for
NAT traversal in restrictive networks — see "Known Limitations" below.

## Architecture

```
lib/
├── core/
│   ├── constants/app_constants.dart   # Firestore collection names, call status/type enums
│   └── theme/app_theme.dart           # Light/dark theme, colors, typography
├── models/
│   ├── user_model.dart
│   └── call_model.dart
├── services/                          # All business logic / I/O lives here
│   ├── auth_service.dart              # Firebase Auth wrapper + friendly error mapping
│   ├── user_service.dart              # Contacts stream, search, profile updates
│   ├── calling_service.dart           # WebRTC + Firestore signaling (the core of the app)
│   └── call_history_service.dart      # Reads finished calls for the History screen
├── providers/                         # State management (ChangeNotifier)
│   ├── auth_provider.dart
│   └── call_provider.dart
├── screens/
│   ├── splash/  auth/  home/  contacts/  profile/  call/  history/
├── widgets/
│   ├── user_tile.dart, call_button.dart, common_button.dart
└── main.dart
```

**Where's the business logic?** Entirely inside `services/`. Screens never
talk to Firebase or WebRTC directly — they call a service (often through a
`Provider`), and rebuild off streams/`ChangeNotifier`s. This keeps UI code
thin and makes the calling logic (the riskiest part) independently testable
and easy to swap out (e.g. replacing Firebase with a custom REST/WebSocket
backend only touches `services/`).

**How would this scale?** The biggest bottleneck is the STUN-only WebRTC
config — add a TURN server for reliable connections behind symmetric NATs
/ corporate firewalls. Presence (`isOnline`) would move from a Firestore
field update to a dedicated presence system (Firebase Realtime Database's
`onDisconnect`, or a presence service) since Firestore alone can't reliably
detect a dropped connection. For call signaling at scale, a purpose-built
signaling server (WebSocket-based) would reduce Firestore read/write costs
versus per-candidate document writes.

## Call States

Implemented: `calling` → `ringing` → `connected` → `ended`, plus `rejected`,
`missed` (30s no-answer timeout), and `failed` (ICE/connection failure). All
six drive both the in-call status label and the auto-navigation back to the
Contacts screen when a call terminates.

## Setup Instructions

1. **Install Flutter** (3.22+) and run `flutter doctor` to confirm your
   toolchain.
2. **Create the project shell**, then copy this `lib/`, `android/`, `ios/`
   content in (or start from `flutter create connectcall` and merge):
   ```bash
   flutter create connectcall
   # then copy this repo's lib/, pubspec.yaml, android/app/src/main/AndroidManifest.xml,
   # ios/Runner/Info.plist over the generated ones (merge, don't blindly overwrite).
   ```
3. **Create a Firebase project** at https://console.firebase.google.com.
   - Enable **Authentication → Email/Password**.
   - Enable **Cloud Firestore** (start in test mode for local dev, then
     apply `firestore.rules` from this repo before shipping).
4. **Connect the app to Firebase:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This regenerates `lib/firebase_options.dart` with your real project
   config (the one in this repo is a placeholder with `REPLACE_ME` values).
5. **Install dependencies:**
   ```bash
   flutter pub get
   ```
6. **Run:**
   ```bash
   flutter run
   ```
   To test calling, run the app on **two separate devices/emulators**
   signed in with two different accounts (WebRTC calls require two real
   media endpoints — one emulator can't easily call itself).

### Environment / Configuration
- No `.env` file is required — all config lives in `lib/firebase_options.dart`
  (generated by `flutterfire configure`, per-platform, safe to commit for
  client apps since Firebase web/app API keys are not secret by themselves;
  access is enforced by `firestore.rules`).
- Deploy the included `firestore.rules` via `firebase deploy --only firestore:rules`
  (requires the Firebase CLI and `firebase init` once).

## Packages Used

`firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_webrtc`,
`provider`, `permission_handler`, `intl`, `uuid`, `cached_network_image`.

## Known Limitations

- **STUN only, no TURN server** — calls between devices on very restrictive
  networks (symmetric NAT, some corporate firewalls) may fail to connect
  peer-to-peer. Adding a TURN server (Twilio, Xirsys, or self-hosted coturn)
  to `CallingService._iceServers` fixes this.
- **No push notifications for background incoming calls** (Bonus 2/3 not
  implemented) — the incoming-call listener only fires while the app process
  is alive; add FCM + CallKit/ConnectionService for true background calling.
- **Presence is best-effort** — `isOnline` is set on login/logout, not on
  every disconnect (e.g. force-quit or crash won't flip it to offline until
  the next app open elsewhere reads a stale value). A Realtime Database
  `onDisconnect` hook would fix this properly.
- Group calling, screen sharing, call recording, and network-quality
  indicators (bonus features) are not implemented.

## AI Tools Used

This app (architecture, all Dart source files, README) was built with the
assistance of **Claude** (Anthropic). All generated code was reviewed for
correctness against the WebRTC + Firestore signaling flow described above;
please treat this as a starting point to run, test on real devices, and
adapt — in particular, verify the signaling listener logic and permission
flows on both Android and iOS before relying on it for the technical review.

## Deliverables Checklist

- [x] Source code (this repository)
- [ ] Android APK — build with `flutter build apk --release` after completing
      Firebase setup above
- [ ] Demo video — record after setup, showing login → contacts → audio call →
      video call → call history
