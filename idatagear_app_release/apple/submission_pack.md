# App Store Connect submission pack — McRecorder

Every text field App Store Connect gates submission on, derived from the code on
**10 September 2026** and not from the older docs in this repo.

> **Renamed 2026-09-10: `Momera Recorder` → `McRecorder`.** Name strings only —
> no logic changed. `CFBundleDisplayName`, `android:label`, `MaterialApp.title`,
> `appTitle` in all five ARB files, the microphone usage description and the
> Android notification-title fallback all now read `McRecorder`; the bundle id,
> the Android package and the Dart package name are deliberately unchanged.
> `flutter analyze` is clean and **194/194 tests pass**.

| | |
|---|---|
| App name | **McRecorder** — `ios/Runner/Info.plist` `CFBundleDisplayName` |
| Bundle id | **`com.idatagear.momerarecording`** — `ios/Runner.xcodeproj/project.pbxproj:488` |
| Version | **`1.0.0`** (build 9) — `pubspec.yaml:4` `version: 1.0.0+9` |
| Platforms | **iOS only.** There is no `macos/` directory. |
| Device family | **iPhone only** — `TARGETED_DEVICE_FAMILY = 1` (3 occurrences) |
| Deployment target | iOS 15.5 — `IPHONEOS_DEPLOYMENT_TARGET`, `ios/Podfile:2` |
| Localizations | **5** — `en-US`, `ja`, `ko`, `zh-Hans`, `zh-Hant` (from `lib/l10n/app_{en,ja,ko,zh,zh_Hant}.arb`) |
| In-app purchases | **None.** No `in_app_purchase` dependency, no `.storekit` file anywhere in the repo. |
| Ads / analytics / crash SDK | **None.** No `google_mobile_ads`, no `firebase_*`, no attribution SDK. |
| Tracking | **None**, consistent across all four places (§8) |

---

## Findings — read this before pasting anything

### F1. There are no in-app purchases, so §1, §2 and §6 do not apply

`pubspec.yaml` has no `in_app_purchase` dependency, `find ios -name "*.storekit"`
returns nothing, and `grep -c "Configuration.storekit in Resources"
ios/Runner.xcodeproj/project.pbxproj` returns `0`. There is no paywall file, no
product-id config class, and no entitlement state anywhere in `lib/`.

This matters for more than tidiness. The **Guideline 3.1.2 Terms of Use (EULA)
requirement applies to apps that offer auto-renewable subscriptions.** This app
offers none, so pasting a subscription-renewal disclosure block into the
description would itself be inaccurate metadata under **Guideline 2.3.1**.
§6 below records the decision and the proof rather than the block.

Keep the App Store Connect **EULA field on *Standard***. The hosted terms page
(§7) explicitly defers to Apple's Standard EULA, so the listing, the page and
the console all name the same agreement.

### F2. BLOCKER — the privacy policy URL does not exist yet

App Store Connect requires a privacy policy URL for **every** app, purchases or
not. Nothing is served at a McRecorder policy URL today:

```
https://www.idatagear.com/privacy-policy-mcrecorder.html  ->  404
```

There is **no privacy URL constant compiled into the binary** — `grep -rniE
"https?://" lib/` returns exactly two hits, both in
[model_download_service.dart:33-35](../../lib/core/services/model_download_service.dart#L33-L35),
and neither is a legal URL. So the path is not yet fixed by shipped code and you
are free to choose it; once chosen it is what the console and the listing must
both carry.

I have written the page to
[`../shared/legal/privacy-policy-mcrecorder.html`](../shared/legal/privacy-policy-mcrecorder.html)
— see §7. It must be deployed and return **200** before submission, because the
descriptions below link to it.

### F3. STALE DOC (now FIXED in that file) — `release_checklist.md` named a language the app does not have

[`release_checklist.md`](release_checklist.md) §4 says:

> **Four languages ship: English, Spanish, Simplified Chinese, Traditional Chinese.**

All four claims in that sentence are wrong. There is **no Spanish ARB**, and
there are **five** localizations, including Japanese and Korean:

```
lib/l10n/app_en.arb  app_ja.arb  app_ko.arb  app_zh.arb  app_zh_Hant.arb
```

[`release_guide.md:355`](release_guide.md) repeats it, then **contradicts itself
at line 528** ("Spanish was dropped") with the correct five-locale table. Follow
the code and line 528. Acting on the §4 sentence would ship a listing missing
`ja` and `ko` and carrying an `es` localization for a UI that is not translated.

### F4. STALE DOC (now FIXED in that file) — `release_guide.md` documented a translation feature that no longer exists

The guide devotes a "Translation" chapter (lines 636–765) to
`google_mlkit_translation`, Apple `TranslationSession`,
`lib/core/translation/translator.dart` and `ios/Runner/TranslationBridge.swift`.
**None of it exists:**

```
lib/core/translation            -> No such file or directory
ios/Runner/TranslationBridge.swift -> No such file or directory
grep -rn "mlkit\|translation" pubspec.yaml ios/Podfile -> no output
```

Consequences for this pack: **no listing copy claims translation**, and the
guide's explanation for the 15.5 deployment target ("raised from 13.0 by
`google_mlkit_translation`", line 74) no longer describes anything in the build.
15.5 is still what ships; it just has a different reason now.

### F5. STALE DOC (now FIXED in that file) — a verification command that silently proved nothing

```bash
grep -c 'TARGETED_DEVICE_FAMILY = "1";' ios/Runner.xcodeproj/project.pbxproj  # documented: expect 3
```

The project file writes it **unquoted**, so that command returns `0`, not `3`.
The underlying fact is correct — iPhone only — but the check that is supposed to
prove it fails. The working form is:

```bash
grep -c 'TARGETED_DEVICE_FAMILY = 1;' ios/Runner.xcodeproj/project.pbxproj  # returns 3
```

### F6. The primary model download URL is still dead — re-verified today

```
https://github.com/zhangzhijiang/momera/releases/download/sensevoice_small_model_v20240717/model.int8.onnx
  -> HTTP 404
https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx
  -> HTTP 206 (range request honoured; full length matches expectedBytes = 239,233,841)
```

[`release_checklist.md`](release_checklist.md) flagged this on 2026-09-05 and it
is unchanged. It is not a metadata problem, but it **is** a review problem: every
first-run download burns a 404 before falling back, and transcription — the
feature the whole listing leads on — depends entirely on a third-party host.
If HuggingFace is rate-limited while a reviewer is testing, the reviewer sees a
failed download. The reviewer notes in §5 tell them what to expect; publishing
the pinned release is the real fix.

### F7. `release_checklist.md` version was stale — now corrected in that file

It recorded `1.0.0+2`; `pubspec.yaml` says `1.0.0+9`. The App Store Connect
**version** field takes `CFBundleShortVersionString`, which is `1.0.0` either
way. Only the build number moved.

### F8. Things the older docs got right — no correction needed

* **App Privacy: nothing collected, no tracking.** Verified independently in §8.
* **iPhone only, no iPad screenshots.** `TARGETED_DEVICE_FAMILY = 1`.
* **No ads, no consent flow, no purchase/restore flow to test.** Confirmed.
* **`ITSAppUsesNonExemptEncryption` is already `false`** in `Info.plist`, so the
  export-compliance question is answered at upload time.
* The Play pack's five-locale list (`en-US`, `ja`, `ko`, `zh-CN`, `zh-TW`) is
  correct for Play, and maps to Apple's script-keyed `zh-Hans` / `zh-Hant`.

### F9. `store-kit.json` carries a dart-define that nothing reads

`appstore.dartDefines` sets `STOREKIT_DISABLE_ADS=true`. `grep -rn
"STOREKIT_DISABLE_ADS" lib/ integration_test/` returns nothing — the app has no
ads to disable. Harmless, but it is not doing what its name suggests.

### F10. Icon and English iPhone screenshots — DELIVERED 2026-09-10

Both were captured after the rename, so every frame shows `McRecorder` in the
app bar. `store-kit validate --store appstore` reports **ALL CHECKS PASS**.

| Asset | Where | Spec |
|---|---|---|
| App Store icon | `apple/icons/app_store_icon_1024.png` | 1024×1024 PNG, **opaque** (no alpha — an alpha channel is an automated rejection) |
| iPhone screenshots | `apple/screenshots/upload/iphone/en-US/` | **8 files, 1320×2868** (iPhone 17 Pro Max, the 6.9" slot) |

English only, iPhone only, by request — **no iPad and no other locale was
captured, and no Android screenshots were taken at all.** The Play candidate
pools under `google/screenshots/` are the pre-existing ones from the earlier run;
nothing there was regenerated.

**iPad was considered and deliberately declined.** `TARGETED_DEVICE_FAMILY = 1`
means the app is iPhone-only, so App Store Connect offers no iPad screenshot slot
to upload into. Supplying iPad shots would have required changing that build
setting to `"1,2"`, which makes iPad screenshots *mandatory* and puts iPad
behaviour into review scope. The setting is unchanged and every "iPhone only"
claim in this pack and the reviewer notes remains true.

### F11. NEW BUG — History's empty-search state renders blank

Found by the screenshot run, which **died at frame 20 of 50** because of it.
This is an app bug, not a harness fault, and it is reachable by any user:
**History → search for something with no matches.**

```
LayoutBuilder does not support returning intrinsic dimensions.
The relevant error-causing widget was:
  SliverFillRemaining  lib/presentation/screens/history_screen.dart:134
```

`SliverFillRemaining` calls `getMaxIntrinsicHeight` on its child during layout,
and a `LayoutBuilder` cannot answer that. In a debug build it throws; in release
the assertion is compiled out and the intrinsic silently resolves to zero, so the
empty state **collapses to nothing** — which is exactly what candidate frame 20
(`history_search_empty`) shows: a search field and an otherwise empty screen.

Home's equivalent empty state (frame 07, `search_no_results`) renders correctly
with its icon and "Nothing matches …" message, so the defect is specific to
`HistoryScreen`.

**Not fixed here** — the rename was explicitly scoped to name strings with no
logic changes, and this needs a real layout change
(`SliverToBoxAdapter` + a sized box, or dropping the `LayoutBuilder`). Two
consequences worth knowing:

* Frames **21–50 were never captured**, which cost the three shots the Play
  selection leans on: `21 settings`, `28 recording-in-progress`, `32 dark_home`.
  The eight chosen below are the best of frames 01–20; re-run the capture once
  this is fixed to get a settings shot, a recording-in-progress shot and a dark
  mode shot.
* It is a visible defect a reviewer could stumble into, though not on the
  documented tap path in the reviewer notes.

---

## 1. Subscriptions & in-app purchases — localizations

**Not applicable. McRecorder has no in-app purchases.**

Proof, all three independent:

```bash
grep -c "in_app_purchase" pubspec.yaml                                    # 0
find ios macos -name "*.storekit"                                         # (no output; no macos/ either)
grep -c "Configuration.storekit in Resources" ios/Runner.xcodeproj/project.pbxproj  # 0
```

There is no product-id config class, no subscription group, no plan periods, no
introductory offer, and no free/paid tier split — **every feature in the app is
available to every user with no purchase.** The one thing gated behind anything
at all is transcription, and the gate is a **228 MB model download**, not money
(see [`device_capability_service.dart`](../../lib/core/capabilities/device_capability_service.dart)).

Machine-readable, so downstream tooling does not have to infer it:

```json
{
  "bundleId": "com.idatagear.momerarecording",
  "hasInAppPurchases": false,
  "subscriptionGroups": [],
  "products": [],
  "introductoryOffers": [],
  "appStoreConnectEulaField": "Standard",
  "note": "No StoreKit configuration file exists in the repository. Nothing to localize."
}
```

**Trap 8 (a debug StoreKit config shipped in the IPA) cannot occur here** because
no such file exists. The check stays valid to re-run after any future change:

```bash
unzip -l build/ios/ipa/*.ipa | grep -E "\.storekit( |$)"   # must return nothing
```

If purchases are ever added, this section must be rewritten before the build that
carries them — Apple product ids are immutable and store-specific, and must never
be "aligned" with Play's.

## 2. IAP review metadata

**Not applicable.** There are no subscriptions, so there is no per-subscription
review screenshot and no IAP review notes to upload. `apple/iap_review/` is
empty and should stay empty.

Recorded for the future, because it is the part that is easy to get wrong: an
uploaded IAP review screenshot **can be replaced but never removed**, so nothing
provisional should ever be uploaded there.

## 3. Release notes (What's New)

First App Store release. Limit **4,000** characters per localization.

**`en-US` — 694/4000**

```
First release on the App Store.

• Record with one tap. Audio is saved as 16 kHz mono WAV, and recording continues when you leave the app or lock the screen.
• Pause and resume, and skip silence so a quiet stretch does not fill your storage.
• Offline speech-to-text in Mandarin, Cantonese, English, Japanese and Korean, detected automatically phrase by phrase. Nothing is uploaded.
• Live text while you record — hold the subtitles button.
• Search by what was said, and tap a result to play from that exact moment.
• History with a month calendar, a scrubable waveform, rename, and sharing for both audio and transcript.
• Light and dark themes; interface in English, 简体中文, 繁體中文, 日本語 and 한국어.
```

**`ja` — 336/4000**

```
App Store での最初のリリースです。

• ワンタップで録音。16 kHz モノラル WAV で保存し、アプリを離れても画面をロックしても録音は続きます。
• 一時停止と再開、そして無音スキップ。静かな時間で保存容量が埋まりません。
• オフラインの文字起こし。中国語（標準語）・広東語・英語・日本語・韓国語をフレーズごとに自動判別します。アップロードは一切ありません。
• 録音中のライブ字幕 — 字幕ボタンを長押し。
• 話した言葉で検索し、結果をタップするとその時点から再生します。
• カレンダー付きの履歴、ドラッグできる波形、名前の変更、音声と文字起こしの共有。
• ライト／ダークテーマ、表示言語は English、简体中文、繁體中文、日本語、한국어。
```

**`ko` — 385/4000**

```
App Store 첫 번째 릴리스입니다.

• 한 번 눌러 녹음. 16 kHz 모노 WAV로 저장되고, 앱을 벗어나거나 화면을 잠가도 녹음이 이어집니다.
• 일시정지와 재개, 그리고 무음 건너뛰기로 조용한 구간이 저장 공간을 채우지 않습니다.
• 오프라인 받아쓰기. 중국어(표준어), 광둥어, 영어, 일본어, 한국어를 문장 단위로 자동 인식합니다. 업로드는 전혀 없습니다.
• 녹음 중 실시간 자막 — 자막 버튼을 누르고 있으면 됩니다.
• 말한 내용으로 검색하고, 결과를 누르면 바로 그 지점부터 재생됩니다.
• 달력이 있는 기록 화면, 끌 수 있는 파형, 이름 바꾸기, 음성과 받아쓴 글 공유.
• 라이트·다크 테마, 표시 언어는 English, 简体中文, 繁體中文, 日本語, 한국어.
```

**`zh-Hans` — 246/4000**

```
App Store 首个版本。

• 一键录音。音频保存为 16 kHz 单声道 WAV，离开应用或锁屏后继续录。
• 暂停与继续，以及跳过静音，安静的时段不会占满存储。
• 离线转文字，支持普通话、粤语、英语、日语、韩语，按句自动识别语种。全程不上传。
• 录音时按住字幕按钮，实时出字。
• 按说过的话搜索，点击结果即从那一刻开始播放。
• 带日历的历史记录、可拖动的波形、重命名，音频与文字稿都能分享。
• 浅色与深色主题；界面语言：English、简体中文、繁體中文、日本語、한국어。
```

**`zh-Hant` — 251/4000**

```
App Store 首個版本。

• 一鍵錄音。音訊存成 16 kHz 單聲道 WAV，離開應用程式或鎖定螢幕後繼續錄。
• 暫停與繼續，以及略過靜音，安靜的時段不會佔滿儲存空間。
• 離線轉文字，支援國語、粵語、英語、日語、韓語，逐句自動判斷語言。全程不上傳。
• 錄音時按住字幕按鈕，即時出字。
• 用說過的話搜尋，點擊結果即從那一刻開始播放。
• 附月曆的歷史紀錄、可拖曳的波形、重新命名，音訊與文字稿都能分享。
• 淺色與深色主題；介面語言：English、简体中文、繁體中文、日本語、한국어。
```

## 4. Discovery metadata

### Keywords — limit 100, comma-separated, **no space after the comma**

Apple already indexes the app name and the subtitle, so no word from either is
repeated below. Verified programmatically by
[`../shared/scripts/count_listing_strings.py`](../shared/scripts/count_listing_strings.py),
which fails the build on a repeat — it caught `녹음` colliding with the Korean
subtitle's `녹음기` and that term was removed. Singular forms only; Apple matches
plurals itself. Each list carries cross-script terms, because users search in
both scripts on every storefront.

**`en-US` — 93/100 (7 spare), 15 terms**

```
voice,memo,dictation,speech,text,audio,note,interview,lecture,meeting,caption,wav,录音,文字起こし,녹음
```

**`ja` — 79/100 (21 spare), 15 terms**

```
録音,ボイスメモ,音声認識,書き起こし,議事録,会議,講義,インタビュー,字幕,テキスト化,文字変換,voice,memo,speech,transcribe
```

**`ko` — 81/100 (19 spare), 16 terms**

```
음성메모,음성인식,전사,회의록,회의,강의,인터뷰,자막,텍스트변환,오디오,기록,voice,memo,speech,dictation,transcribe
```

**`zh-Hans` — 72/100 (28 spare), 16 terms**

```
录音笔,语音转文字,会议记录,采访,讲座,字幕,听写,音频,文本,语音识别,粤语,普通话,voice,memo,speech,dictation
```

**`zh-Hant` — 72/100 (28 spare), 16 terms**

```
錄音筆,語音轉文字,會議記錄,採訪,講座,字幕,聽寫,音訊,文字稿,語音辨識,粵語,國語,voice,memo,speech,dictation
```

### Promotional text — limit 170

**Promotional text updates without submitting a new binary**, so it is the one
field to rotate freely after launch. Rotations are offered below the primaries.

**`en-US` — 156/170**

```
Speech-to-text that runs on your iPhone, not on a server. Record, transcribe in five languages, and search by what you actually said — with the network off.
```

**`ja` — 59/170**

```
音声認識は端末の中だけで動きます。5言語を自動判別して文字にし、話した言葉で検索できます。ネットワークを切ったままで。
```

**`ko` — 77/170**

```
음성 인식이 기기 안에서만 동작합니다. 5개 언어를 자동으로 판별해 글로 옮기고, 말한 내용으로 검색할 수 있습니다. 네트워크를 끈 채로.
```

**`zh-Hans` — 54/170**

```
语音识别只在这台设备上运行，不上传服务器。自动判别五种语言并转成文字，还能按你说过的话搜索——全程可以断网。
```

**`zh-Hant` — 54/170**

```
語音辨識只在這台裝置上執行，不上傳伺服器。自動判別五種語言並轉成文字，還能用你說過的話搜尋——全程可以斷網。
```

#### Rotations for later (`en-US`, all under 170)

```
Hold the subtitles button while you record and watch each phrase turn into text. Nothing is uploaded — the speech model lives on your iPhone.
```

```
Search a month of recordings by what was said, not what you named them. Tap a result and playback starts at that exact moment.
```

```
Mandarin, Cantonese, English, Japanese and Korean, detected phrase by phrase. A conversation that switches language is transcribed in both.
```

## 5. Store listing & reviewer information

### App information

| Field | Value |
|---|---|
| Bundle id | `com.idatagear.momerarecording` |
| Primary language | English (U.S.) |
| Primary category | **Utilities** |
| Secondary category | **Productivity** |
| Copyright | `2026 iDataGear Inc.` |
| Privacy policy URL | `https://www.idatagear.com/privacy-policy-mcrecorder.html` — **must return 200 first; see F2** |
| Support URL | `https://www.idatagear.com` |
| Marketing URL | *(leave blank)* — see the note below |
| Age rating | 4+ *(see §8)* |
| EULA field | **Standard** — do not upload a custom EULA |

**On the marketing URL:** it is load-bearing only for apps that serve ads,
because it is how Google's crawler finds `app-ads.txt` for an iOS app. Momera
Recorder serves **no ads** — there is no `google_mobile_ads` dependency — so this
field carries no weight and is safely blank. (For the record,
`https://www.idatagear.com/app-ads.txt` does return 200; it just has no bearing
on this app.)

**On the category:** Utilities over Productivity because this is a recorder, not
a workflow app. The Play pack chose Tools for the same reason, which is the
equivalent. Either is defensible; Utilities is the better fit.

### App name — 10/30, every localization

```
McRecorder
```

This is **byte-identical to `CFBundleDisplayName`** in
[`ios/Runner/Info.plist`](../../ios/Runner/Info.plist), and to `appTitle` in all
five ARB files, so the home-screen name, the in-app title and the listing agree.
"Momera" is a brand term rather than a generic one, so there is no uniqueness
risk and no fallback is needed.

### Subtitle — limit 30

| Locale | Subtitle | Count |
|---|---|---|
| `en-US` | `Record and transcribe offline` | 29/30 |
| `ja` | `オフライン文字起こしレコーダー` | 15/30 |
| `ko` | `오프라인 받아쓰기 음성 녹음기` | 16/30 |
| `zh-Hans` | `离线转文字的录音机` | 9/30 |
| `zh-Hant` | `離線轉文字的錄音機` | 9/30 |

```
Record and transcribe offline
```

```
オフライン文字起こしレコーダー
```

```
오프라인 받아쓰기 음성 녹음기
```

```
离线转文字的录音机
```

```
離線轉文字的錄音機
```

### Description — limit 4,000

Every claim below was checked against code, not against the older docs. The five
recognised **speech** languages come from `TranscriptionLanguage` in
[transcription_service.dart:18-26](../../lib/core/services/transcription_service.dart#L18-L26);
the five **interface** languages come from `lib/l10n/*.arb` and are a different
set — Cantonese has no separate written locale. "About 228 MB" is
`ModelDownloadService.expectedBytes = 239233841`. "Exactly one kind of network
request" is literal: `http` appears in one file in `lib/`.

**Corrected against the Play copy for iOS:** the Play description says recording
continues "with a notification you can stop it from". That is the Android
foreground service. On iOS there is no such notification — the system shows its
own recording indicator, as
[recording_session_channel.dart:8-12](../../lib/core/services/recording_session_channel.dart#L8-L12)
says in as many words. Every localization below says the iOS thing instead.
"Your recordings never leave the phone" likewise became "the iPhone".

**`en-US` — 2082/4000**

```
McRecorder is a voice recorder that turns what you said into text — and does it entirely on your own iPhone.

RECORDING
• Tap once to record. Audio is saved as 16 kHz mono WAV: a plain, universal file you can open anywhere, not a format that locks you in.
• Keeps recording when you leave the app or lock the screen. iOS shows its own recording indicator the whole time.
• Pause and resume without ending the recording.
• Skip silence, so an hour in a quiet room does not become an hour of audio.
• A storage limit you choose, and an auto-save interval so an interruption costs you seconds rather than the whole session.

TRANSCRIPTION, OFFLINE
• Speech-to-text runs on the device. No account, no upload, no server.
• Mandarin, Cantonese, English, Japanese and Korean — detected automatically, phrase by phrase, so a conversation that switches language is transcribed in both.
• Hold the subtitles button while recording and watch the text arrive as each phrase finishes.
• The speech model is downloaded once (about 228 MB) and then kept on the device. After that, transcription works in Airplane Mode.

FINDING IT AGAIN
• Search by recording name or by what was actually said.
• Tap a result to start playing from the exact moment that phrase was spoken.
• A month calendar marks every day you recorded on; tap a day to see just that day.
• The home screen keeps today's recordings out of the way of the next one. History keeps everything.

THE REST
• A waveform you can scrub to any point.
• Rename a recording, share the audio, copy or share the transcript, remove a transcript without touching the audio.
• Light and dark themes, or follow the device.
• Interface in English, 简体中文, 繁體中文, 日本語 and 한국어.

PRIVACY
Your recordings never leave the iPhone. The app makes exactly one kind of network request in its life: downloading the speech model. There are no ads, no analytics, no account, no tracking and no in-app purchases. Recordings are stored in the app's own folder and are yours to share or delete.

Privacy Policy: https://www.idatagear.com/privacy-policy-mcrecorder.html
```

**`ja` — 965/4000**

```
McRecorder は、話した内容をその場で文字にするボイスレコーダーです。処理はすべて iPhone の中で完結します。

録音
• タップするだけで録音開始。16 kHz モノラルの WAV で保存するので、どこでも開ける普通のファイルです。独自形式に縛られません。
• アプリを離れても画面をロックしても録音は続きます。その間は iOS の録音インジケータが表示されます。
• 録音を終了せずに一時停止・再開ができます。
• 無音をスキップ。静かな部屋で一時間置いても、一時間分の音声にはなりません。
• 保存容量の上限と自動保存の間隔を選べます。中断されても失われるのは数秒だけです。

文字起こし（オフライン）
• 音声認識は端末上で動きます。アカウントもアップロードもサーバーもありません。
• 中国語（標準語）・広東語・英語・日本語・韓国語に対応。フレーズごとに自動で判別するので、途中で言語が切り替わる会話も両方そのまま文字になります。
• 録音中に字幕ボタンを長押しすると、一区切りごとにテキストが表示されます。
• 音声モデルは初回だけダウンロード（約 228 MB）して端末に保存します。以降は機内モードでも文字起こしできます。

あとから見つける
• 録音名でも、話した言葉でも検索できます。
• 検索結果をタップすると、その言葉が話された時点から再生します。
• カレンダーが録音した日に印を付けます。日付をタップすればその日だけ表示。
• ホームは今日の録音だけ。それ以外はすべて履歴にあります。

そのほか
• 波形をドラッグして好きな位置へ。
• 名前の変更、音声の共有、文字起こしのコピーと共有、音声を残したまま文字起こしだけ削除。
• ライトテーマ／ダークテーマ、または端末の設定に追従。
• 表示言語は日本語、English、简体中文、繁體中文、한국어。

プライバシー
録音が iPhone から出ることはありません。このアプリが行う通信は、音声モデルのダウンロードだけです。広告も、解析も、アカウントも、トラッキングも、アプリ内課金もありません。

プライバシーポリシー: https://www.idatagear.com/privacy-policy-mcrecorder.html
```

**`ko` — 1042/4000**

```
McRecorder는 말한 내용을 그대로 글로 옮겨 주는 음성 녹음기입니다. 모든 처리는 iPhone 안에서 끝납니다.

녹음
• 한 번 누르면 녹음 시작. 16 kHz 모노 WAV로 저장하므로 어디서나 열 수 있는 평범한 파일이며, 독자 형식에 묶이지 않습니다.
• 앱을 벗어나거나 화면을 잠가도 녹음은 계속되고, 그동안 iOS의 녹음 표시가 켜져 있습니다.
• 녹음을 끝내지 않고 일시정지하고 다시 이어갈 수 있습니다.
• 무음 건너뛰기. 조용한 방에서 한 시간을 두어도 한 시간짜리 음성이 되지 않습니다.
• 저장 용량 한도와 자동 저장 간격을 직접 고를 수 있어, 중단되어도 잃는 것은 몇 초뿐입니다.

받아쓰기, 오프라인으로
• 음성 인식이 기기에서 실행됩니다. 계정도, 업로드도, 서버도 없습니다.
• 중국어(표준어), 광둥어, 영어, 일본어, 한국어를 문장 단위로 자동 인식하므로 도중에 언어가 바뀌는 대화도 양쪽 모두 받아씁니다.
• 녹음 중 자막 버튼을 누르고 있으면 한 구절이 끝날 때마다 글자가 나타납니다.
• 음성 모델은 처음 한 번만 내려받아(약 228 MB) 기기에 보관합니다. 그 뒤로는 비행기 모드에서도 받아쓰기가 됩니다.

다시 찾기
• 녹음 이름으로도, 말한 내용으로도 검색됩니다.
• 검색 결과를 누르면 그 말을 한 바로 그 지점부터 재생됩니다.
• 달력이 녹음한 날을 표시하고, 날짜를 누르면 그날만 볼 수 있습니다.
• 홈에는 오늘 것만, 나머지는 모두 기록에 있습니다.

그 밖에
• 파형을 끌어 원하는 지점으로 이동.
• 이름 바꾸기, 음성 공유, 받아쓴 글 복사와 공유, 음성은 두고 받아쓴 글만 삭제.
• 라이트·다크 테마 또는 기기 설정 따르기.
• 표시 언어는 한국어, English, 简体中文, 繁體中文, 日本語.

개인정보
녹음은 iPhone 밖으로 나가지 않습니다. 이 앱이 하는 통신은 음성 모델을 내려받는 것 하나뿐입니다. 광고도, 분석도, 계정도, 추적도, 인앱 구입도 없습니다.

개인정보 처리방침: https://www.idatagear.com/privacy-policy-mcrecorder.html
```

**`zh-Hans` — 725/4000**

```
McRecorder 是一款把你说过的话直接变成文字的录音机，而且全部在 iPhone 本机完成。

录音
• 点一下就开始录。音频保存为 16 kHz 单声道 WAV——到哪儿都能打开的普通文件，不会被专有格式绑住。
• 离开应用或锁屏后继续录音，期间 iOS 会显示自己的录音指示标志。
• 可以暂停再继续，不必结束这一段录音。
• 跳过静音：在安静的房间里放一个小时，不会变成一个小时的音频。
• 存储上限和自动保存间隔都可以自己选，中断时最多只损失几秒。

离线转文字
• 语音识别在设备上运行。不需要账号，不上传，没有服务器。
• 支持普通话、粤语、英语、日语和韩语，按句自动识别语种，中途换语言的对话两种都能转出来。
• 录音时按住字幕按钮，说完一句就出现一句。
• 语音模型只需下载一次（约 228 MB），之后保存在设备上，飞行模式下也能转写。

再找回来
• 既能按录音名称搜索，也能搜你说过的话。
• 点搜索结果，就从说那句话的时间点开始播放。
• 日历标出录过音的每一天，点某一天只看那天的。
• 主屏只留今天的录音，其余全部在历史里。

其他
• 波形可以拖动到任意位置。
• 重命名、分享音频、复制或分享文字稿，也可以只删文字稿、保留音频。
• 浅色和深色主题，也可以跟随系统。
• 界面语言：简体中文、繁體中文、English、日本語、한국어。

隐私
录音不会离开这台 iPhone。这个应用一生中只发起一类网络请求：下载语音模型。没有广告，没有统计，没有账号，没有追踪，也没有任何应用内购买。

隐私政策：https://www.idatagear.com/privacy-policy-mcrecorder.html
```

**`zh-Hant` — 734/4000**

```
McRecorder 是一款把你說過的話直接變成文字的錄音機，而且全部在 iPhone 本機完成。

錄音
• 按一下就開始錄。音訊存成 16 kHz 單聲道 WAV——到哪裡都打得開的普通檔案，不會被專有格式綁住。
• 離開應用程式或鎖定螢幕後繼續錄音，期間 iOS 會顯示自己的錄音指示標誌。
• 可以暫停再繼續，不必結束這一段錄音。
• 略過靜音：在安靜的房間裡放一小時，不會變成一小時的音訊。
• 儲存上限和自動儲存間隔都能自己選，中斷時最多只損失幾秒。

離線轉文字
• 語音辨識在裝置上執行。不需要帳號，不上傳，沒有伺服器。
• 支援國語、粵語、英語、日語和韓語，逐句自動判斷語言，中途換語言的對話兩種都轉得出來。
• 錄音時按住字幕按鈕，說完一句就出現一句。
• 語音模型只需下載一次（約 228 MB），之後保存在裝置上，飛航模式下也能轉寫。

再找回來
• 可以用錄音名稱搜尋，也可以搜你說過的話。
• 點搜尋結果，就從說那句話的時間點開始播放。
• 月曆標出錄過音的每一天，點某一天只看那天的。
• 主畫面只留今天的錄音，其餘全部在歷史紀錄裡。

其他
• 波形可以拖到任意位置。
• 重新命名、分享音訊、複製或分享文字稿，也可以只刪文字稿、保留音訊。
• 淺色與深色主題，也可以跟隨系統。
• 介面語言：繁體中文、简体中文、English、日本語、한국어。

隱私
錄音不會離開這支 iPhone。這個應用程式一生中只發出一種網路請求：下載語音模型。沒有廣告，沒有統計，沒有帳號，沒有追蹤，也沒有任何 App 內購買。

隱私權政策：https://www.idatagear.com/privacy-policy-mcrecorder.html
```

### Notes to reviewers

**Demo account: not required. Leave the username and password fields blank.**
The app has no account system, no sign-in and no server.

Paste this into App Store Connect → App Review Information → Notes:

```
No sign-in is required. There is no account system, no server, and no in-app purchases or subscriptions of any kind — every feature is available immediately.

IMPORTANT — PLEASE READ BEFORE TESTING TRANSCRIPTION

Speech-to-text runs entirely on the device. The speech model is NOT bundled in the app (it would add ~228 MB to the download), so it is fetched once, on demand, the first time you ask for text. On a fresh install this is a ~228 MB download over Wi-Fi and can take several minutes. The app shows a progress sheet throughout; it is not a hang.

Exact path to transcription:
1. Launch the app. Tap the large record button at the bottom of the home screen.
2. Grant the microphone permission when iOS asks. Speak for 5-10 seconds in English, Mandarin, Cantonese, Japanese or Korean.
3. Tap the record button again to stop. The recording appears in the list above.
4. Tap "Transcribe" on that recording's row.
5. A sheet appears: "Transcription runs fully offline. The speech model (228 MB) is downloaded once and kept on this device." Tap Download and wait for it to finish.
6. Transcription then runs locally and the text appears under the recording. From this point on it works with the device in Airplane Mode.

Live text while recording:
Start a recording, then PRESS AND HOLD the subtitles button beside the record button. Text appears as each phrase completes. This requires the model from step 5 to have been downloaded first; before that the button explains it is unavailable.

Other things you may want to reach:
- Settings: gear icon at the top right of the home screen (interface language, theme, maximum storage, auto-save interval).
- History and the month calendar: the "History" button on the home screen.
- Search by spoken words: use the search field, then tap a result to begin playback at the exact moment that phrase was spoken. Only recordings that have already been transcribed are searchable by content.

Permissions:
- Microphone — requested in context, the first time you tap record. It is the app's only permission on iOS and its only purpose.
- Background audio (UIBackgroundModes: audio) — so a recording continues when the app is backgrounded or the screen is locked. This is a real, user-visible feature: start recording, lock the screen, wait, unlock, and the recording is still running. iOS shows its own recording indicator throughout.

Network use:
The app makes exactly one kind of network request in its life: downloading the speech model described above. No audio, no transcripts and no identifiers are ever transmitted. There is no analytics SDK, no crash reporter, no advertising SDK and no attribution SDK in the binary.

Tracking:
The app does not track users. There is no App Tracking Transparency prompt at any point, because there is nothing to ask permission for. NSPrivacyTracking is false in the privacy manifest and no NSUserTrackingUsageDescription key exists.

Content and age rating:
All on-screen text is the app's own interface, translated into English, Simplified Chinese, Traditional Chinese, Japanese and Korean. The app ships no content corpus — no articles, no media library, no user-generated feed. Transcripts are produced from whatever the user records. Nothing in the app is age-sensitive.

Device support:
iPhone only (TARGETED_DEVICE_FAMILY = 1), iOS 15.5 and later. It runs on iPad in iPhone compatibility mode; no iPad-specific layout is claimed.
```

## 6. Terms of Use (EULA) in the description

**Not required for this submission, and deliberately omitted.**

Guideline **3.1.2** requires a functional Terms of Use (EULA) link in the App
Store description of every localization **for apps offering auto-renewable
subscriptions**. McRecorder offers none — see F1 and §1 for the three
independent proofs. Adding a subscription-renewal disclosure block ("Payment will
be charged to your Apple Account… renews automatically…") to the description of
an app with no subscriptions would describe a purchase flow that does not exist,
which is a **Guideline 2.3.1** inaccurate-metadata problem in the other direction.

What is in place instead, and why it is sufficient:

* The App Store Connect **EULA field stays on *Standard***, so Apple's Standard
  EULA governs use of the app. Do not upload a custom EULA — the moment you do,
  the description would have to link to *that* instead.
* The hosted legal page (§7) carries a **Terms of Use** section that explicitly
  defers to the same agreement, at the byte-identical URL:

  ```
  https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
  ```

  Verified today:

  ```bash
  curl -sS -o /dev/null -w '%{http_code}\n' -L \
    https://www.apple.com/legal/internet-services/itunes/dev/stdeula/   # 200
  ```

* Every localization's description carries the **privacy policy link**, which is
  the disclosure that does apply here, byte-identical across all five.

**There is no paywall in the binary**, so the companion 3.1.2 requirement — that
the same disclosures be reachable from the purchase screen — has no screen to
apply to. `grep -rn "paywall\|Paywall" lib/` returns nothing.

**If a subscription is ever added, this section becomes mandatory and must be
rewritten before that build ships.** The full per-localization block —
en-US, ja, ko, zh-Hans and zh-Hant, each with its own localized labels
(利用規約 (EULA) / 이용약관 (EULA) / 使用条款 (EULA) / 使用條款 (EULA)) and the URL
byte-identical — is what would be appended to the end of each description, after
the feature copy, costing roughly 690 characters in English and 275 in CJK.
Every description above has at least 1,900 characters of headroom, so the block
fits in all five without touching the feature copy.

## 7. Legal pages

### What was already live

Searched first, as required. `www.idatagear.com` is the live host
(`CNAME` in the site repo at `~/Developer/projects/idatagear/idatagear`, served
from `github.com/zhangzhijiang/idatagear`). Sibling apps have per-app pages:

```
https://www.idatagear.com/privacy-policy-momera-hiking.html      -> 200 (live)
https://www.idatagear.com/privacy-policy-mcrecorder.html   -> 404 (missing)
```

**No page exists for McRecorder, and no legal URL is compiled into the
binary** — `grep -rniE "https?://" lib/` returns only the two model-download
hosts. So this is a genuine gap, not a page I invented a need for.

Those sibling pages are **standalone, self-contained files** — inline CSS, no
shared nav, no include chrome — so a new file can be dropped in beside them
without stripping anything. I matched their structure and house palette and
added a dark-mode block, which they do not have.

### What I wrote

**[`../shared/legal/privacy-policy-mcrecorder.html`](../shared/legal/privacy-policy-mcrecorder.html)**
— self-contained, responsive, embedded CSS, **no external requests**, light and
dark, with canonical and Open Graph tags matching the sibling pages' SEO shape.

It covers privacy **and** terms in one page: on-device storage (with the exact
file layout), the single network request and both hosts, the absence of ads,
analytics, crash reporting, accounts and tracking, permissions scoped per
platform, purchases (none, on both stores), children, retention, rights,
per-platform differences (iOS background audio vs. the Android foreground-service
notification), transcript accuracy, licence, no warranty, limitation of
liability, and governing law.

It serves **both stores**. The Play pack's §7 records the same missing-URL
blocker; this one page closes it for Play as well.

Deploy:

```bash
cp idatagear_app_release/shared/legal/privacy-policy-mcrecorder.html \
   ~/Developer/projects/idatagear/idatagear/privacy-policy-mcrecorder.html
# then commit and push the site repo, and re-check:
curl -sS -o /dev/null -w '%{http_code}\n' -L \
  https://www.idatagear.com/privacy-policy-mcrecorder.html   # must be 200
```

### What you must supply before it goes live

Three facts are mine to guess and yours to state. They are marked in the HTML as
**visibly highlighted `[[ … ]]` blocks** so they cannot ship unnoticed:

| Marker | What is needed |
|---|---|
| `[[ GOVERNING LAW — jurisdiction to be supplied ]]` | Which jurisdiction's law governs |
| `[[ VENUE — courts to be supplied ]]` | Which courts have jurisdiction |
| `[[ REGISTERED ADDRESS — to be supplied ]]` | iDataGear Inc.'s registered address |

Two facts I did **not** invent — both were read from the live
`privacy-policy-momera-hiking.html` footer:

* Entity name **iDataGear Inc.**
* Contact **support@idatagear.com** — a domain address, not your personal one.
  **Confirm this mailbox is actually monitored**, because App Review may write to
  it. The existing `shared/legal/privacy_policy.md` and the Play pack both use
  `zhangzhijiang@gmail.com`; a personal address should not be the published
  contact.

### The older markdown policy is now superseded, and was wrong for iOS

[`../shared/legal/privacy_policy.md`](../shared/legal/privacy_policy.md) is
Android-only throughout — "Android's app preferences", "Android's share sheet",
an Android-only permissions table, no mention of iOS background audio — and
publishes a personal email address. It was never served anywhere. Either delete
it or leave it as the Play-only draft it is; the HTML page above replaces it for
both stores.

## 8. App Privacy questionnaire & age rating

Derived from the SDKs actually in `pubspec.yaml`, not from previous answers.
The full dependency list is: `flutter_riverpod`, `record`, `just_audio`,
`sherpa_onnx`, `path_provider`, `path`, `http`, `intl`, `shared_preferences`,
`share_plus`. **There is no analytics, advertising, attribution or crash SDK of
any kind.**

### iOS — App Privacy answers

Answer **"No, we do not collect data from this app."** That single answer closes
the whole questionnaire.

| Data type | Collected | Linked to identity | Used for tracking | Purpose | SDK |
|---|---|---|---|---|---|
| *(every category)* | **No** | n/a | **No** | n/a | none |

```yaml
platform: ios
data_collection: none
tracking: false
collected_data_types: []
not_collected:
  - contact_info          # no account system, no sign-in, no email field
  - health_and_fitness
  - financial_info        # no in-app purchases, no payment handling
  - location              # no location permission requested or declared
  - sensitive_info
  - contacts
  - user_content          # audio and transcripts stay in the app container
  - browsing_history
  - search_history        # in-app search runs locally over local files
  - identifiers           # no IDFA, no IDFV, no device id read or sent
  - purchases
  - usage_data            # no analytics SDK
  - diagnostics           # no crash reporter
  - other_data
reasoning: >
  Apple defines collection as data transmitted off the device. `http` appears in
  exactly one file in lib/ — core/services/model_download_service.dart — and it
  performs a GET for the speech model. It sends no body, no identifiers and no
  audio. Recordings, transcripts, waveform caches and settings are written to the
  app's own container and never read by anything else.
```

**There must be no "Data Used to Track You" section in the generated answers.**

### Tracking — all four places, read individually

| Where | Expected | Actual | Verdict |
|---|---|---|---|
| `NSUserTrackingUsageDescription` in `Info.plist` | absent | **absent** (`grep -c` → 0) | PASS |
| ATT call site (Dart or `AppDelegate.swift`) | none | **none** — no `ATTrackingManager`, no `AppTrackingTransparency`, no `app_tracking_transparency` package | PASS |
| `NSPrivacyTracking` in `PrivacyInfo.xcprivacy` | `false` | **`false`**, and correctly with **no** `NSPrivacyTrackingDomains` key | PASS |
| App Privacy answers | no tracking section | **none**, per the YAML above | PASS |

No mediation adapter can pull the app into tracking scope here, because there is
no ad SDK at all — the `gma_mediation_meta` → `FBAudienceNetwork` case cannot
arise. `AdSupport` is not linked by any dependency.

`PrivacyInfo.xcprivacy` also declares one accessed-API reason, which is correct
and should stay:

```
NSPrivacyAccessedAPICategoryFileTimestamp -> C617.1
```

`RecordingRepository.list()` calls `File.stat()` to date recordings whose
filename has no parseable timestamp; the files are inside the app container,
which is exactly reason C617.1.

### macOS

**Not applicable — there is no `macos/` directory.** The app ships iOS and
Android only. Nothing to answer, and nothing to over-declare by copying the iOS
answers across.

### Age rating — suggested **4+**

Scanned rather than guessed. The app ships **no content corpus**: `pubspec.yaml`
bundles exactly two assets, `assets/models/sensevoice/tokens.txt` (a tokenizer
vocabulary) and `assets/models/silero_vad/silero_vad.onnx` (a binary VAD model).
There is no JSON content file, no article set, no media library. Every
user-visible string in the app comes from `lib/l10n/*.arb`, which are interface
strings only.

> **On `tokens.txt`:** it is a speech-recognition vocabulary, not content. A
> tokenizer vocabulary trained on general speech will contain profanity tokens
> the way a dictionary contains them — as units the model can *recognise*, never
> as anything the app *displays* on its own. Apple's questions ask about
> depictions. There are none. `release_guide.md` makes the same point about not
> reading the vocabulary as a capability list, and it is right.

The only text that can ever appear beyond the interface is the transcript of
what the user themselves recorded — user-generated, on-device, never shared with
other users, and with no feed, no comments and no social surface of any kind.

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Unrestricted Web Access | **No** — the app has no browser or web view |
| Gambling and Contests | No |
| Age Assurance / user-generated content exposure | No — transcripts are local to one device and are never shared with other users |

Apple computes the final rating from these answers; the expected result is **4+**.
**This is a legal declaration you must read and submit yourself** — it is offered
here as a derivation from the code, not as a substitute for your own reading.

### Export compliance

Already answered in the binary, so the upload will not stall on it:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

The app performs no encryption of its own; the model download is ordinary HTTPS,
which is the exempt case this key declares.

---

## Pre-submission verification

Re-verified across files after writing. Status as of 10 September 2026.

| # | Check | Status |
|---|---|---|
| 1 | Every string counted, `n/limit` printed | **PASS** — 30 field/locale pairs, all under limit, re-run after the rename, via `shared/scripts/count_listing_strings.py` (exit 0) |
| 2 | Privacy URL byte-identical to the constant in the code | **N/A** — no legal URL is compiled into the binary. The URL is byte-identical across all five descriptions, the App Information table and the hosted page's canonical tag. |
| 3 | Every localization's description contains the Terms of Use (EULA) link | **N/A by design** — no auto-renewable subscription, so 3.1.2 does not apply. See §6. |
| 4 | EULA URL byte-identical everywhere and returns 200 | **PASS** — appears once, in the hosted terms page; `curl` → 200 |
| 5 | App Store Connect EULA field on *Standard* | **ACTION** — a console setting; set it to Standard and do not upload a custom EULA |
| 6 | Tracking answer consistent across all four places | **PASS** — see the four-row table in §8 |
| 7 | Product ids match the config class character for character | **N/A** — no products and no config class |
| 8 | Version string matches `CFBundleShortVersionString` | **PASS** — `1.0.0` from `pubspec.yaml: 1.0.0+9` |
| 9 | App name matches `CFBundleDisplayName` | **PASS** — `McRecorder`, identical in `Info.plist` and all five ARB files |
| 10 | Every localization present in every localized section | **PASS** — `en-US`, `ja`, `ko`, `zh-Hans`, `zh-Hant` in §3, §4 and §5 |
| 11 | Each stale doc named, with what is wrong in it | **PASS** — F3, F4, F5, F6, F7, F9 |
| 12 | No `.storekit` file shipped in the IPA | **PASS by construction** — no such file exists in the repo |
| 13 | Privacy policy URL returns 200 | **FAIL — BLOCKER.** 404 today. Deploy the page from §7 first. |
| 14 | Screenshots and 1024 icon present | **PASS** — 1024 opaque icon + 8 iPhone shots at 1320×2868, English only, iPhone only by request. `validate --store appstore` → ALL CHECKS PASS |
| 15 | App name matches across stores and stores' configs | **PASS** — `McRecorder` in `Info.plist`, `android:label`, all five ARB files and `store-kit.json` |
| 16 | Rename did not break the build | **PASS** — `flutter analyze` clean, **194/194 tests pass** (one assertion in `test/widget_test.dart` updated to the new title) |

Re-run the string counts at any time:

```bash
python3 idatagear_app_release/shared/scripts/count_listing_strings.py   # exit 0 = all fields within limit
```

Re-run the live-URL checks:

```bash
for u in \
  https://www.idatagear.com/privacy-policy-mcrecorder.html \
  https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ ; do
  printf '%s -> ' "$u"
  curl -sS -o /dev/null -w '%{http_code}\n' -L "$u"
done
```
