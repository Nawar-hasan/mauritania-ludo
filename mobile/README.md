# Ludo Champion — Flutter Frontend Prototype

A complete frontend-only Flutter prototype based on the supplied 33 reference images, with missing application flows added.

## Included

- Splash, onboarding, language selection, login, registration, OTP, forgot/reset password and policies.
- Home dashboard and bottom navigation.
- Game-mode selection, 2/4 players, Classic/Quick/Master rules, wager selection, confirmation and matchmaking.
- Private room creation, room-code joining, room preview and waiting room.
- Interactive local Ludo board prototype with dice, turn timer, auto-roll, auto-move, inactivity timeout and result pages.
- Wallet, mock deposit flow, receipt submission, withdrawal review, OTP field and transaction history.
- Store tabs for coins, gems, skills, dice and frames.
- Tournaments, details, bracket and leaderboard.
- Social voice rooms, room creation, seats, chat and gifts.
- Profile, stats, history, inventory, achievements, referrals, privacy, sound and support pages.
- Arabic/English direction toggle.
- Screen catalog accessible from the bottom of the Home screen.
- All original images included under `assets/reference_ui/` for visual comparison only. The UI is built with Flutter widgets and does not use screenshots as backgrounds.

## Important prototype notes

- No backend is connected.
- Wallet values, deposits, withdrawals, matchmaking, chat and gifts are mock/local interactions.
- Dice and match state are local for interface testing. In production, the backend must be authoritative for dice, movement validation, timers and results.
- Paid skills are intentionally excluded from wager games.
- Real-money operations require legal review, identity/age verification, responsible-play controls and compliance for each launch country.

## Run

Flutter is not installed in the artifact-generation environment, so native platform folders were not auto-generated here.

From the project directory on a computer with Flutter installed:

```bash
flutter create . --platforms=android,ios,web
flutter pub get
flutter run
```

`flutter create .` preserves the existing `lib/`, assets and `pubspec.yaml` while generating Android/iOS/Web runner files.

## First route

The app starts at Splash and automatically opens onboarding. Use **Explore demo without account** on Login to open the frontend immediately.
