# 🌿 LifeInSync — Digital Wellbeing App

> A Flutter-based digital wellbeing companion that helps users track screen time, build habits, manage focus sessions, and monitor digital fatigue.

---

## 📱 App Overview

LifeInSync is a mobile-first wellbeing app built with Flutter and Firebase. It gives users a clear picture of their digital habits through screen time tracking, app categorization, focus mode, habit building, and an auto-detected fatigue score — all in one clean, calming interface.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Authentication | Firebase Auth (Email, Google, Phone OTP) |
| Database (Cloud) | Cloud Firestore |
| Database (Local) | Drift / SQLite |
| State Management | Riverpod |
| UI / Animations | flutter_animate, fl_chart |
| Fonts | Google Fonts — Raleway (all screens) |
| Screen Time | app_usage (Android) |
| Notifications | flutter_local_notifications |

---

## ✅ What Is Done

### 🔐 Authentication
- [x] Email & Password sign up / sign in
- [x] Google Sign-In (mobile + web via popup)
- [x] Phone OTP sign in with 6-digit Pinput UI
- [x] Forgot password (Firebase reset email)
- [x] Auth state listener (`_AuthGate`) — auto routes to home or login
- [x] Sign out with confirmation dialog
- [x] Signup redirects to Login (not dashboard)
- [x] Firebase initialized in `main.dart`

### 🎨 UI / Design System
- [x] Full custom theme in `app_theme.dart`
- [x] Raleway font applied globally across all screens
- [x] Calm green + violet color palette
- [x] Rounded card design language (20–24px radius)
- [x] Reusable decorations (`primaryGradientCard`, `cardShadowLight`, etc.)
- [x] Dark/light color tokens defined

### 🏠 Dashboard
- [x] Time-aware greeting (Good morning/afternoon/evening)
- [x] Wellbeing score card (gradient, circular progress ring)
- [x] Quick stats row (Focus, Habits, Screen time)
- [x] Focus session quick-launch card
- [x] Screen time summary with category bars
- [x] Today's habits chip strip
- [x] Fatigue badge card
- [x] Staggered entrance animations

### 📱 Screen Time
- [x] Weekly bar chart (fl_chart) — color coded (green = ok, red = over limit)
- [x] Today's total card with over/under limit indicator
- [x] Per-app usage list with category badges and progress bars
- [x] Daily screen limit slider
- [x] Static mock data (real data wiring = TODO)

### 📂 App Categorizer
- [x] Rule-based categorization engine (`category_rules_engine.dart`)
- [x] 10 categories: Productive, Entertainment, Social, Education, Health, Gaming, News, Shopping, Finance, Utility
- [x] Package name exact match + keyword fallback
- [x] Health ratio banner (healthy % + progress bar)
- [x] Pie chart centered with legend (interactive touch)
- [x] Filter chips by category
- [x] Per-app tile with usage bar
- [x] Static mock data (real data wiring = TODO)

### ⏱️ Focus Mode
- [x] Three session types: Pomodoro (25m), Deep Work (50m), Flow State (90m)
- [x] Animated countdown ring with pulse effect
- [x] Short break (5m) and long break (15m) auto-switching
- [x] Pomodoro counter and focus streak
- [x] Session tip card
- [x] Play / Pause / Reset / Skip controls
- [x] Session completion snackbar
- [x] Focus sessions NOT yet saved to Firestore (TODO)

### 😴 Fatigue Tracker
- [x] Auto-detection algorithm (`fatigue_detector.dart`)
- [x] Scoring based on: screen time, draining apps, late night use, long sessions
- [x] Healthy behavior deductions (focus sessions, habits)
- [x] 4 fatigue levels: Fresh, Mild, Moderate, High
- [x] Score gauge ring UI
- [x] Score breakdown card with per-factor bars
- [x] 7-day history bar chart (mock data)
- [x] Trigger list with severity badges
- [x] Recommendation card
- [x] NOT yet saving to Firestore (TODO)

### ✅ Habits
- [x] Habit list with emoji, name, streak, completion toggle
- [x] Animated checkmark toggle
- [x] Add habit bottom sheet (emoji picker + name field)
- [x] Progress card (today's completion %)
- [x] Static in-memory state (Firestore wiring = TODO)

### 📊 Insights
- [x] Week / Month toggle
- [x] Summary cards (avg score, avg fatigue, focus time)
- [x] Wellbeing + fatigue dual line chart
- [x] Productive vs Draining comparison bar
- [x] Category time breakdown list
- [x] Habit consistency bars (7-day)
- [x] AI Insights cards (pattern-based text, static)
- [x] All static mock data (real data wiring = TODO)

### 🚪 Navigation & Global Shell
- [x] `MainShell` with GlobalKey Scaffold
- [x] Hamburger menu AppBar (visible on all screens)
- [x] Avatar in AppBar opens drawer
- [x] Side drawer with all 7 nav items + Sign Out
- [x] Bottom NavigationBar (7 destinations)
- [x] `IndexedStack` preserves screen state
- [x] Sign out confirmation dialog (Cancel + Sign Out side by side)
- [x] Logout clears full navigation stack

---

## ⬜ What Needs To Be Done

### 🔴 Priority 1 — Backend Wiring (Core)

- [ ] **Add `cloud_firestore` package** to `pubspec.yaml`
- [ ] **Create `FirestoreService`** at `lib/shared/services/firestore_service.dart`
- [ ] **Wire user profile creation** on signup (save name, email, preferences to Firestore)
- [ ] **Wire Habits to Firestore** — replace static list with `StreamBuilder` reading from `habits/{uid}/items`
- [ ] **Wire Habit logging** — toggle = write to `habitLogs/{uid}/logs/{habitId}_{date}`
- [ ] **Wire Focus sessions** — save to `focusSessions/{uid}/sessions` on session complete
- [ ] **Wire Fatigue score** — save daily score to `fatigueHistory/{uid}/logs/{date}`
- [ ] **Wire Insights** — read real data from all Firestore collections instead of mock arrays

### 🟡 Priority 2 — Real Screen Time Data

- [ ] **Request PACKAGE_USAGE_STATS permission** on first launch (Android)
- [ ] **Create `ScreenTimeService`** using `app_usage` package
- [ ] **Replace mock app list** in `screen_time_screen.dart` with real usage data
- [ ] **Replace mock app list** in `categorizer_screen.dart` with real usage data
- [ ] **Feed real screen time** into `FatigueDetector.analyze()` inputs

### 🟡 Priority 3 — Notifications

- [ ] **Create `NotificationService`** at `lib/shared/services/notification_service.dart`
- [ ] **Initialize notifications** in `main.dart`
- [ ] **Habit reminders** — per-habit scheduled notification at user-set time
- [ ] **Screen time warnings** — alert when approaching daily limit
- [ ] **Focus session nudge** — "You haven't focused today" end-of-day reminder
- [ ] **Streak milestone celebrations** — 7, 21, 30 day habit streaks

### 🟠 Priority 4 — Security & Production Readiness

- [ ] **Set Firestore security rules** (replace test mode)
  ```
  Only allow users to read/write their own documents
  Validate data types on write
  ```
- [ ] **Enable Firebase App Check** (prevent unauthorized API access)
- [ ] **Add Firebase Crashlytics** for error monitoring
- [ ] **Add input sanitization** on all text fields
- [ ] **Handle Firestore offline mode** gracefully

### 🔵 Priority 5 — UX Polish

- [ ] **Onboarding flow** (3 screens for new users — name, goals, daily limit)
- [ ] **Settings screen** (daily limits, notification preferences, theme toggle)
- [ ] **Profile screen** (edit name, avatar, timezone)
- [ ] **Empty states** on all screens when no data exists yet
- [ ] **Loading skeletons** while Firestore data loads
- [ ] **Pull to refresh** on dashboard and insights
- [ ] **Dark mode** support (tokens already in `app_theme.dart`)

### 🔵 Priority 6 — Future Features

- [ ] **Weekly PDF report** export (habit + focus + screen summary)
- [ ] **Widget support** (home screen widget showing daily score)
- [ ] **Wearable sync** (Google Fit / Health Connect integration)
- [ ] **Social accountability** (share streaks with friends)
- [ ] **iOS support** (Screen Time API requires special entitlement from Apple)

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry, Firebase init, AuthGate
├── core/
│   ├── theme/
│   │   └── app_theme.dart            # Colors, Raleway font, global theme
│   └── constants/
│       └── app_constants.dart        # Route names, thresholds, keys
├── features/
│   ├── auth/
│   │   ├── auth_service.dart         # Firebase Auth (email, Google, OTP)
│   │   ├── login_screen.dart         # Login UI
│   │   ├── signup_screen.dart        # Signup UI
│   │   └── otp_screen.dart           # Phone OTP UI
│   ├── dashboard/
│   │   ├── dashboard_screen.dart     # Home screen
│   │   └── main_shell.dart           # Nav shell, AppBar, Drawer
│   ├── screen_time/
│   │   └── screen_time_screen.dart   # Weekly chart, app list
│   ├── app_categorizer/
│   │   ├── categorizer_screen.dart   # Pie chart, filter, app tiles
│   │   └── category_rules_engine.dart# Rule-based app categorization
│   ├── focus_mode/
│   │   └── focus_screen.dart         # Pomodoro timer, controls
│   ├── fatigue_tracker/
│   │   ├── fatigue_screen.dart       # Score UI, breakdown, history
│   │   └── fatigue_detector.dart     # Auto-score algorithm
│   ├── habits/
│   │   └── habits_screen.dart        # Habit list, add sheet, toggle
│   └── insights/
│       └── insights_screen.dart      # Charts, AI insights, consistency
└── shared/
    ├── widgets/                       # (empty — reusable widgets go here)
    └── services/
        ├── firestore_service.dart     # TODO: create this
        ├── screen_time_service.dart   # TODO: create this
        └── notification_service.dart  # TODO: create this
```

---

## 🚀 Getting Started

### Prerequisites
```bash
flutter --version    # Flutter 3.x+
dart --version       # Dart 3.x+
```

### Setup
```bash
# 1. Clone the repo
git clone https://github.com/your-org/lifeinSync.git
cd lifeinSync

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
# - Create project at console.firebase.google.com
# - Enable Auth (Email, Google, Phone)
# - Enable Firestore (test mode)
# - Run: flutterfire configure
# - This generates lib/firebase_options.dart

# 4. Add Google Client ID for web (in web/index.html)
# <meta name="google-signin-client_id" content="YOUR_ID.apps.googleusercontent.com">

# 5. Run
flutter run
```

### Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
  tools:ignore="ProtectedPermissions"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 🗄️ Firestore Data Structure

```
users/{uid}
  → name, email, createdAt, dailyScreenLimit, focusGoalMinutes

habits/{uid}/items/{habitId}
  → name, emoji, frequency, streak, createdAt

habitLogs/{uid}/logs/{habitId}_{date}
  → habitId, date, completed

focusSessions/{uid}/sessions/{sessionId}
  → type, durationMinutes, startTime, completed

fatigueHistory/{uid}/logs/{date}
  → date, score, level, triggers
```

---

## 🔐 Firestore Security Rules (Apply Before Launch)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /habits/{userId}/items/{habitId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /habitLogs/{userId}/logs/{logId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /focusSessions/{userId}/sessions/{sessionId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /fatigueHistory/{userId}/logs/{logId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## 📦 Key Dependencies

```yaml
firebase_core: ^3.3.0
firebase_auth: ^5.1.0
cloud_firestore: ^5.4.0        # Add this next
google_sign_in: ^6.2.1
flutter_riverpod: ^2.5.1
fl_chart: ^0.68.0
flutter_animate: ^4.5.0
google_fonts: ^6.2.1
pinput: ^5.0.0
app_usage: ^3.0.0
flutter_local_notifications: ^17.2.1
drift: ^2.18.0
```

---

## 👥 For the Next Developer

**Where to start:** `lib/shared/services/firestore_service.dart` — this is the most important file to create. Once it exists, you can wire it into each screen one at a time.

**Order of work:**
1. Create `FirestoreService` (all CRUD methods)
2. Wire signup → creates user profile in Firestore
3. Wire habits screen → `StreamBuilder` on `getHabitsStream()`
4. Wire focus screen → save session on `_onTimerComplete()`
5. Wire fatigue screen → save score daily
6. Wire insights → read real data
7. Replace mock screen time with `app_usage`
8. Add notifications
9. Set security rules
10. Test end-to-end on real Android device

**All mock data is clearly marked** — search for `// Sample` or `// Mock` comments in each screen file to find exactly what needs replacing.

---

## 🧑‍💻 Built With

Flutter · Firebase · Riverpod · Raleway · fl_chart · flutter_animate

---

*LifeInSync — because your digital life deserves balance. 🌿*
