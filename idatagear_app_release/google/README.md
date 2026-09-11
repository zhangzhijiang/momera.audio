# Google Play listing — McRecorder

Everything the Play Console needs, and how to regenerate it.

* **Package** `com.idatagear.momerarecording`
* **Default listing** `en-US`. Every Play language not listed below falls back
  to it.
* **Toolkit** `~/Developer/projects/google_play_store_helper`, driven through
  `./idatagear_app_release/store-kit`. Config: `idatagear_app_release/store-kit.json`.
* **Console declarations** (data safety, foreground service, content rating,
  permissions): [`submission_pack.md`](submission_pack.md).

## Status

`store-kit validate` — **ALL CHECKS PASS**, 6 warnings, none blocking.

| | State |
|---|---|
| App icon 512×512 | ✅ done |
| Feature graphics ×5 | ✅ done, one per listing language |
| Listing copy ×5 | ✅ done, longest field 78/80 |
| Phone screenshots, `en-US` + `ja` | ✅ 8 chosen out of 50, in `upload/` |
| Phone screenshots, `ko` | ⚠️ 30 of 50 captured, none selected |
| Phone screenshots, `zh-CN` + `zh-TW` | ❌ not captured |
| 7″ and 10″ tablet screenshots | ❌ not captured — and see the tablet note below |
| Privacy policy URL | ❌ text written, **not hosted**. Blocks submission. |

**The capture run was stopped part-way on purpose**, so the matrix is three
locales and two tiers short of the plan. Nothing is broken: the screen list runs
50/50 with zero skips, and finishing is one command —

```bash
./idatagear_app_release/store-kit shoot --tier phone --locale ko
./idatagear_app_release/store-kit shoot --tier phone --locale zh
./idatagear_app_release/store-kit shoot --tier phone --locale zh_Hant
```

then replace the two per-locale keys in `selection.json` with the single `"*"`
line the file's comment gives you, and re-run `select` and `validate`.

### The six validate warnings, explained

* `29 recording_paused` is near-identical to `28 recording` in all three
  locales. It is meant to be: the same screen with the timer stopped and the
  pause glyph swapped for play. Real difference, small pixel difference.
* `41 dark_history_single_day` is near-identical to `40 dark_history_calendar`.
  Selecting a day changes the tapped cell from a ring to a filled circle and
  filters the list below the fold. Also real, also small.
* `candidates/phone/ko: 30/50` — the interrupted run.

None affects `upload/`, which passed every check including locale-set parity.

---

## What goes where in the Console

| Console field | File |
|---|---|
| App icon (512×512) | `icons/play_store_icon_512.png` |
| Feature graphic (1024×500), default listing | `feature_graphic/feature_graphic_1024x500.png` |
| Feature graphic, per language | `feature_graphic/feature_graphic_<locale>_1024x500.png` |
| Phone screenshots | `screenshots/upload/phone/<locale>/` |
| 7-inch tablet screenshots | `screenshots/upload/tablet_7/<locale>/` |
| 10-inch tablet screenshots | `screenshots/upload/tablet_10/<locale>/` |
| Short / full description, release notes | `listing.md`, one `##` section per language |
| Data safety, content rating, foreground-service form, app access | `submission_pack.md` |
| Privacy policy URL | host `../shared/legal/privacy_policy.md` — see `submission_pack.md` §7 |
| Promo video | none — see below |

The Console's language tabs are named exactly like the folders: `en-US`, `ja`,
`ko`, `zh-CN`, `zh-TW`.

`icons/launcher_mipmaps/` is a copy of the shipped launcher icons. It is
reference material, not something the Console asks for.

### Promo video

Google Play accepts **no video upload**. The store-listing promo slot is a
**YouTube URL**, and the video must be public or unlisted, have embedding
enabled, monetization off, and be a clean watch link — no playlist, no tracking
parameters, no shortened link. It also only displays when the 1024×500 feature
graphic exists, which it does. Nothing here produces one;
`./idatagear_app_release/store-kit record --platform android` would produce a
master to upload to YouTube yourself.

---

## Regenerating

```bash
# once, before capturing — checks build mode, translations, wiring
./idatagear_app_release/store-kit preflight

# the matrix: 3 tiers x 5 locales
./idatagear_app_release/store-kit shoot --dry-run
./idatagear_app_release/store-kit shoot

./idatagear_app_release/store-kit sheets     # contact sheets, for choosing
./idatagear_app_release/store-kit select     # selection.json -> upload/
./idatagear_app_release/store-kit generate   # icon + feature graphics
./idatagear_app_release/store-kit validate   # must pass before upload

./idatagear_app_release/store-kit capture reset   # ALWAYS, when finished
```

`candidates/` and `sheets/` are git-ignored: 50 frames × 3 tiers × 5 locales is
750 PNGs, all reproducible. `upload/`, the graphics and the copy are committed.

### The two things capture needs that are not obvious

**A release build must be installed before `preflight`.** A debug build paints
`BOTTOM OVERFLOWED BY N PIXELS` into screenshots, and an IDE run silently
replaces a release install:

```bash
flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**The emulator needs host audio.** Without it the virtual microphone delivers no
samples, `AudioRecordingService.elapsed` is derived from bytes written, and
every recording screen photographs `00:00` — which reads as a broken app:

```bash
emulator -avd Pixel_8 -allow-host-audio
```

---

## The screen list

`integration_test/store_screenshots.dart` — 50 `shot()` calls, and the sequence
number in a filename is the index of the call that made it. **Reordering that
list invalidates `selection.json`**, which refers to those numbers.

`integration_test/store_demo_data.dart` holds the twelve seeded recordings the
screens display, in all five languages.

### What is real and what is seeded

Every frame is a real `adb screencap` of the real release-mode build. Nothing is
mocked up or retouched. Two things in them are seeded demo content, because a
fresh install has an empty recordings folder and `shoot` wipes app data before
every run:

* **The audio** is generated: 16 kHz mono PCM with a speech-like envelope,
  written through the app's own `buildWavHeader`. Every waveform on screen was
  therefore computed by the real `computePeaks` from a real file — no waveform
  is drawn from fake data.
* **The transcripts** are seeded, in the app's real `.txt` sidecar format, and
  rendered by the real UI — but they were **not** produced by SenseVoice during
  the run. The 228 MB model is a runtime download and capture happens with the
  radios off, so no capture run has the model on disk. They are written to look
  like what the model does produce: punctuated text, per-phrase segments with
  timings, and a genuinely per-segment detected-language list.

The recording made on-device in shots 28–31 and 46 is the exception: that is a
real recording, made by the real recorder with the foreground service running.
It is silence, because nobody is talking into the capture machine.

---

## What shipped, and why those eight

`selection.json` carries the reasoning per frame; the short version is that the
eight span the app's range instead of eight views of one list:

| # | Screen | Why it is worth a slot |
|---|---|---|
| 02 | `home_today` | The whole app in one frame: waveform, detected languages, transcript, record button |
| 05 | `search_spoken_words` | Search by what was **said**, with a tappable timestamp. The differentiator |
| 13 | `model_download_sheet` | The offline promise in the app's own words |
| 14 | `history_calendar` | The month grid that indexes the archive |
| 17 | `history_long_transcript` | What the archive becomes after a few weeks |
| 21 | `settings` | Storage as hours, not bytes — matters for a long-form recorder |
| 28 | `recording` | Recording in progress, with the hold-for-live-text panel |
| 32 | `dark_home` | Dark mode, hand-built rather than an inversion |

Suggested **display order** in the Console (drag there; upload order is lexical
by number): `02, 28, 05, 13, 14, 17, 32, 21`.

Deliberately not shipped: `11 transcript_copied` carries Android's own clipboard
chip, which is system UI the app cannot dismiss and which looks like a defect in
a listing. Every candidate is kept in `candidates/` regardless — nothing was
pruned.

## Tablets: capture them, but think before shipping them

**The app has no tablet layout.** There is not a single width breakpoint in
`lib/` — no `MediaQuery` size branch, no master-detail, no max-width clamp on
the recordings list. At the 600 dp and 960 dp the Console's tablet tiers imply,
the phone layout simply stretches: full-width tiles, transcripts running the
whole screen, the record bar marooned in the middle of a wide bar.

Play requires **zero** tablet screenshots (only the phone tier has a minimum, of
two), and a tablet tab full of stretched phone shots reads worse to a tablet
shopper than an empty one. So:

* **Recommended now:** ship phone only. Nothing is lost.
* **The real fix** is small and worth doing on its own merits: constrain the
  list content to something like 700 dp and centre it, the way
  `widgets/no_results.dart` already does for its empty state. Then the tablet
  tiers are worth capturing and the "not optimized for tablets" flag goes away.

This is a product finding, not a listing problem — recorded here because this is
where it was noticed.

## Locales

| ARB | Play listing | Translated | Recommendation |
|---|---|---|---|
| `en` | `en-US` | 117/117 | **Publish.** Default listing. |
| `ja` | `ja` | 117/117 | **Publish.** |
| `ko` | `ko` | 117/117 | **Publish.** |
| `zh_Hant` | `zh-TW` | 117/117 | **Publish.** Taiwan and Hong Kong are both served by Play. |
| `zh` | `zh-CN` | 117/117 | **Publish, with low expectations.** Play is not available in mainland China, so this listing reaches Simplified-Chinese readers elsewhere — Singapore, Malaysia, and the diaspora — and nothing else. It costs nothing to ship, since the translation already exists. |

All five are fully translated, and the listing copy and feature graphic exist
for all five. **Screenshots currently exist for `en-US` and `ja` only.** Play
falls back per-asset-type, so `ko`, `zh-CN` and `zh-TW` would show translated
text and their own feature graphic alongside the `en-US` screenshots until the
three remaining capture runs are done. That is a working listing, not a broken
one — but screenshots of an English UI under Korean copy is exactly the kind of
mismatch that costs installs, so finish the runs before publishing those three.

The UI languages and the *speech* languages are deliberately different sets. The
model recognises Mandarin, Cantonese, English, Japanese and Korean; the UI ships
in English, both Chinese scripts, Japanese and Korean, because Cantonese has no
separate written locale. Don't let a listing claim five UI languages and five
speech languages are the same five.
