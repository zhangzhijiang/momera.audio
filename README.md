# Momera Recorder

A simple, local-first **recorder** with optional **offline speech-to-text
transcription**. It captures audio today; the name is deliberately not
audio-specific, leaving room for other capture types later.

- **Package:** `com.idatagear.momerarecording`
- Record audio (16 kHz mono WAV — transcription-ready)
- Play back, manage, and delete recordings
- Transcribe any saved recording to text, fully offline, on demand

## Phase 1 scope

A single screen that records audio and lists the recordings. Each recording can
be transcribed to text using an offline model. There is no real-time/streaming
speech recognition — transcription is an explicit action run on a saved file.

## Architecture

```
lib/
  main.dart                                 App entry (single screen)
  core/
    services/
      audio_recording_service.dart          Records 16 kHz mono WAV
      audio_playback_service.dart           Playback (just_audio)
      transcription_service.dart            Offline file STT (sherpa_onnx + VAD)
      model_download_service.dart           Downloads the SenseVoice model
    utils/app_theme.dart                    Colors + theme
  data/
    models/recording.dart                   Recording value object
    repositories/recording_repository.dart  Filesystem store (no database)
  presentation/
    providers/                              Riverpod providers
    screens/home_screen.dart                The one screen
    widgets/                                 Record button, recording tile, etc.
  utils/model_asset_helper.dart             Resolves model/asset file paths
```

### Speech-to-text

Transcription uses [`sherpa_onnx`](https://pub.dev/packages/sherpa_onnx) with the
**SenseVoice** model and **Silero VAD**. The large model (~228 MB) is **not
bundled** — it is downloaded on first transcription via `ModelDownloadService`
and cached in the app documents directory. The small support files
(`tokens.txt`, `silero_vad.onnx`) are bundled under `assets/models/`.

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
