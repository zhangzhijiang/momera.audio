# Play Console submission answers — Momera Recorder

Every non-graphic field and declaration the Console gates a release on, answered
from the code rather than from memory. Where an answer is a judgement call, the
reasoning is given so you can overrule it.

* **Package** `com.idatagear.momerarecording`
* **minSdk 24** (Android 7.0) · **targetSdk 36** · **compileSdk 36**
* Verified against `android/app/build.gradle.kts`, `AndroidManifest.xml`,
  `pubspec.yaml` and `lib/` on 9 September 2026.

---

## 1. Store listing

Text lives in [`listing.md`](listing.md) — app name, short description, full
description and release notes for `en-US`, `ja`, `ko`, `zh-CN`, `zh-TW`.

| Field | Value |
|---|---|
| App name (≤30) | `Momera Recorder` (15) |
| Category | Tools *(alternative: Productivity — Tools is the better fit; this is a recorder, not a workflow app)* |
| Tags | Voice recorder, Transcription, Notes |
| Contact email | zhangzhijiang@gmail.com |
| Website | *(none yet — optional, but a privacy-policy URL is not; see below)* |
| Privacy policy URL | **REQUIRED, AND MISSING.** See §7. |

---

## 2. Data safety

**Answer: no data collected, no data shared.**

The reasoning, because this is the section that gets apps rejected:

Play defines "collection" as data **transmitted off the device**. Momera
Recorder transmits none. `http` appears in exactly one file in `lib/` —
`core/services/model_download_service.dart` — and it performs a `GET` for the
speech model. It sends no body, no identifiers and no audio. There is no
analytics SDK, no crash reporter, no ad SDK and no account system anywhere in
`pubspec.yaml`.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | *(not asked once you answer No above)* |
| Do you provide a way for users to request that their data is deleted? | *(not asked)* |

Three things a reviewer might query, pre-answered:

* **Audio recordings.** Created and stored only in the app's private storage
  (`Documents/recordings`). Never uploaded. On-device-only data is explicitly
  out of scope for the Data safety declaration.
* **Speech-to-text.** Runs locally via the downloaded model. No audio is sent
  anywhere for recognition — including the live text shown while recording.
* **Sharing.** `share_plus` hands a file or some text to Android's share sheet,
  and the clipboard copy is local. Both are user-initiated transfers to an app
  the user picks, which Play does not treat as collection or sharing by you.
  Nothing is transferred without an explicit tap.

---

## 3. Foreground service declaration — do not skip this one

The app declares `FOREGROUND_SERVICE_MICROPHONE` and
`android:foregroundServiceType="microphone"` on `.RecordingService`
(`AndroidManifest.xml:18,59`). Since Android 14, Play requires a **separate
declaration form** in the Console for every foreground service type, and a build
that ships an undeclared type is rejected at review.

| Field | Answer |
|---|---|
| Foreground service type used | **Microphone** |
| What is the feature? | Continuing an audio recording the user explicitly started, while the app is in the background or the screen is locked. |
| Why does it need a foreground service? | Android does not permit microphone capture from the background without one. Without it, leaving the app or locking the screen silently truncates the recording — the exact failure a voice recorder must not have. |
| Why can't you use an alternative (WorkManager, JobScheduler)? | Those are for deferrable work. This is continuous real-time audio capture that must not be deferred, batched or interrupted. |
| Is it user-initiated and visible? | Yes. It starts only when the user taps record, shows a persistent notification with a Stop action for its whole lifetime, and `android:stopWithTask="true"` ends it if the task is dismissed. |

You will need a short screen recording of the flow (tap record → leave the app →
notification visible → stop from the notification) for the form's video field.

---

## 4. Ads, content rating, target audience

| Declaration | Answer |
|---|---|
| Does your app contain ads? | **No.** No ad SDK in `pubspec.yaml`; no AdMob app id in the manifest. |
| In-app purchases | **None.** No billing dependency. |
| Content rating questionnaire (IARC) — category | **Utility, Productivity, Communication or Other** |
| Violence / sexuality / language / controlled substances | **None** to all |
| Does the app allow users to interact or exchange content? | **No.** There is no network feature, no accounts, no user-to-user anything. |
| Does the app share the user's location? | **No** |
| Does the app allow users to purchase digital goods? | **No** |
| Expected rating | **Everyone / PEGI 3 / 全年齢** |
| Target age group | **18 and over** *(any selection including under-13 pulls the app into the Families policy and its extra review; nothing here is aimed at children, so keep it out)* |
| Appeals to children? | **No** |

---

## 5. App access

**All functionality is available without any special access.**

There is no login, no region lock, no paywall and no code-gated feature. Tick
"All functionality is available without special access" and provide no
credentials.

The one thing a reviewer should be told, in the review-notes box:

> Transcription requires a one-time ~228 MB speech-model download, which the app
> offers the first time you tap "Transcribe". The device needs an internet
> connection for that download only; everything afterwards, including
> transcription, works offline. Recording, playback, renaming, sharing and
> name-search all work without it.

---

## 6. Permissions justification

Volunteer these in review notes; every one is used and none is broad.

| Permission | Justification |
|---|---|
| `RECORD_AUDIO` | The app is a voice recorder. |
| `INTERNET` | Downloads the speech model once. No other network use. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE` | Background recording; see §3. |
| `POST_NOTIFICATIONS` | The recording notification. Recording still works if denied. |
| `WAKE_LOCK` | Held only while recording, so device sleep cannot cut audio off. |

The app requests **no** location, camera, contacts, shared-storage or
`QUERY_ALL_PACKAGES` permission — worth saying explicitly, because a recorder
asking for none of those is unusual enough to be reassuring.

---

## 7. Blocking gap: privacy policy URL

Play requires a **publicly reachable privacy policy URL** for every app,
regardless of whether it collects data. There is no URL and no hosted page for
this app anywhere in the repo.

The policy text is written and ready:
[`../shared/legal/privacy_policy.md`](../shared/legal/privacy_policy.md). It has
to be **hosted** and the URL pasted into the Console. Cheapest routes:

* GitHub Pages on the existing repo, or a Gist rendered through a Pages site
* Any static host — it is one page with no assets

This is the one item on this page that will stop a submission outright.

---

## 8. Pre-launch checks worth doing

* **Upload an App Bundle, not an APK.** `flutter build appbundle --release`.
  The 146 MB release APK is a single fat binary; Play splits the AAB per ABI and
  the actual install is far smaller.
* **16 KB page size.** Play requires 16 KB-aligned native libraries for apps
  targeting Android 15+. This build was captured on a 16 KB-page emulator
  (`sdk_gphone16k_arm64`, Android 17) and the app ran, with the
  sherpa-onnx native probe passing — the transcription UI stays visible, which
  `DeviceCapabilityService` only allows when `initBindings()` loaded. That is
  good evidence, but it is not a substitute for
  `zipalign -c -P 16 -v 4 <aab/apk>` before you ship.
* **Signing.** `android/key.properties` is machine-local and gitignored; a fresh
  clone will fail `validateSigningRelease` until it is recreated.
* **Tablet screenshots are optional and currently unwise.** See the note in
  [`README.md`](README.md).
