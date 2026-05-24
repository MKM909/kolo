# Kolo

Kolo is an Android-first Flutter app that acts as a personal AI-powered financial operating system for young Nigerians with irregular income.

The app does not move money and is not a bank. It sits on top of the user's existing bank and fintech apps, tracks financial activity, keeps a usable balance, and uses Google Gemini to help the user budget, understand spending, and pause before bad financial decisions.

## Product Direction

Kolo is designed for students, freelancers, and early-career users whose money comes from allowance, family support, gigs, and other unpredictable sources. The core experience is proactive rather than purely manual:

- Detect transaction alerts from SMS and notifications.
- Keep a running balance in Nigerian Naira.
- Categorize income and expenses automatically.
- Generate and adjust budgets through conversational onboarding.
- Intervene through a floating Kolo bubble when spending context matters.
- Track savings vaults, owings, gigs, bills, and weekly spending patterns.
- Support trusted partner sharing for selected summaries.

All planned product capabilities are v1 launch scope.

## Core Features

- Firebase Auth with email/password, Google Sign-In, and biometric unlock.
- AI onboarding chat that creates the initial budget.
- Manual balance and transaction logging.
- SMS transaction parsing for Nigerian banks.
- Notification listener for supported fintech apps.
- Android app watcher through AccessibilityService.
- Floating overlay bubble for alerts, chat, and spending interventions.
- Full Kolo AI chat powered by Google Gemini via Firebase Cloud Functions.
- Budget dashboard, analytics, transactions, and category breakdowns.
- Savings vaults, owings tracker, gig tracker, and bill reminders.
- Pattern insights and trusted partner sharing.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter / Dart |
| State management | Riverpod |
| Backend | Firebase Auth, Firestore, Cloud Functions |
| AI | Google Gemini via Cloud Functions |
| Local cache | Hive |
| Background services | `flutter_background_service` |
| Overlay | `flutter_overlay_window` |
| SMS | Native Android SMS receiver + Flutter service boundary |
| Notifications | `notification_listener_service` |
| Charts | `fl_chart` |
| Animations | `flutter_animate` |

## Project Docs

- [Product Requirements](kolo_prd.md)
- [User Flows](kolo_user_flow.md)
- [Design System](kolo_design.md)

## Development

Install dependencies:

```sh
flutter pub get
```

Run the app:

```sh
flutter run
```

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

Run backend tests:

```sh
cd functions
npm test
```

## Gemini Configuration

Kolo calls Gemini only from Firebase Cloud Functions. Functions read the API key from `GEMINI_API_KEY`; do not commit the raw key. Set it as a Firebase secret or local Functions environment value before running live AI calls.

The default model is `gemini-3.1-flash-lite`. Users can change the model from Profile > Kolo AI Model, and the selected model is sent with Gemini-backed callable requests.
