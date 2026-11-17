# Flutter in native apps: the simple version

This is the plain, official Flutter add-to-app approach.
Each native app uses Flutter's own classes directly, with one small helper file
(`FlutterHost`) that holds the engine and the channel.

```
Android app ──▶ flutter_release (AAR) ──▶ Flutter engine
iOS app     ──▶ Flutter + App frameworks (CocoaPods) ──▶ Flutter engine
```

## What is in the folder

| Path | What it is |
| --- | --- |
| `flutter_module/` | The Flutter UI. Three screens: Initial counter/navigation screen, `SecondScreen` (trigger payment), and `ThirdScreen` (payment result). |
| `native_android_app/` | Android app. `FlutterHost.kt` (engine + bridge), `PaymentActivity.kt` (native payment UI), and `MainActivity.kt` (host dashboard). |
| `native_ios_app/` | iOS app. `FlutterHost.swift` (engine + bridge), `PaymentViewController.swift` (native payment UI), and `HostViewController.swift` (host dashboard). |

## The bridge channel

Channel name: `com.example.flutter_module/bridge`

| Direction | Method | Data / Arguments | Response |
| --- | --- | --- | --- |
| Flutter → app | `getConfig` | — | `{userId: String, language: String}` |
| Flutter → app | `sendEvent` | `{name: String, payload: Map}` | `true` |
| Flutter → app | `openPayment` | `{phoneNumber: String}` | `{status: "success" \| "failed" \| "cancelled", phoneNumber: String}` |
| App → Flutter | `receiveData` | a text string | — |

### End-to-end payment journey
1. User navigates to `SecondScreen` in Flutter and taps **Pay**.
2. Flutter invokes `openPayment` with the validated phone number over the bridge channel.
3. Native host launches `PaymentActivity` (Android) or presents `PaymentViewController` (iOS) modally on top of the Flutter screen.
4. User selects **Success** or **Failed** (or cancels).
5. The native screen resolves the bridge call. On success, `SecondScreen` updates its status to **`Payment status: Paid`** and pushes `ThirdScreen` displaying the payment outcome.

## Android Architecture: Why `FlutterActivity` is required

In native Android, `io.flutter.embedding.android.FlutterActivity` is the Android Activity container that displays your Flutter UI on screen and connects it to the Android operating system.

### 1. Why a `FlutterEngine` alone is not enough
In `FlutterHost.start()`, creating and caching a `FlutterEngine` boots the Dart VM/isolate and sets up your `MethodChannel` in the background. However, a `FlutterEngine` is **headless**—it has no window, surface, or touch/keyboard input.

`FlutterActivity` provides:
- **Rendering Surface (`FlutterView`):** Attaches to the cached engine via `FlutterActivity.withCachedEngine(ENGINE_ID)` so Flutter has an Android `Surface`/`Texture` to render frames into.
- **Lifecycle & Input Bridging:** Automatically forwards Android Activity lifecycle states (`onResume`, `onPause`, `onDestroy`) to Flutter's `AppLifecycleState`, and routes touch events, soft keyboard/IME insets, and system back presses into Dart.
- **Configuration Change Handling:** Declared in `AndroidManifest.xml` with `android:configChanges` and `android:windowSoftInputMode="adjustResize"`, allowing Flutter to resize and re-layout smoothly on screen rotation or virtual keyboard toggles without destroying the Activity.
- **Android Manifest Requirement:** Android requires every Activity launched via `startActivity()` to be declared in `AndroidManifest.xml`; otherwise, calling `FlutterHost.open()` throws an `ActivityNotFoundException`.

### 2. How this project uses `FlutterActivity` without custom subclasses
To keep host app integration as simple as possible for client teams:
- **Stock Activity in Manifest:** Client host apps only need to declare the standard `io.flutter.embedding.android.FlutterActivity` with `android:exported="false"`. No custom `Activity` subclass is required.
- **Foreground Tracking via `ActivityLifecycleCallbacks`:** `FlutterHost` registers `Application.ActivityLifecycleCallbacks` to track the active `FlutterActivity` via a `WeakReference`. When Flutter requests `openPayment`, `FlutterHost` uses this foreground Activity context to launch `PaymentActivity` directly on top of the Flutter screen.
- **Security & One-Time Tokens:** `handleOpenPayment` generates a cryptographic one-time `UUID` token and locks concurrent payments. `PaymentActivity` finishes and returns the outcome directly to `FlutterHost.completePayment(token, ...)`, which verifies the token with `MessageDigest.isEqual` before resolving the `MethodChannel.Result`. If the `FlutterActivity` finishes or closes prematurely, pending payments are automatically cancelled.

### 3. Alternatives (when you would not use stock `FlutterActivity`)
- **Subclass `FlutterActivity`:** Only needed if the host app requires custom `Activity` lifecycle overrides directly inside the host screen itself.
- **`FlutterFragment`:** Used when Flutter should only occupy a portion of an existing Android screen (such as a tab, drawer, or bottom sheet) inside an existing `AppCompatActivity`.

---

## Build and run: Android

```bash
cd flutter_module
flutter pub get
flutter build aar --no-debug --no-profile --build-number=1.0
cd ../native_android_app
./gradlew :app:assembleDebug        # Windows: gradlew.bat :app:assembleDebug
```

> **JDK Note:** If `flutter build aar` encounters Dokka javadoc issues on newer JDKs (e.g., OpenJDK 25), specify JDK 17 or 21:  
> `flutter build aar --no-debug --no-profile --build-number=1.0 --extra-gen-args="-Dorg.gradle.java.home=/path/to/jdk-21"`

The app finds the local AAR at `flutter_module/build/host/outputs/repo` (see `settings.gradle.kts`) and the engine at `download.flutter.io`.

1. Launch `native_android_app`.
2. Tap **Start engine** → **Open Flutter**.
3. Tap **Go to Second Screen** → **Pay**.
4. Test the native payment flow and verify the result reflects on `SecondScreen` and navigates to `ThirdScreen`.

---

## Build and run: iOS

Needs a Mac with Xcode, Flutter, CocoaPods, and XcodeGen (`brew install xcodegen`).

```bash
cd flutter_module
flutter pub get                      # creates the hidden .ios folder
cd ../native_ios_app
xcodegen generate                    # creates the project, runs `pod install`
open NativeIOSApp.xcworkspace
```

Run on a simulator from Xcode. A Debug build cannot be launched directly from the home screen (a Flutter engine restriction); use a Release build on a real device for standalone launching.

---

## Using this in your own Native Android or iOS app

### Android
1. In `settings.gradle.kts`, add the local repo path and `download.flutter.io`:
   ```kotlin
   repositories {
       google()
       mavenCentral()
       maven { url = uri("$rootDir/../flutter_module/build/host/outputs/repo") }
       maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
   }
   ```
2. In `app/build.gradle.kts`:
   ```kotlin
   dependencies {
       implementation("com.example.flutter_module:flutter_release:1.0")
   }
   ```
3. In `AndroidManifest.xml`, register stock `FlutterActivity` and `PaymentActivity`:
   ```xml
   <activity
       android:name="io.flutter.embedding.android.FlutterActivity"
       android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
       android:exported="false"
       android:hardwareAccelerated="true"
       android:windowSoftInputMode="adjustResize" />
   <activity
       android:name=".PaymentActivity"
       android:exported="false"
       android:windowSoftInputMode="adjustResize" />
   ```
4. Copy `FlutterHost.kt` and `PaymentActivity.kt` into your Android source folder.

### iOS
1. In `Podfile`, use `install_all_flutter_pods(flutter_application_path)`.
2. Run `pod install`.
3. Copy `FlutterHost.swift` and `PaymentViewController.swift` into your app.

---

## Sharing with another team or vendor

- **Android:** Send them the folder `flutter_module/build/host/outputs/repo` (the entire Maven repo folder, not only the `.aar`) along with the dependency declarations and manifest snippets above.
- **iOS (with Flutter installed):** Send the `flutter_module` source and the Podfile snippet.
- **iOS (without Flutter):** Run `flutter build ios-framework --output=dist/ios` and distribute the generated `.xcframework` bundles for direct embedding in Xcode.

---

## Trade-offs versus a heavy SDK wrapper

- **Zero wrapper bloat:** Uses official Flutter engine APIs directly, keeping integration lightweight (two small helper files per platform).
- **No subclassing friction:** Host apps use stock `FlutterActivity` / `FlutterViewController` without having to change their inheritance hierarchies.
- **Synchronous start:** Start the engine before opening the screen to ensure instant presentation without frame lag or missed initial messages.
