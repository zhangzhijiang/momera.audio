# McRecorder

A simple, local-first **recorder** with **offline speech-to-text
transcription**. It captures audio today; the name is deliberately not
audio-specific, leaving room for other capture types later.

- **Package:** `com.idatagear.momerarecording`
- Record audio (16 kHz mono WAV — transcription-ready), including while
  backgrounded or with the screen locked
- Play back, rename, search, manage, and delete recordings
- Transcribe any saved recording to text, fully offline, on demand
- Watch a live transcript while recording, on a press-and-hold button
- Search recordings by what was said

## Scope

A single screen that records audio and lists the recordings. Each recording can
be transcribed to text using an offline model.

**On "live" transcription.** The press-and-hold live panel is *not* streaming
recognition. SenseVoice is a whole-utterance model, so the live path is
sherpa-onnx's "VAD + non-streaming ASR" pattern: audio feeds a voice-activity
detector and each *completed utterance* is decoded once the speaker pauses.
Text therefore arrives a phrase at a time, roughly a second behind the speaker,
and the panel is a rolling preview rather than the transcript of record — the
full text still comes from the on-demand pass over the saved file.

## Architecture

```
lib/
  main.dart                                 App entry
  core/
    services/
      audio_recording_service.dart          Records 16 kHz mono WAV
      vad_speech_detector.dart              Silero VAD behind the silence gate
      audio_playback_service.dart           Playback (just_audio)
      recording_session_channel.dart        Keeps capture alive in the background
      transcription_service.dart            Offline file STT (sherpa_onnx + VAD)
      live_transcription_service.dart       Press-and-hold live transcript
      decode_worker.dart                    Runs SenseVoice decodes off the UI isolate
      model_download_service.dart           Downloads the SenseVoice model
    audio/silence_gate.dart                 Drops silence from the recorded stream
    utils/app_theme.dart                    Colors + theme
  data/
    models/recording.dart                   Recording value object
    repositories/recording_repository.dart  Filesystem store (no database)
  presentation/
    providers/                              Riverpod providers
    screens/home_screen.dart                Recording, and today's recordings
    screens/history_screen.dart             Every recording, grouped by day
    screens/settings_screen.dart            Language, theme, auto-save, storage,
                                            History
    widgets/recording_calendar.dart         Month index over the archive
    widgets/                                 Record button, recording tile, etc.
  utils/model_asset_helper.dart             Resolves model/asset file paths
```

### Speech-to-text

Transcription uses [`sherpa_onnx`](https://pub.dev/packages/sherpa_onnx) with the
**SenseVoice** model and **Silero VAD**. The large model (~228 MB) is **not
bundled** — it is downloaded on first transcription via `ModelDownloadService`
and cached under **Application Support**, not Documents: it is re-downloadable,
and Apple rejects apps that put re-creatable data where iCloud backs it up. The
small support files (`tokens.txt`, `silero_vad.onnx`) are bundled under
`assets/models/`.

Decoding runs on a worker isolate (`decode_worker.dart`) that addresses the same
native recogniser as the main isolate — `OfflineRecognizer.decode` is a native
call with no yield point, so decoding in-process stalled the UI for the length
of the inference, once per utterance.

> Note: Google ML Kit has no speech-to-text API, so it is not used here. The
> native `speech_to_text` plugin only transcribes the live microphone, not saved
> files, so it does not fit the "transcribe a recording later" requirement —
> hence the offline `sherpa_onnx` file pipeline.

## Run

```bash
flutter pub get
flutter run
```

## Recording format

Recordings are saved as 16 kHz / mono / PCM16 WAV in the app's `recordings/`
directory. Transcripts are stored as sibling `<name>.txt` files.

Audio is written as raw `.pcm` while recording and only gets a WAV header when
the recording is finalised, so a crash or force quit loses at most one flush
interval — whatever was flushed is recovered on the next launch.

The home screen lists only what was recorded today; everything older is reached
through **Settings › History**, which groups the whole archive by day and is
where full-text search over every transcript lives (the home search covers
today, matching the list under it). A month calendar sits above that list and
marks the days that hold recordings; tapping one narrows the list to that day,
and tapping it again returns the whole archive. Days with nothing on them are
inert, so the marks are what tell you where to look. Rows alternate between two
near-identical backgrounds — banding that restarts at each day header, so a long
list can be read across without counting.

Playback is refused while a recording is in progress. Beyond the speaker bleeding
into the microphone, `just_audio` activates its own `.playback` audio session on
iOS, which would take the session away from `record_ios` mid-recording and end
the capture.

Silence is recorded like anything else by default — a quiet room consumes about
115 MB per hour — but **Skip silence** on the record panel changes that. With it
on, a `SilenceGate` runs Silero VAD over the incoming audio and writes only the
parts containing speech, plus 400 ms before each phrase (the detector needs a
quarter-second to be sure, by which time the first syllable is past) and 600 ms
after (so word tails and the gaps between words are not chopped). The gate keeps
the *original bytes* rather than the detector's segments: segments only arrive
once an utterance is over, and audio waiting in the detector is audio a crash
would lose. What survives is bit-identical to what the app would otherwise have
written — there is simply less of it, so the timer and the saved file are
shorter than the session. The 644 KB VAD model is bundled, so this works on a
device that never downloads the speech model; where it cannot run at all, the
app says so and keeps recording everything.

Two limits stop a recording: the storage cap in Settings, and the ~4 GiB (about
37 hours) a 32-bit RIFF size can describe.

## What a recording survives

A recording is meant to end when the user taps stop, and nothing else. What that
promise actually covers:

| | Recording continues |
|---|---|
| Screen locked | **Yes** |
| Another app in the foreground | **Yes** |
| Phone call answered mid-recording | **Yes** — the audio session resumes itself, and the call is simply missing from the file |
| Headset unplugged, Bluetooth dropped, mic momentarily stolen | **Yes** — capture is rebuilt, see below |
| Device dozing with the screen off | **Yes** — a partial wake lock is held for the length of the recording (Android) |
| App swiped out of the recents list, or force-quit | **No** — see below |
| Battery dies | **No**, but nothing flushed is lost |

**Interruptions are recovered from, not surrendered to.** If the capture stream
errors or ends without being asked, `AudioRecordingService` tears it down and
opens a new one, up to 20 times with a doubling backoff capped at three seconds
— about fifty seconds of trying. The file stays open throughout and the gap is
simply absent from the audio, which is honest: nothing was captured during it.
The UI says "Reconnecting…" while this happens, so a frozen timer never has to
be guessed at. Only after every attempt fails does the recording end, keeping
everything captured up to that point.

**Being swiped away is different, and cannot be fixed from Dart.** Capture is
owned by the `record` plugin, which lives in the Flutter engine, which is
destroyed with the activity — so on Android the recording ends when the task is
removed, and on iOS the system terminates the process outright. The service
therefore stops itself in `onTaskRemoved` rather than leaving a "Recording"
notification standing over a recording that is no longer happening, and the
foreground service is deliberately **not** `START_STICKY`: a service the system
restarts would have no engine behind it and would advertise the same lie. The
audio already flushed is finalised into a playable `.wav` on the next launch by
`recoverInterrupted`, so at most one auto-save interval is lost.

Surviving task removal would mean moving capture out of Dart and into the
Android service itself, writing the file natively. That is a real option if it
is ever needed; it is not what this app does today, and it would not help on
iOS, where a terminated app gets no execution at all.
