# Momera Recorder — App Store release checklist

Ordered so nothing below the blockers can usefully be started first.
The *why* for every configuration choice is in
[`release_guide.md`](release_guide.md).

**Last verified: 2026-09-05** against version `1.0.0+2`.

---

## 1. Hard blockers — account and portal work, none of it automatable

- [x] **Apple Distribution certificate exists.**
      Verified present: `Apple Distribution: ZhiJiang Zhang (6ZWZ3Z58ZT)`.
      ```bash
      security find-identity -v -p codesigning | grep -c "Apple Distribution"   # expect 1
      ```
- [x] **`DEVELOPMENT_TEAM` is set.** Already committed as `6ZWZ3Z58ZT` —
      Flutter picked it up from the keychain, so no manual Xcode step.
      ```bash
      grep -c "DEVELOPMENT_TEAM = 6ZWZ3Z58ZT" ios/Runner.xcodeproj/project.pbxproj  # expect 3
      ```
- [ ] **Create the App Store Connect app record** for bundle id
      `com.idatagear.momerarecording`.
      Must match exactly — it is **not** the id `flutter create` derives from
      the Dart package name.
- [ ] **Agreements, Tax and Banking** — accept the current Paid/Free Apps
      agreement. Not needed for a free app with no IAP, but it blocks
      *everything* if you later add one and can take more than a day to clear.
      Momera Recorder currently has **no in-app purchases**, so this is not a v1
      blocker.
- [ ] *(not applicable)* In-app purchase products — the app has none.
- [ ] *(not applicable)* AdMob console app and ad units — the app serves no ads.

---

## 2. Configuration — all verified, each with the command that proves it

Everything in this section is **already done**. The commands are here so you can
re-prove it after any change, not because anything is outstanding.

- [x] **Bundle id matches Android.**
      ```bash
      grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.idatagear.momerarecording;" ios/Runner.xcodeproj/project.pbxproj  # expect 3
      ```
- [x] **Deployment target is 15.5 in both places.** Raised from 13.0 by
      `google_mlkit_translation`; see the guide for why and how to reverse it.
      ```bash
      grep -c "IPHONEOS_DEPLOYMENT_TARGET = 15.5" ios/Runner.xcodeproj/project.pbxproj  # expect 3
      grep -n "^platform :ios, '15.5'" ios/Podfile                                      # expect 1 hit
      ```
- [x] **No legacy signing pin.** This is what causes the misleading "your team
      has no devices from which to generate a provisioning profile" on archive.
      ```bash
      grep -c "iPhone Developer" ios/Runner.xcodeproj/project.pbxproj   # expect 0
      ```
- [x] **iPhone only for v1.**
      ```bash
      grep -c 'TARGETED_DEVICE_FAMILY = "1";' ios/Runner.xcodeproj/project.pbxproj  # expect 3
      ```
- [x] **Microphone usage description present.** Missing this is a *crash* on
      first record, not a denied prompt.
      ```bash
      plutil -extract NSMicrophoneUsageDescription raw -o - ios/Runner/Info.plist
      ```
- [x] **Encryption declaration present**, so uploads don't stall on the export
      compliance question.
      ```bash
      plutil -extract ITSAppUsesNonExemptEncryption raw -o - ios/Runner/Info.plist  # expect false
      ```
- [x] **Privacy manifest is a member of the Runner target.** A manifest that is
      merely on disk is ignored by Apple. Check the *built app*, not the source:
      ```bash
      ls build/ios/iphoneos/Runner.app/PrivacyInfo.xcprivacy
      ```
- [x] **No tracking, all four checks.**
      ⚠️ The `-o -` is not optional — without it `plutil -extract` **overwrites
      the file** with the extracted value.
      ```bash
      grep -c NSUserTrackingUsageDescription ios/Runner/Info.plist                 # expect 0
      plutil -extract NSPrivacyTracking raw -o - ios/Runner/PrivacyInfo.xcprivacy  # expect false
      grep -rnE "app_tracking_transparency|gma_mediation_meta" pubspec.yaml        # expect no output
      grep -rnE "TrackingAuthorization|TrackingStatus" lib/                        # expect no output
      ```
- [x] **1024 icon has no alpha channel.** An alpha channel gets the binary
      rejected by email hours after upload, not at submit time.
      ```bash
      sips -g hasAlpha ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png  # expect no
      ```

### Still on a placeholder

- [ ] **Version is `1.0.0+2`.** Fine for the first submission. Remember that
      **App Store Connect reserves a build number permanently, even if you
      delete the build** — a failed upload means bump the *build* number
      (to `1.0.0+3`, and so on), not the version.

---

## 3. Physical-device testing

The simulator cannot exercise the microphone meaningfully, and cannot tell you
anything about memory pressure. **Test on real hardware before submitting.**

- [ ] **Fresh install, first launch** — the microphone prompt appears and shows
      the expected wording, and the app does not crash on tapping record.
- [ ] **Negative tracking check** — **no App Tracking Transparency prompt
      appears at any point.** There should be none; confirm there is none.
- [ ] **Model download** — ~228 MB completes, shows sane progress, and survives
      backgrounding. Then confirm the resume path: kill the app mid-download and
      relaunch.
- [ ] **Model lands outside `Documents/`.** In Xcode → Devices → the app
      container, confirm the model is under `Library/Application Support/models/`
      and that `Documents/` holds only recordings.
- [ ] **Record → stop → transcribe** end to end, and confirm the transcript
      sidecar survives a relaunch.
- [ ] **Memory on the oldest device you have.** The model plus the ONNX runtime
      against iOS jetsam limits is **untested**. This is the most likely source
      of a device-only crash.
- [ ] **Long-recording UI freeze.** Transcription currently runs on the main
      isolate — see "Bugs" in the guide. Transcribe a long recording and see how
      bad the block is.
- [ ] **Audio session interaction** — take a phone call mid-recording, and play
      audio in another app, and confirm sane behaviour.

---

## 4. Store listing

**Run `/idatagear-apple-store-assets`.** That command owns the 1024 icon, the
screenshots in every language, the description, subtitle, promotional text,
keywords, What's New, and the App Store Connect submission answers. Do not write
listing copy here.

Three facts it will need from this port:

- **iPhone only** — no iPad screenshots required. `TARGETED_DEVICE_FAMILY = "1"`.
- **Four languages ship: English, Spanish, Simplified Chinese, Traditional
  Chinese.** Screenshots and listing copy are needed for all four, not English
  alone.
- **App Privacy: nothing is collected.** No data leaves the device; transcription
  is fully on-device. There must be **no** "Data Used to Track You" section.

- [ ] Listing produced and uploaded.
- [ ] **App Review notes mention the model download.** A reviewer on a fresh
      install waits for ~228 MB before they can transcribe anything. Say so
      explicitly, or it reads as a hang.

- [ ] **⚠️ The primary model URL is dead — fix before release.** Verified
      2026-09-05:
      ```bash
      curl -sSI -L "https://github.com/zhangzhijiang/momera/releases/download/sensevoice_small_model_v20240717/model.int8.onnx"
      #   HTTP/2 404          <- our "own pinned CDN" does not exist
      curl -sSI -L "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx"
      #   HTTP/2 200, content-length: 239233841   <- matches expectedBytes exactly
      ```
      `ModelDownloadService.modelUrls` lists the GitHub release first and calls
      it "our own pinned GitHub Release asset (stable, version-locked)", but
      that release does not exist. Every first-run download therefore burns a
      404 before falling back, and **the app depends entirely on a third-party
      HuggingFace URL** it does not control — if that is rate-limited, moved or
      taken down, no user can transcribe anything. Either publish the release
      that URL points at, or remove it and add a CDN you actually own.

---

## 5. Build and upload

- [ ] `flutter build ipa --release`
- [ ] Upload `build/ios/ipa/*.ipa` via Transporter or Xcode Organizer.
- [ ] TestFlight verification:
  - [ ] Microphone permission prompt on a fresh install
  - [ ] Record, stop, play back
  - [ ] Model download and offline transcription
  - [ ] **No ATT prompt at any point**
  - [ ] App does not crash under sustained recording

> There is no purchase/restore flow, no ads, and no UMP consent flow to verify —
> the app has none of those.

---

## 6. Don't forget Android

The port changed these **shared** files. Nothing has shipped to Play yet, so
there is no installed base at risk, but each one ships to Android in the next
build and should be exercised on a device.

| File | What could differ on Android at runtime |
|---|---|
| `lib/core/services/model_download_service.dart` | **Model moved from `Documents/` to the app-support directory.** Any model downloaded by an older local build is orphaned and re-downloads (~228 MB). Verify download, resume and delete all still work. |
| `lib/utils/model_asset_helper.dart` | `tokens.txt` and the VAD model now unpack under the new root. Verify transcription still initialises. |
| `lib/presentation/screens/home_screen.dart` | **The bottom record bar now spans the full screen width** (it was collapsing to a narrow card). Purely visual, and it is the intended design — but eyeball it. |
| `pubspec.yaml` | `permission_handler` removed. It was never imported anywhere, so no runtime effect is expected — confirm the mic permission flow still works, since `record` handles it natively. |
| `pubspec.yaml` (icons) | iOS icon generation enabled. All 10 Android PNGs verified **byte-identical** by checksum — no Android icon change. |
| `lib/main.dart` | Now resolves and applies a UI locale. Android picks up the device language; verify a Chinese device shows the right script. |
| `lib/presentation/screens/home_screen.dart` (settings action) | New gear icon in the app bar opening the settings screen. |
| `lib/presentation/widgets/recording_tile.dart` | **Dates are now locale-formatted** rather than a hardcoded English pattern. An English device should look unchanged; a Chinese or Spanish device will show localised dates. |
| `lib/presentation/widgets/model_download_sheet.dart` | Strings localised only; no behaviour change. |
| `pubspec.yaml` (`shared_preferences`, `flutter_localizations`) | New plugins. `shared_preferences` adds an Android SharedPreferences dependency; settings must persist across a cold start. |
| `.metadata` | Tooling metadata only, no runtime effect. |

Android re-test list:

- [ ] Record → stop → play back
- [ ] Model download, including resume after a kill
- [ ] Transcription end to end
- [ ] Microphone permission on a fresh install
- [ ] Bottom bar renders full-width and looks right
- [ ] Settings persist across a force-quit and relaunch
- [ ] Switching UI language takes effect immediately and survives a relaunch
- [ ] A device set to Chinese shows the correct script (Simplified vs Traditional)

Android gate, re-run after **every** change (not once at the end):

```bash
flutter analyze
flutter test
flutter build appbundle --release
git status --short lib/ android/
```

Last run 2026-09-05: analyze clean, **81/81 tests pass**,
`✓ Built app-release.aab (141.7MB)`.

- [x] **Real Play download size — measured, no problem.** The 141.7 MB AAB is
      not the number that matters: 59 MB of it is `BUNDLE-METADATA` that is
      never shipped, and it carries three ABIs where a device receives one.
      **An arm64 phone downloads ≈ 29.7 MB.** Nowhere near a Play limit.
      Re-measure only if a large dependency is added:
      ```bash
      python3 -c "import zipfile,collections;z=zipfile.ZipFile('build/app/outputs/bundle/release/app-release.aab');\
      g=collections.defaultdict(int);[g.__setitem__(i.filename.split('/')[2] if i.filename.startswith('base/lib/') else 'shared', \
      g[i.filename.split('/')[2] if i.filename.startswith('base/lib/') else 'shared']+i.compress_size) \
      for i in z.infolist() if not i.filename.startswith('BUNDLE-METADATA')];print(g)"
      ```

---

## 7. Background recording — implemented, needs device testing

Recording now continues while backgrounded and while the screen is locked, and
stops only when the user asks. `UIBackgroundModes: [audio]` is therefore backed
by a feature that genuinely uses it, which removes the earlier "declares a
background mode it does not use" rejection risk.

The storage cap and auto-save interval from settings are now enforced.

**None of this has been exercised on physical hardware.** The simulator cannot
tell you anything useful about lock-screen audio, foreground services or
interruptions. Test on real devices:

- [ ] **iOS: lock the screen mid-recording**, wait a few minutes, unlock —
      recording is still running and the audio is continuous.
- [ ] **iOS: background the app** (home gesture), return — still recording.
- [ ] **iOS: incoming phone call** while recording. Ringing must not interrupt;
      answering pauses and hanging up resumes
      (`AudioInterruptionMode.pauseResume`).
- [ ] **Android: lock the screen mid-recording** — the notification is visible
      on the lock screen with a live elapsed time.
- [ ] **Android: Stop from the notification** ends the recording and the file
      is playable.
- [ ] **Android 13+: deny the notification permission**, then record — the
      recording still works (just with no notification).
- [ ] **Crash recovery**: force-quit mid-recording, relaunch. A recording
      appears containing everything up to the last flush (≤10 s lost).
- [ ] **Storage cap**: set the cap to 512 MB, record until it is hit. Recording
      stops, the audio is kept and playable, and the message names the limit.
- [ ] **Battery**: record for 30+ minutes locked and check the drain is sane.
