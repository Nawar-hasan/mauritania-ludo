#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "Usage: ./release_tools/prepare_ios_on_mac.sh https://YOUR-BACKEND-DOMAIN.up.railway.app"
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/mobile"
BACKEND="${1%/}"
API="$BACKEND/api/v1"
SOCKET="$BACKEND/matches"
if [ ! -d ios ]; then
  flutter create . --platforms=ios
fi
flutter clean
flutter pub get
cat <<MSG
The iOS project is ready.
Next open mobile/ios/Runner.xcworkspace in Xcode and set:
- Display Name: MAURITANIA LUDO
- A unique Bundle Identifier, e.g. com.mauritanialudo.app
- Your Apple Developer Team
Then run:
flutter build ipa --release --dart-define=API_BASE_URL=$API --dart-define=SOCKET_URL=$SOCKET
MSG
