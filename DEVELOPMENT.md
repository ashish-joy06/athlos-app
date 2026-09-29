# Development Guide for Athletix

Welcome to the development guide for **Athletix** — A Flutter-Firebase based mobile application designed to streamline collaboration between athletes, coaches, doctors, and sports organizations.

---

## Project Setup

### Prerequisites

* **Flutter SDK** - [Install Flutter](https://docs.flutter.dev/get-started/install)
* **Git** - [Install Git](https://git-scm.com/downloads)

### 1. Fork the Repository into your GitHub Account
[Fork Repo](https://github.com/vjlive/athletix/fork)
### 2. Clone the Repository

```bash
git clone https://github.com/<your-username>/athletix.git
cd athletix
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 5. Run the Development Server

```bash
flutter run
```
- It is recommended to use a physical android device for debugging.
---

## Project Structure

```
Athletix/
├── android/
├── assets/
│   ├── applogo.png
│   └── Running_Boy.json
├── functions/
├── ios/
├── lib/
│   ├── components/
│   │   ├── bottom_nav_bar.dart
│   │   └── fcm_listener.dart
│   ├── screens/
│   │   ├── athlete/
│   │   │   ├── athlete_dashboard.dart
│   │   │   ├── calendar_screen.dart
│   │   │   ├── injury_tracker_screen.dart
│   │   │   ├── performance_logs_screen.dart
│   │   │   └── tournaments_screen.dart
│   │   ├── coach/
│   │   │   └── coach_dashboard.dart
│   │   ├── doctor/
│   │   │   └── doctor_dashboard.dart
│   │   ├── organization/
│   │   │   ├── add_tournament_screen.dart
│   │   │   ├── manage_players_screen.dart
│   │   │   └── organization_dashboard.dart
│   │   ├── auth_screen.dart
│   │   ├── profile_screen.dart
│   │   └── splash_screen.dart
│   └── main.dart
├── linux/
├── macos/
├── test/
├── web/
├── windows/
├── .firebaserc
├── .gitignore
├── .metadata
├── analysis_options.yaml
├── CODE_OF_CONDUCT.md
├── DEVELOPMENT.md
├── CONTRIBUTING.md
├── firebase.json
├── LICENSE
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

---

## Useful Scripts

| Script       | Description           |
| ------------ | --------------------- |
| `flutter pub get` | Get Flutter Dependencies |
| `flutter run`  | Run Flutter App |
| `flutter clean`   | Remove all Dependencies |
| `flutter doctor` | Check the Flutter SDK status |

---

Happy Coding!
