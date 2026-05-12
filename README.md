# CareCircle

CareCircle is a **SwiftUI** healthcare support app that connects **caregivers**, **social workers**, and **community** participants. It uses **Firebase** for authentication, Firestore, Storage, and optional **Cloud Functions**, with **SwiftData** for local persistence and role-based dashboards after a location onboarding step.

---

## Features

- **Role-based access** — Separate experiences for caregivers, social workers, and community users (`ContentView` / `RootView`).
- **Location onboarding** — Users complete location capture before entering the main app (`LocationCaptureView`, `GeoService`).
- **Routines** — Routine tracking, completion, and local notifications (`RoutineService`, `RoutineNotificationManager`, `RoutineCompletionService`).
- **Community** — Community requests, posts, and support flows (`CommunityService`, `CommunityViews`, `CareRequestService`, `SupportPostService`).
- **Social** — Social posts, connections, and messaging-style flows (`SocialPostService`, `SocialConnectView`, `ChatService`, `UnseenRepliesManager`).
- **Care reports** — Structured questions, flow, preview, and export helpers (`CareReportFlowView`, `CareReportService`, `CareReportQuestions`, `PDFService`, `ReportImageService`).
- **Journal** — Journal entries, calendar, and automatic cleanup of older entries (`JournalStore`, `JournalCalendarView`, `JournalEntryView`).
- **Declutter** — Dedicated declutter experience (`DeclutterView`) — some tabs may be toggled in the UI over time.
- **Theming** — Centralized app styling (`AppTheme`).
- **Backend config** — `firebase.json`, `firestore.rules`, `storage.rules`, and Node **Cloud Functions** under `functions/`.

---

## Tech stack

| Layer | Technology |
|--------|------------|
| UI | SwiftUI |
| Apple frameworks | SwiftData, MapKit / Core Location (via location features), UserNotifications |
| Backend | Firebase Auth, Firestore, Storage, Firebase iOS SDK (Swift Package Manager) |
| Serverless | Firebase Cloud Functions (Node.js in `functions/`) |
| Tooling | Xcode (Swift 6 toolchain recommended), Git |

---

## Requirements

- **macOS** with **Xcode 16** (or the version that matches `objectVersion` / your team’s setup).
- An **Apple Developer** account for device testing, push capabilities, and distribution (as needed).
- A **Firebase** project with iOS app registered using the same **bundle identifier** as the Xcode target.

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/CareCircle.git
cd CareCircle
```

### 2. Firebase configuration (required)

1. In the [Firebase Console](https://console.firebase.google.com/), open your project (or create one).
2. Add an **iOS app** with bundle ID matching Xcode (e.g. `namanYadav.CareCircle` — confirm under target **Signing & Capabilities**).
3. Download **`GoogleService-Info.plist`**.
4. Place it in the **`CareCircle/`** folder next to the other app sources (same level as `CareCircleApp.swift`).

> **Public repositories:** `GoogleService-Info.plist` is listed in `.gitignore` so secrets are not committed. Use `CareCircle/GoogleService-Info.plist.example` as a shape reference only; always use the file from Firebase Console for real values.

### 3. Open the project in Xcode

```bash
open CareCircle.xcodeproj
```

- Resolve Swift packages: **File → Packages → Resolve Package Versions** (first open may fetch Firebase automatically).
- Select the **CareCircle** scheme and a simulator or device, then **Run** (⌘R).

### 4. Firestore, Storage, and Functions (optional)

If you use server-side rules or Cloud Functions:

- Deploy rules and functions with the [Firebase CLI](https://firebase.google.com/docs/cli):  
  `firebase deploy --only firestore:rules,storage,functions`  
  (from the repo root, after `firebase login` and `firebase use <projectId>`).
- Install function dependencies:  
  `cd functions && npm install`

Internal notes in the repo (`RULES_DEPLOY.md`, `STORAGE_RULES_DEBUG.md`) may help your team debug rule deployments.

---

## Project layout (high level)

```
CareCircle/
├── CareCircle/              # SwiftUI app sources
├── CareCircleTests/         # Unit tests
├── CareCircleUITests/       # UI tests
├── CareCircle.xcodeproj/    # Xcode project
├── firebase.json            # Firebase project config
├── firestore.rules          # Firestore security rules
├── storage.rules            # Storage security rules
└── functions/               # Cloud Functions (Node)
```

---

## Git & GitHub

The repository is intended to track **source** and **shared** Xcode data (for example `Package.resolved` under `xcshareddata` for reproducible dependency resolution), while **excluding** machine-specific `xcuserdata`, build artifacts, `functions/node_modules`, and **`GoogleService-Info.plist`**.

If this is your first push:

1. Create a **new empty** repository on GitHub (no README/license if you already have them locally to avoid merge conflicts).
2. Add the remote and push (replace URL with yours):

```bash
git remote add origin https://github.com/<your-username>/CareCircle.git
git add -A
git status   # review changes
git commit -m "Initial CareCircle open-source snapshot"
git push -u origin main
```

If `GoogleService-Info.plist` was ever committed with real keys, rotate the affected keys in Google Cloud / Firebase and prefer the `.gitignore` approach going forward.

---

## Future improvements

- **Tests** — Expand unit and UI tests around auth, Firestore services, and critical flows.
- **Accessibility** — Audit Dynamic Type, VoiceOver labels, and contrast using `AppTheme` tokens.
- **CI** — Add Xcode build + optional `firebase emulators` in GitHub Actions.
- **Feature flags** — Remote Config or a simple backend flag for tab visibility (e.g. journal / declutter).
- **Offline-first** — Broader Firestore offline persistence patterns and conflict handling where needed.
- **HIPAA / compliance** — If you target regulated environments, document BAA, data retention, and encryption posture explicitly (this README is not legal advice).

---

## License

Specify a license (e.g. MIT, Apache-2.0) by adding a `LICENSE` file at the repository root.

---

## Acknowledgments

Built with SwiftUI and Firebase. Healthcare UX and copy should be reviewed with domain experts before production clinical use.
