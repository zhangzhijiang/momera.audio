# Momera.Audio — App Store release checklist

Ordered so nothing below the blockers can usefully be started first.
The *why* for every configuration choice is in
[`release_guide.md`](release_guide.md).

**Last verified: 2026-09-05** against version `1.0.0+1`.

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
      `com.idatagear.momera.audio`.
      Must match exactly — it is **not** the auto-derived
      `com.idatagear.momera.momeraAudio`.
- [ ] **Agreements, Tax and Banking** — accept the current Paid/Free Apps
      agreement. Not needed for a free app with no IAP, but it blocks
      *everything* if you later add one and can take more than a day to clear.
      Momera.Audio currently has **no in-app purchases**, so this is not a v1
      blocker.
- [ ] *(not applicable)* In-app purchase products — the app has none.
- [ ] *(not applicable)* AdMob console app and ad units — the app serves no ads.

---

## 2. Configuration — all verified, each with the command that proves it

Everything in this section is **already done**. The commands are here so you can
re-prove it after any change, not because anything is outstanding.

- [x] **Bundle id matches Android.**
      ```bash
      grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.idatagear.momera.audio;" ios/Runner.xcodeproj/project.pbxproj  # expect 3
      ```
- [x] **Deployment target is 13.0 in both places.**
      ```bash
      grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0" ios/Runner.xcodeproj/project.pbxproj  # expect 3
      grep -n "^platform :ios, '13.0'" ios/Podfile                                      # expect 1 hit
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

- [ ] **Version is `1.0.0+1`.** Fine for the first submission. Remember that
      **App Store Connect reserves a build number permanently, even if you
      delete the build** — a failed upload means bump the *build* number
      (`1.0.0+2`), not the version.

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

Two facts it will need from this port:

- **iPhone only** — no iPad screenshots required. `TARGETED_DEVICE_FAMILY = "1"`.
- **App Privacy: nothing is collected.** No data leaves the device; transcription
  is fully on-device. There must be **no** "Data Used to Track You" section.

- [ ] Listing produced and uploaded.
- [ ] **App Review notes mention the model download.** A reviewer on a fresh
      install waits for ~228 MB before they can transcribe anything. Say so
      explicitly, or it reads as a hang.

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
| `.metadata` | Tooling metadata only, no runtime effect. |

Android re-test list:

- [ ] Record → stop → play back
- [ ] Model download, including resume after a kill
- [ ] Transcription end to end
- [ ] Microphone permission on a fresh install
- [ ] Bottom bar renders full-width and looks right

Android gate, re-run after **every** change (not once at the end):

```bash
flutter analyze
flutter test
flutter build appbundle --release
git status --short lib/ android/
```

Last run 2026-09-05: analyze clean, 1/1 tests pass,
`✓ Built app-release.aab (95.4MB)`.

---

## 7. Not yet done — background recording

`UIBackgroundModes: [audio]` **is already declared in `Info.plist`, but the
feature is not implemented.** Apple rejects apps that declare a background mode
they do not use, so this is a live submission risk.

Either finish the feature or remove the key before submitting. Tracked
separately from the port.
