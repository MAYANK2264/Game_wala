# GameWala Repairs - Flutter Frontend

## Configure API URL
1. Deploy the Apps Script Web App and copy its URL ending with `/exec`.
2. Open `lib/main.dart` and replace `REPLACE_WITH_YOUR_DEPLOYMENT_ID` with your deployment path or paste full URL into `_baseUrl`.

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

## Notes
- Uses `http` for API calls.
- Basic validation and snackbars are included.
- Role selection is local-only for MVP.
