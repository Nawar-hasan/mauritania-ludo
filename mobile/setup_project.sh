#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH. Install Flutter and run this script again."
  exit 1
fi
flutter create . --platforms=android,ios,web
flutter pub get
echo "Project setup completed. Run: flutter run"
