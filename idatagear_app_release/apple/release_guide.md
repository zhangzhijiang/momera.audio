# Momera.Audio — iOS release guide

Reference for *how* and *why* the iOS build is configured the way it is.
Companion to [`release_checklist.md`](release_checklist.md), which is the
ordered to-do list. This file explains the reasoning; that one tracks the work.

**Last verified: 2026-09-05.** Every command quoted below was actually run on
that date and its real output recorded.

---

## Current build status

| Platform | Command | Result (2026-09-05) |
|---|---|---|
| Android | `flutter build appbundle --release` | ✅ `app-release.aab`, 95.4 MB |
| iOS | `flutter build ios --release --no-codesign` | ✅ `Runner.app`, 49.0 MB |
| Analyzer | `flutter analyze` | ✅ No issues found |
| Tests | `flutter test` | ✅ 1/1 passed |

Version is `1.0.0+1` (`pubspec.yaml`). Neither store has a released build yet.

> **Android release signing was broken before this port started.**
> `android/key.properties` carried a Windows path
> (`c:/Users/zhang/new-upload-key.jks`) left over from the machine the project
> was created on, so `validateSigningRelease` failed on this Mac. It now points
> at `/Users/zhangzhijiang/Developer/projects/new-upload-key.jks`, the same
> upload keystore the other apps use (alias and passwords were already correct —
> only the path was wrong). That file is gitignored and machine-local, so a
> fresh clone on another Mac will hit the same failure and need the same fix.

---

## Per-platform divergence table

**Everything not in this table is shared.** That is the point of the table: if
you are wondering whether an iOS change affects Android, and it is not listed
here, the answer is yes.

| Concern | Android | iOS | Why they differ |
|---|---|---|---|
| Application id | `com.idatagear.momera.audio` | `com.idatagear.momera.audio` | **Deliberately identical.** `flutter create` derived `com.idatagear.momera.momeraAudio` from the Dart package name; that was overridden to match Android. Nothing forced a difference and a matching id is one less thing to get wrong. |
| Minimum OS | `minSdk 24` (Android 7.0) | `IPHONEOS_DEPLOYMENT_TARGET 13.0` | Set by different plugin floors — see below. |
| Display name | `Momera.Audio` (`AndroidManifest.xml`) | `Momera.Audio` (`CFBundleDisplayName`) | Same string; different mechanism. |
| Signing | Upload keystore via `android/key.properties` | Automatic, `DEVELOPMENT_TEAM = 6ZWZ3Z58ZT` | Platform mechanics. |
| Model storage | app support dir | `Library/Application Support` | Same Dart call, `getApplicationSupportDirectory()`. Listed only because the *reason* is iOS-specific — see below. |
| Backup exclusion | no-op | `NSURLIsExcludedFromBackupKey` via method channel | Android has no iCloud backup of app-private files to opt out of. The Dart side branches on `defaultTargetPlatform` and returns early. |
| Privacy manifest | n/a | `ios/Runner/PrivacyInfo.xcprivacy` | Apple-only requirement. |
| Background audio | *not yet implemented* | `UIBackgroundModes: [audio]` declared | See "Known gaps". |
| Device family | phones + tablets (no restriction) | `TARGETED_DEVICE_FAMILY = "1"` (iPhone only) | Deliberate for v1 — see below. Android has no equivalent gate; the same APK runs on tablets. |
| Architectures | `arm64-v8a`, `x86_64` | device `arm64` | `x86_64` is kept on Android for emulator debug builds. |

### Things that look like they should differ but do not

- **Product/bundle identifier.** See above — same on both, on purpose.
- **The 16 kHz mono WAV recording format.** Identical, and it must stay
  identical: `RecordingRepository._durationForWavBytes()` derives a recording's
  duration arithmetically from its byte length assuming exactly that format.
- **Where user recordings live.** `Documents/recordings/` on both. Recordings
  are user-generated content that *should* be backed up. Only the
  re-downloadable model moved out of `Documents/`.
- **The model download URLs and the 239,233,841-byte integrity check.**
  Byte-identical model on both platforms.
- **Ads, IAP, analytics, crash reporting, tracking.** None on either platform.
  There is nothing to diverge.

---

## Why the deployment target is 13.0

`IPHONEOS_DEPLOYMENT_TARGET = 13.0`, set in `ios/Runner.xcodeproj/project.pbxproj`
(all three configurations) and `ios/Podfile`.

**It is 13.0 because of exactly one plugin: `sherpa_onnx_ios`.**

| Plugin | iOS floor |
|---|---|
| **`sherpa_onnx_ios` 1.13.2** | **13.0** ← binding constraint |
| `record_ios` 1.2.1 | 12.0 |
| `just_audio` 0.10.5 | 12.0 |
| `audio_session` 0.2.3 | 12.0 |
| `permission_handler_apple` | 12.0 *(dependency since removed)* |

**The runner-up is 12.0.** If `sherpa_onnx_ios` ever relaxes its floor, or the
speech engine is replaced, the target can drop straight to 12.0 with no other
change. Nothing else in the project needs 13.0.

Do not raise it "to be safe" — every bump drops real devices. Raise it only when
`pod install` actually fails and names the plugin that demands it.

`ios/Flutter/AppFrameworkInfo.plist` does **not** carry a `MinimumOSVersion`
key. Current Flutter templates drop it rather than keep a third copy in sync, so
there are only two places to change: the pbxproj and the Podfile.

### Swift Package Manager stays off

`flutter build` reports:

```
The following plugins do not support Swift Package Manager for ios:
  - sherpa_onnx_ios
```

The `no-enable-swift-package-manager` flag is already set. Leave it. Turning SPM
on breaks the build until sherpa-onnx adopts it.

---

## Why the model moved out of `Documents/`

`ModelDownloadService` downloads a ~239 MB SenseVoice model at runtime rather
than bundling it. It originally landed in `getApplicationDocumentsDirectory()`.

On iOS that maps to `<container>/Documents`, which is **backed up to iCloud and
cannot be purged by the system**. Apple's iOS Data Storage Guidelines are
explicit that only user-generated data that cannot be re-created belongs there;
re-downloadable content must live elsewhere. Shipping a quarter-gigabyte of
re-fetchable model into `Documents/` is a well-known rejection.

It now uses `getApplicationSupportDirectory()` and additionally sets
`NSURLIsExcludedFromBackupKey` on the containing directory:

- **Not `Documents/`** — would be rejected.
- **Not `Library/Caches/`** — the system may purge it under disk pressure, and
  silently deleting a model the user waited several minutes to download is a
  terrible experience.
- **`Library/Application Support` + do-not-back-up** — the combination Apple's
  own documentation points at for exactly this case.

This is a **shared** change: the Android path moved too. That was free here
because nothing has shipped. **If this app were already live, the same change
would orphan every existing user's 239 MB download** and silently re-download
it. Any future move of this path needs a migration step.

The exclusion flag is applied through a small method channel
(`com.idatagear.momera.audio/backup`, handled in `ios/Runner/AppDelegate.swift`)
because there is no pure-Dart API for it. The Dart side checks
`defaultTargetPlatform` and returns early off Apple platforms, and a failure to
set the flag is logged rather than propagated — it must never fail a download.

---

## No tracking — deliberate, and recorded so nobody re-derives it

Momera.Audio ships **no tracking of any kind**, and this is a decision, not an
oversight. Recorded here so it is not re-litigated later:

- No ads SDK, no analytics, no crash reporting, no attribution SDK.
- No `app_tracking_transparency` dependency and no ATT prompt anywhere.
- No `NSUserTrackingUsageDescription` in `Info.plist`.
- `NSPrivacyTracking = false` in `PrivacyInfo.xcprivacy`, with **no**
  `NSPrivacyTrackingDomains` key at all.

That last point matters. Apple's rule runs both ways: declaring tracking
domains requires `NSPrivacyTracking = true`, and declaring
`NSPrivacyTracking = true` requires at least one domain. An empty domain array
with tracking true is `ITMS-91064`, rejected at upload. The safest manifest is
the one here — tracking false, key absent.

In App Store Connect, the App Privacy section must therefore have **no "Data
Used to Track You"** entries. The app collects nothing: audio never leaves the
device and transcription is fully on-device.

**Do not add a mediation adapter without reading its `PrivacyInfo.xcprivacy`.**
Xcode unions SDK manifests into the app, so merely shipping a pod that declares
`NSPrivacyTracking = true` puts the whole app into ATT scope whether or not it
ever runs.

### Required-reason API declared

One entry in `NSPrivacyAccessedAPITypes`:

`NSPrivacyAccessedAPICategoryFileTimestamp`, reason **C617.1**.

`RecordingRepository.list()` calls `File.stat()` and reads `stat.modified` as a
fallback creation date for recordings whose filename has no parseable
timestamp. The files are inside the app container, which is what C617.1 covers.
If that call is ever removed, this entry should go too.

---

## What changed during the port

Only what was necessary. Everything below was verified with a real command.

### iOS-only
- `ios/` created from scratch with `flutter create --platforms=ios .`
  (no previous iOS folder existed — no legacy template to clean up).
- Bundle id corrected from the auto-derived `com.idatagear.momera.momeraAudio`.
- Deleted `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"` from all
  three configurations. The current Flutter template still ships this line, and
  it pins signing to a development identity — the cause of the misleading
  "your team has no devices from which to generate a provisioning profile"
  error when archiving. App Store distribution profiles need no registered
  device.
- `ios/Podfile`: uncommented `platform :ios, '13.0'`.
- `ios/Runner/Info.plist`: added `NSMicrophoneUsageDescription`,
  `ITSAppUsesNonExemptEncryption = false`, `UIBackgroundModes = [audio]`; set
  `CFBundleDisplayName` to `Momera.Audio`.
- `ios/Runner/PrivacyInfo.xcprivacy`: created and added to the Runner target's
  Resources build phase (verified present inside the built `.app`, not just on
  disk — a manifest that is not a target member is ignored by Apple).
- `ios/Runner/AppDelegate.swift`: added the backup-exclusion method channel.

### Shared (ships to Android too)
- `pubspec.yaml`: removed the unused `permission_handler` dependency; enabled
  iOS launcher icons with `remove_alpha_ios: true`.
- `lib/core/services/model_download_service.dart`: model path moved to
  Application Support; added `modelsRoot()`; added backup exclusion.
- `lib/utils/model_asset_helper.dart`: derives all model paths from
  `modelsRoot()`.
- `lib/presentation/screens/home_screen.dart`: `crossAxisAlignment:
  CrossAxisAlignment.stretch` on the body `Column`. **This is a bug fix with
  visible Android impact** — see below.
- `.metadata`: iOS platform registered.

### Traps hit during this port, for next time

- **`flutter create` silently re-resolved every dependency.** It pushed
  `sherpa_onnx` 1.13.2 → 1.13.7 — the speech engine — plus major bumps to
  `archive` (3→4) and `package_config` (2→3), and raised the Dart SDK floor.
  A port has no business upgrading the STT engine. `pubspec.lock` was reverted
  and `flutter pub get` confirmed the original resolution still holds. **Check
  `git diff pubspec.lock` immediately after running `flutter create`.**
- **`flutter create` also dropped the `android` platform entry from
  `.metadata`**, replacing it with `ios`. Restored, with Android's original
  `create_revision` preserved.
- **It did not clobber `test/widget_test.dart`.** The documented failure mode
  (a stock test referencing `MyApp`) did not occur here; the existing file came
  through byte-identical (`e54c02fd…`). Worth re-checking on the next port
  rather than assuming either way.
- **`DEVELOPMENT_TEAM` was populated automatically** as `6ZWZ3Z58ZT` from the
  keychain. It did not need setting by hand in Xcode.
- **Regenerating icons did not touch Android.** All 10 Android PNGs verified
  byte-identical by checksum before and after `dart run flutter_launcher_icons`.
  The icon master has no alpha channel to begin with (1254×1254, `hasAlpha: no`),
  so `remove_alpha_ios: true` is belt-and-braces rather than load-bearing — but
  it stays, because a future icon revision might reintroduce alpha.

---

## Size, and what the user actually downloads

| | |
|---|---|
| Android AAB | 95.4 MB |
| iOS `Runner.app` (device, uncompressed) | 49.0 MB |
| Model downloaded on first use | 239,233,841 bytes (~228 MiB) |

Both platforms are dominated by the sherpa-onnx native libraries. The iOS
figure is smaller because only the arm64 device slice ships.

**The model download is the number that matters for review.** A reviewer on a
fresh install must wait for ~228 MB before they can transcribe anything. Give
App Review explicit notes about this, and make sure the download UI clearly
shows progress — a reviewer who thinks the app has hung will reject it.

---

## Known gaps

- **Background recording is declared but not implemented.**
  `UIBackgroundModes: [audio]` is in `Info.plist`, but the app does not
  currently configure an audio session to keep recording when backgrounded, and
  Android has no foreground service. **This combination is itself a review
  risk**: Apple rejects apps that declare a background mode they do not use.
  Either finish the feature or remove the key before submitting.
- **Transcription runs on the main isolate.**
  `TranscriptionService.transcribeFile()` does the whole VAD + decode loop
  inline, blocking the UI thread for the duration. On a long recording this
  freezes the app, and on iOS a long enough block can trip the watchdog. It
  should move to `compute()`/an isolate.
- **Memory has not been measured on a low-RAM device.** The model plus the
  ONNX runtime against iOS jetsam limits is untested. Test on the oldest
  iOS 13-capable hardware you have.
- **iPad is deliberately off for v1.** See below.


---

## iPad: measured, then disabled for v1

`TARGETED_DEVICE_FAMILY = "1"` (iPhone only), changed from the template's
`"1,2"` in all three configurations.

This was **measured, not assumed**. The app was built for the simulator and run
on an iPad Pro 13-inch (M5):

- Nothing overflowed, nothing clipped, no layout exceptions.
- With the record-bar bug fixed (below), the layout is functional.
- But the empty state is a very large expanse of whitespace at 13", and the
  content has no max-width constraint, so lists stretch the full width.

It is off for v1 because enabling it obliges a full iPad screenshot set **in
every language** and puts iPad layouts in front of App Review — real work for a
device class this UI has not been designed for.

**Going `"1"` → `"1,2"` in a later release is easy.** Going the other way reads
as dropping device support and annoys users. Starting narrow is the reversible
choice.

To enable iPad later: set `TARGETED_DEVICE_FAMILY = "1,2"` in all three
configurations, add max-width constraints to the home screen body, and produce
13" iPad screenshots.

---

## Bug found during the port: the record bar was never full-width

**This was a real, pre-existing bug on both platforms, found by porting.**

`_RecordBar` in `lib/presentation/screens/home_screen.dart` is styled as a
bottom bar — surface fill, and a `Border(top:)` intended to run the width of the
screen. But its parent `Column` used the default
`CrossAxisAlignment.center`, which sizes children to their *intrinsic* width.
The bar therefore collapsed to the width of the words "Tap to record" and
rendered as a narrow white card floating above the bottom edge, with visible
hard left and right edges and a top border only as wide as the card.

It was first noticed on iPad, where it is glaring, but a screenshot on an
iPhone 15 Pro Max confirmed **the same bug on phones**. Since the widget tree is
shared, the Android build had it too.

Fixed with `crossAxisAlignment: CrossAxisAlignment.stretch` on the body
`Column`, verified by before/after screenshots on the iPhone simulator.

**Android runtime impact: the bottom bar now spans the screen width.** That is
the intended design and no shipped release ever showed the broken version, but
it is a visible change to the Android UI and should be eyeballed on a device.
