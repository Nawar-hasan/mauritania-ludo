# Ludo Champion V2 fixes

- Actual Arabic mode with RTL, persistent language choice, and translations for shared screens, navigation, buttons, forms, profile and the new game screen.
- Working profile photo selection from camera and gallery using `image_picker`; the selected local image is saved and reused after restarting the application.
- New local Classic Ludo engine: four tokens, roll 6 to leave base, extra roll on 6, three consecutive sixes cancel the third turn, safe cells, captures, exact home roll, four-token win detection, roll/move timers and timeout.
- Rebuilt game screen with green top-left, yellow top-right, red bottom-left and blue bottom-right, matching the supplied reference. Dice has a dedicated framed area below the board.

## Update an existing project
Extract the patch into the project root and overwrite existing files, then run:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```
