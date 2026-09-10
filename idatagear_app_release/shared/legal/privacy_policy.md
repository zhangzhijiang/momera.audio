# Privacy Policy — Momera Recorder

**Last updated: 9 September 2026**

Momera Recorder is a voice recorder with on-device speech-to-text, published by
iDataGear.

The short version: **your recordings never leave your device.** We do not
collect them, we cannot read them, and there is no account or server to send
them to.

---

## What we collect

**Nothing.**

Momera Recorder has no account system, no analytics, no advertising, no crash
reporting and no tracking of any kind. We do not collect, transmit, store or
have access to any personal information about you.

## What stays on your device

These stay in the app's own private storage on your device, and are never
uploaded anywhere:

| What | Where |
|---|---|
| Your audio recordings (16 kHz mono WAV) | The app's `Documents/recordings` folder |
| Transcripts produced by speech-to-text | A `.txt` file beside each recording |
| Waveform caches | A `.peaks` file beside each recording |
| Your settings (language, theme, storage limit, auto-save interval) | Android's app preferences |
| The downloaded speech model | The app's private application-support folder |

Uninstalling the app removes all of it. Deleting a recording inside the app
removes its audio, its transcript and its waveform cache together.

## Speech-to-text runs on your device

Transcription is performed entirely on your device by a speech model that runs
locally. Your audio is **not** sent to us or to any third party for
transcription — not while recording, not afterwards, and not for the live text
shown while you record.

## The one network request the app makes

The app connects to the internet for exactly one purpose: **downloading the
speech model**, once, the first time you ask for text. The model is about
228 MB and is fetched from one of:

* `https://github.com` — our pinned release asset
* `https://huggingface.co` — a public copy of the same model, used only if the
  first source fails

This is an ordinary file download. No audio, no transcripts, no identifiers and
no personal information are sent with it. After the download completes,
transcription works with the device offline.

Those hosts will see the network request itself, including your IP address, as
they would for any file download. Their handling of that is governed by their
own privacy policies.

## When you choose to share

The app can share a recording's audio or its transcript through Android's share
sheet, and can copy a transcript to your clipboard. This only ever happens when
you tap Share or Copy. What happens to the content afterwards is governed by
whichever app you send it to. We are not involved and receive nothing.

## Permissions, and why each one exists

| Permission | Why |
|---|---|
| Microphone (`RECORD_AUDIO`) | To record audio. This is the app's purpose. |
| Internet (`INTERNET`) | Only to download the speech model, as described above. |
| Foreground service, microphone type (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`) | So a recording continues when you leave the app or lock the screen. Android requires a visible, persistent notification for the whole time this runs. |
| Notifications (`POST_NOTIFICATIONS`) | To show that recording notification. Recording still works if you deny it; you just do not get the notification. |
| Wake lock (`WAKE_LOCK`) | Held only while recording, so a device going to sleep does not cut your audio off. |

The app requests no location, camera, contacts, or shared-storage permissions,
and does not read files outside its own folder.

## Children

Momera Recorder is a general-purpose utility. It is not directed at children,
and because it collects no data it collects no data from children either.

## Your rights

Because we hold no data about you, there is nothing for us to disclose, export,
correct or delete. Your recordings are yours, on your device, under your
control: rename them, share them, delete them, or uninstall the app to remove
everything at once.

## Changes to this policy

If this policy changes, the "Last updated" date above changes with it. Because
the app collects nothing, any change would be a clarification rather than a new
use of your data.

## Contact

Questions about this policy: **zhangzhijiang@gmail.com**
