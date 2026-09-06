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

Version is `1.0.0+2` (`pubspec.yaml`). Neither store has a released build yet.

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
| Privacy manifest | n/a | `ios/Runner/PrivacyInfo.xcprivacy` | Apple-only requirement. `shared_preferences_foundation` ships its own manifest declaring UserDefaults access (reason `1C8F.1`) with tracking false; Xcode unions SDK manifests, so ours needs no UserDefaults entry. |
| Background recording | Foreground service (`RecordingService.kt`) with a persistent notification | `UIBackgroundModes: [audio]` + the plugin's AVAudioSession | Entirely different platform mechanisms for the same behaviour. Android *requires* a visible notification; iOS shows its own indicator and needs no UI. |
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

**Two plugins independently require 13.0.**

| Plugin | iOS floor |
|---|---|
| **`sherpa_onnx_ios` 1.13.2** | **13.0** ← binding constraint |
| **`shared_preferences_foundation` 2.5.7** | **13.0** ← also binding |
| `record_ios` 1.2.1 | 12.0 |
| `just_audio` 0.10.5 | 12.0 |
| `audio_session` 0.2.3 | 12.0 |
| `permission_handler_apple` | 12.0 *(dependency since removed)* |

**The runner-up is 12.0**, but getting there now needs *both* constraints gone.
Originally only `sherpa_onnx_ios` held the floor; `shared_preferences_foundation`
arrived with the settings screen and requires 13.0 too. So replacing the speech
engine alone would no longer let the target drop — settings persistence would
have to move to a plain JSON file via `path_provider` as well.

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


---

## Settings screen and localization

Added after the port proper. Four UI languages ship: **English, Spanish,
Simplified Chinese, Traditional Chinese**.

### How the locales are wired

Translations live in `lib/l10n/*.arb` and are code-generated into
`lib/l10n/app_localizations.dart` by `flutter gen-l10n`, driven by `l10n.yaml`
and `generate: true` in `pubspec.yaml`. The generated files are committed.

**Simplified Chinese is plain `zh`, not `zh-Hans`.** gen-l10n derives the locale
from the ARB filename, so `app_zh.arb` becomes `Locale('zh')` while
`app_zh_Hant.arb` becomes `Locale.fromSubtags(languageCode: 'zh', scriptCode:
'Hant')`. `AppLanguage.chineseSimplified` must therefore use `Locale('zh')` —
using `zh-Hans` hands `MaterialApp` a locale absent from
`AppLocalizations.supportedLocales`. There is a test pinning this.

`MomeraAudioApp.resolveLocale` handles device locales we do not translate
exactly:

- **Chinese is matched first, before the generic exact match.** This is not
  cosmetic ordering. Since Simplified is plain `zh` with a null script code, a
  device set to `zh-TW` matches `zh` on language *and* script (both null) and
  would be served **Simplified text on a Traditional device**. That bug was
  written, caught by a test, and fixed — do not "simplify" this ordering.
- `zh-HK`, `zh-MO`, `zh-TW` and any `Hant` script → Traditional. All other
  Chinese → Simplified.
- Regional variants fall back to the base language (`es-MX` → `es`).
- Anything untranslated, or a null device locale, falls back to English.

### Settings

Persisted with `shared_preferences`; reads are defensive so a corrupt or
missing value falls back to the default rather than throwing at launch.

| Setting | Default | Notes |
|---|---|---|
| Language | System | Falls back to English for untranslated device languages |
| Maximum storage | 2 GB | ~18 h at 16 kHz mono PCM16 (~1.83 MB/min) |
| Auto-save interval | 10 s | A crash loses at most this much audio |

The settings screen also shows current usage against the cap — a limit with no
visible usage figure is hard to set sensibly.

> **The storage cap and auto-save interval are stored and displayed but not yet
> enforced.** Nothing in the recording pipeline reads either value. They become
> live as part of the background-recording work. Until then they are inert
> preferences, which is a UI-honesty problem: the app shows controls that do
> nothing.

### Consequence for the store listing

The app now ships in four languages, so `/idatagear-apple-store-assets` must
produce screenshots and listing copy for **en, es, zh-Hans, zh-Hant** — not
English alone.


---

## Background recording

Recording continues while the app is backgrounded **and while the screen is
locked**, and stops only when the user asks — from the app, or from the Android
notification's Stop action.

This also resolves what was a submission risk: `UIBackgroundModes: [audio]` is
now backed by a feature that genuinely uses it. Apple rejects apps that declare
a background mode they do not exercise.

### Why raw PCM on disk

Audio is streamed from the microphone as PCM and appended to a `.pcm` file,
flushed on the interval from settings. A WAV header is prepended only when the
recording is finalised, at which point it becomes `.wav`.

The obvious alternative — let the plugin write a WAV directly, or write WAV
segments and concatenate — is worse in two specific ways:

1. **Concatenated WAVs embed 44-byte headers mid-stream.** Those bytes are not
   audio. They produce clicks on playback and get fed to the VAD as noise.
2. **A WAV whose header was never finalised is a repair job.** A raw PCM stream
   is not: whatever bytes survived are valid audio, so recovery is "prepend a
   header for the length on disk". `AudioRecordingService.recoverInterrupted()`
   runs at startup and does exactly that for any `.pcm` left behind.

The consequence is the crash-safety guarantee: **a crash, force quit or battery
death loses at most one flush interval** (10 s by default).

Byte counting also makes the storage cap exact — the final chunk is trimmed so
the cap is honoured precisely rather than overshot by up to one buffer.

### Android: the foreground service

`android/app/src/main/kotlin/com/idatagear/momera/audio/RecordingService.kt`.

Android will not let an app record from the background indefinitely. A
foreground service is the sanctioned mechanism, and the platform **requires a
persistent, non-dismissable notification** for the service's whole lifetime —
that is how a user can always tell an app is recording. It is not optional and
cannot be hidden.

- Service type `microphone`, declared in both the manifest and the
  `startForeground` call (mandatory from Android 14).
- Permissions added: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`,
  `POST_NOTIFICATIONS`.
- The notification's text comes from Dart so it is localised with the rest of
  the UI, and carries a **Stop** action. A Stop tap is forwarded to Dart via
  `stopRequested`, because Dart owns the recorder and the file being written —
  the service never touches the microphone itself.

`POST_NOTIFICATIONS` is requested at runtime on first record (Android 13+).
Recording proceeds either way: a denied grant only means the notification is
not shown, so the user loses the indicator and the Stop action but keeps the
recording.

### iOS: let the plugin own the audio session

`AppDelegate` deliberately does **not** configure `AVAudioSession`.

`record_ios` manages the shared session itself — it sets `.playAndRecord` with
the options from `RecordConfig.iosConfig` when capture starts. An `AppDelegate`
that also set a category would simply be overwritten, and two owners of one
audio session is how intermittent, unreproducible audio bugs happen. Session
options are configured from Dart instead.

What actually keeps capture alive when the screen locks is
`UIBackgroundModes: audio` plus the plugin's active session. The method channel
still exists on iOS so the Dart side is uniform, but its handlers are no-ops.

### Surviving a phone call

`AudioInterruptionMode.pauseResume`, not the plugin's default.

The default is `pause`: capture stops on interruption and waits for a **manual**
resume that this app never issues — so an incoming call would silently end a
recording that the user believes is still running. That directly contradicts
"record until the user taps stop". `pauseResume` resumes capture by itself.

`allowHapticsAndSystemSoundsDuringRecording: true` additionally means a *ringing*
call no longer interrupts at all — only actually answering one does.

### Storage cap

Stop-and-warn, never evict. When recordings reach the configured cap the
recording is finalised (audio up to that point is kept) and the user is told.
The app never deletes recordings to make room — silently destroying a user's
audio is not a decision it gets to make.

The budget is computed at start as `cap - bytes already used`, and
`RecordingRepository.totalBytes()` counts the in-progress `.pcm` too, so the
accounting stays honest during a recording.


---

## Speech recognition: languages

The model is `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17`. It supports
**five** languages and no others:

| Code | Language |
|---|---|
| `zh` | Mandarin Chinese |
| `yue` | Cantonese |
| `en` | English |
| `ja` | Japanese |
| `ko` | Korean |

The token vocabulary contains tags for many more languages (`es`, `de`, `fr`,
…), inherited from the vocabulary the model was built on. **The checkpoint is
not trained for them.** Do not read the vocabulary as a capability list.

### UI languages mirror the model's languages — resolved

Spanish was dropped. The UI now ships in exactly the languages the recogniser
can transcribe, so the interface is never offered in a language whose speech the
app cannot handle:

| UI locale | Serves |
|---|---|
| `en` | English |
| `zh` | Mandarin (Simplified) |
| `zh-Hant` | **Cantonese** and Traditional readers — there is no separate written Cantonese locale; Hong Kong and Macau read Traditional |
| `ja` | Japanese |
| `ko` | Korean |

A device set to Spanish, French, German, etc. falls back to English.

### Auto-detection is per speech segment

`OfflineSenseVoiceModelConfig.language` defaults to `''`, which means detect.
Because transcription runs Silero VAD first and decodes **each speech segment
independently**, language identification also happens per segment — so a
conversation that switches language between utterances transcribes correctly,
each utterance in its own language.

Within a single utterance that code-switches mid-sentence, one language wins;
the vocabulary has `<|zh/en|>` tags for that case but the result carries one
label per segment.

The detected language comes back on `OfflineRecognizerResult.lang` (it was
being discarded). It is now collected in first-seen order, persisted with the
transcript, and shown on the recording tile — so a bilingual recording visibly
lists both.

The **Spoken language** setting pins the recogniser to one language instead.
Changing it rebuilds the recogniser, because the language is baked in at
construction.

### Transcript sidecars are JSON

Storing detected languages meant the `<name>.txt` sidecar became JSON
(`{"text": ..., "languages": [...]}`). The reader still accepts the old
plain-text form, so transcripts written before this change are not lost.


---

## Search

Search covers recording names and transcript text, and returns **hits within a
recording** — tapping one seeks playback to the moment the words were spoken.

### It is a plain scan, deliberately

No index, no database. Transcripts are small and the list is already in memory,
so a `contains` over what is loaded is the right tool until there are thousands
of recordings. SQLite FTS would add a schema, a dependency and a migration for
no user-visible gain today.

### Timed segments

`TranscriptSegment {start, end, text, language}` is captured during
transcription and stored in the transcript sidecar. The data was already there
and being discarded: the VAD reports `SpeechSegment.start` (a sample offset) for
every phrase it emits, and the recogniser reports the language per segment.

Transcripts written before segments existed still match — they just cannot offer
a seek position. The sidecar reader handles all three historical shapes (plain
text, JSON without segments, JSON with segments).

### ⚠️ Traditional/Simplified folding is load-bearing

`lib/core/search/han_variants.dart` folds Traditional Han to Simplified before
comparing, in **both** the query and the text.

This is not a nicety. The app ships both Chinese scripts and transcribes
Mandarin and Cantonese, so the same words are routinely written both ways —
without folding, searching 會議 would not find a transcript containing 会议.
That is the single most likely way search would appear broken to a
Chinese-speaking user, and it is verified end to end on the simulator.

The table is a **curated subset** (~660 rules), not a general converter. It:

- does not handle one-to-many mappings (乾/幹/干 all fold to 干), which is fine
  for substring matching but **must never be used to convert displayed text**;
- passes unknown characters through unchanged, so an incomplete table degrades
  to "this character matches only itself" rather than to a wrong result.

Extend it by appending a pair to `_pairs`. It was built by auditing common words
against the table rather than by guesswork — the first pass silently omitted
會, 沒, 麼, 後, 數 and 辦, which the audit caught.

### What search cannot do, and why users will notice

**Only transcribed recordings are searchable by speech.** Transcription is a
manual per-recording action, so a user who records twenty things and transcribes
two will search and conclude search is broken. The empty-results screen says so
explicitly rather than just showing "no results".

Making this go away means auto-transcribing after each recording, which costs
real CPU and battery — significant after a multi-hour background recording — and
cannot happen until the 228 MB model is downloaded. **That is a product
decision, not an implementation detail.**

Also: `useInverseTextNormalization` is enabled, so spoken numbers are stored as
digits — "twenty twenty six" is in the transcript as "2026", and searching the
words will not find it.
