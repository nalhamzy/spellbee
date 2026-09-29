# Bee Buddy voice pack — 2026-09-29

The included pack contains **1,519 exact-text recordings**: all 360 authored
catalog words, their definitions, examples and letter-by-letter spellings,
59 feedback phrases and 20 Bee Adventures lines. Included playback is available
to free and paid learners. Selecting Studio changes unbundled/custom speech;
it does not replace the included voice. Premium entitlement checks are retained.

The OpenAI Speech API created this fictional, bright, friendly character voice
using `gpt-4o-mini-tts-2025-12-15` and built-in `marin`. It is AI-generated, not a
recording or clone of a real child. No child input is involved in generation.
Provider credentials are loaded privately from the environment or the existing
Firebase secret and are never printed or stored in the repository.

Official speech guide: https://developers.openai.com/api/docs/guides/text-to-speech
Official request parameters: https://developers.openai.com/api/reference/cli/resources/audio/subresources/speech/methods/create

## Reproduce

Run from the app directory with Python 3.12 and `requests` / `imageio-ffmpeg`:

```powershell
py -3.12 tools/audio/export_scripts.py
py -3.12 tools/audio/generate_voice.py
py -3.12 tools/audio/optimize_verify_voice.py
py -3.12 tools/audio/check_pronunciation.py
flutter test test/voice_playback_test.dart
```

Generation is content-addressed and resumes without regenerating completed
clips. The runtime manifest is published atomically only after every script
succeeds. Legacy production clips remain as fallback; provider originals are
retained outside the bundle under ignored `.codex-run/voice-source/`.

The new pack was reduced from **105.4 MB to 67.1 MB** using 80 kbps, 24 kHz,
mono MP3. There is no pitch modification or silence clipping. Every current
recording passed FFmpeg decoding and exact-script coverage; the verification
report records final bytes and SHA-256 hashes.

## Pronunciation review limits

Twenty isolated words spanning all eight levels were transcribed before and
after compression without giving the transcriber an expected-word prompt.
The final compact set matched 17/20 spellings exactly. `cat`/`Kat` and
`elephant`/`Elefant` are transcription spellings of the same sounds; isolated
`cynosure` remained ambiguous to the transcription model. These checks do not
certify every phoneme or replace educator listening review of championship
vocabulary. The full initial and final reports preserve the actual outputs.

The sample exposed an incorrect `zeugma` rendering; it was regenerated with
dictionary-backed guidance and now transcribes correctly before and after
compression. `cynosure` also received dictionary guidance. Sources:

- https://www.merriam-webster.com/dictionary/zeugma
- https://www.merriam-webster.com/dictionary/cynosure (lists both SIGH and SIN variants)
- https://dictionary.cambridge.org/pronunciation/english/cynosure

## Reliability changes

- Modern Flutter binary asset manifest support replaces the removed JSON path.
- Catalog clips, contexts and phrases play before any cloud or device fallback.
- Calm/Normal/Fast apply .88/1.0/1.15 playback; slow replay uses .75 even if
  the saved preference is Calm and never changes the saved setting.
- One router generation cancels superseded speech across all three engines.
- Pending manifest loads and gateway replies cannot start speech after stop.
- Native playback completion is subscribed before short clips start; native
  commands are serialized and cancellation resolves waiting callers.
- Fixed the gateway fetch's self-awaiting `whenComplete` callback, which could
  leave a successful uncached request waiting forever.
- Gateway responses require audio content; cached writes are atomic. Existing
  quotas and premium checks are unchanged. Online generation uses the same
  friendly style; updated Cloud Function code must accompany this client.
