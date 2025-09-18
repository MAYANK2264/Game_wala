# GameWala Repairs - Flutter Frontend

## Configure API URL & Google Sign-In
1. Deploy the Apps Script Web App and copy its URL ending with `/exec`.
2. Open `lib/main.dart` and set `_baseUrl` to that URL.
3. Google Sign-In requires a SHA-1 for Android: set it up in your Firebase project if needed. For local testing, most devices work without Firebase config, but production should set up properly.

Example:
```
final String _baseUrl = 'https://script.google.com/macros/s/AKfycb.../exec';
```

## Run
```
flutter pub get
flutter run -d android
```

## Build APK
```
flutter build apk --release
```
The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

If you need an app bundle:
```
flutter build appbundle --release
```

## Notes
- Uses Google Sign-In to obtain the user email; employees must be approved in the sheet.
- Voice notes are saved to Google Drive via Apps Script and linked in the sheet.
- Status colors: red Received, yellow In Progress, green Completed, blue Handed Over.
