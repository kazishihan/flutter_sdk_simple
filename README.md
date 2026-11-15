# Flutter in native apps: the simple version

This is the plain, official Flutter add-to-app approach. There is **no wrapper SDK**:
each native app uses Flutter's own classes directly, with one small helper file
(`FlutterHost`) that holds the engine and the channel.

```
Android app ──▶ flutter_release (AAR) ──▶ Flutter engine
iOS app     ──▶ Flutter + App frameworks (CocoaPods) ──▶ Flutter engine
```

Status: written, **not built or run** (the authoring environment had no Flutter, Android
SDK or Xcode). Run the checks below on your machine.

## What is in the folder

| Path | What it is |
| --- | --- |
| `flutter_module/` | The Flutter UI. `lib/main.dart` is the whole app: one channel, one screen. |
| `native_android_app/` | Android app. `FlutterHost.kt` (engine + channel), `MainActivity.kt` (buttons). |
| `native_ios_app/` | iOS app. `FlutterHost.swift` (engine + channel), `HostViewController.swift` (buttons). |

## The channel (two calls each way)

Channel name: `com.example.flutter_module/bridge`

| Direction | Method | Data |
| --- | --- | --- |
| Flutter → app | `getConfig` | returns `{userId, language}` |
| Flutter → app | `sendEvent` | `{name, payload}`, returns `true` |
| App → Flutter | `receiveData` | a text string |

## Build and run: Android

```bash
cd flutter_module
flutter pub get
flutter build aar --no-debug --no-profile --build-number=1.0
cd ../native_android_app
./gradlew :app:assembleDebug        # Windows: gradlew.bat :app:assembleDebug
```

The app finds the AAR at `flutter_module/build/host/outputs/repo`
(see `settings.gradle.kts`) and the engine at `download.flutter.io`. Install it, then:
**Start Flutter engine** → **Open Flutter screen** → **Send data to Flutter**.
The Flutter screen's **Send event to host** shows up in the app's log.

If you changed the Flutter code, run `flutter build aar ...` again before building the app.

## Build and run: iOS

Needs a Mac with Xcode, Flutter, CocoaPods and XcodeGen (`brew install xcodegen`).

```bash
cd flutter_module
flutter pub get                      # creates the hidden .ios folder
cd ../native_ios_app
xcodegen generate                    # creates the project, runs `pod install`
open NativeIOSApp.xcworkspace
```

Run on a simulator from Xcode. A Debug build cannot be launched from the home screen
(a Flutter restriction); use a Release build on a real device for that.

## Using this in your own app

Android: add the two Maven repositories from `settings.gradle.kts`, add
`implementation("com.example.flutter_module:flutter_release:1.0")`, add the
`FlutterActivity` entry from `AndroidManifest.xml`, and copy `FlutterHost.kt`.

iOS: use the Podfile as a template (`install_all_flutter_pods`) and copy `FlutterHost.swift`.

## Sharing with another team

- **Android:** send them the folder `flutter_module/build/host/outputs/repo`
  (the whole folder, not only the `.aar`) and the three steps above.
- **iOS, with Flutter installed on their Mac:** send the `flutter_module` source and the Podfile lines.
- **iOS, without Flutter:** run `flutter build ios-framework --output=dist/ios` and send the
  xcframeworks; they drag them into Xcode (Frameworks, Libraries, and Embedded Content → Embed & Sign).

## Trade-offs versus the full SDK version

- Every host app writes (or copies) the engine and channel code, and uses Flutter classes.
- No listener API, no error codes, no queued data. If the host sends data before Flutter is
  ready, it can be lost, so start the engine early and send data after the screen opens.
- It is much smaller (two helper files per platform), which is the point.
