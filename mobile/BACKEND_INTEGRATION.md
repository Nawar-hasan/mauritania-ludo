# Backend integration status

The uploaded Flutter screens are preserved. The backend is now available in the repository, but mock removal should happen feature-by-feature so the application never becomes unusable.

Recommended connection order:

1. Auth and persisted tokens.
2. User profile and avatar upload.
3. Wallet accounts and ledger.
4. Match creation/matchmaking.
5. Socket.IO authoritative game state.
6. Admin-managed settings.
7. Remove the remaining mock store, tournament and social data after their API modules are added.

Build against local API:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 --dart-define=SOCKET_URL=http://10.0.2.2:3000/matches
```

Build against Railway:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-API.up.railway.app/api/v1 \
  --dart-define=SOCKET_URL=https://YOUR-API.up.railway.app/matches
```
