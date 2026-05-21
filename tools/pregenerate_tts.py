"""Pre-generate SpellBee's premium voice assets.

One-off script. Reads OPENAI_API_KEY from the environment, calls OpenAI's
/audio/speech endpoint for each phrase in `PHRASES` and each word in the
level 1–3 catalog, writes MP3s to `assets/audio/`, then exits. Skips any
file that already exists so reruns are cheap.

Usage:
    OPENAI_API_KEY=sk-... python tools/pregenerate_tts.py
    REFRESH_WORDS=1 OPENAI_API_KEY=sk-... python tools/pregenerate_tts.py

Cost is small for phrase refreshes; existing files are skipped on reruns.
"""
from __future__ import annotations

import os
import sys
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_WORDS = ROOT / "assets" / "audio" / "words"
OUT_PHRASES = ROOT / "assets" / "audio" / "phrases"

# Level 1-3 words, hard-coded here so this script stays self-contained.
# Keep in sync with lib/core/data/words_catalog.dart.
LEVEL_WORDS = [
    # Level 1
    "cat", "dog", "sun", "moon", "tree", "fish", "ball", "milk", "book",
    "home", "play", "jump", "bird", "cake", "rain",
    # Level 2
    "happy", "water", "apple", "bread", "cloud", "train", "plant", "sheep",
    "river", "night", "smile", "money", "dream", "sugar",
    # Level 3
    "school", "friend", "family", "pencil", "orange", "kitchen", "giraffe",
    "guitar", "window", "rocket", "castle", "bridge", "hungry", "thunder",
    "circle",
]

WORD_PROMPTS = [
    "{word}",
]

# (filename_stub, spoken_text). Two-beat pause marker is " ... ".
PHRASES = [
    # Encouragement on correct
    ("great",        "Great!"),
    ("nice_work",    "Nice work!"),
    ("perfect",      "Perfect!"),
    ("amazing",      "Amazing!"),
    ("you_got_it",   "You got it!"),
    ("wonderful",    "Wonderful!"),
    ("excellent",    "Excellent!"),
    ("awesome",      "Awesome!"),
    ("brilliant",    "Brilliant!"),
    ("fantastic",    "Fantastic!"),
    ("super_job",    "Super job!"),
    ("way_to_go",    "Way to go!"),
    ("nailed_it",    "Nailed it!"),
    ("great_spelling","Great spelling!"),
    ("well_done",    "Well done!"),
    ("keep_it_up",   "Keep it up!"),
    ("sharp_work",   "Sharp work!"),
    ("smart_spelling","Smart spelling!"),
    ("smooth_spelling","Smooth spelling!"),
    ("strong_spelling","Strong spelling!"),
    ("spelling_star","Spelling star!"),
    ("lovely_work",  "Lovely work!"),
    ("bright_work",  "Bright work!"),
    ("that_was_clear","That was clear!"),
    ("beautifully_done","Beautifully done!"),
    ("you_spelled_that_well","You spelled that well!"),
    # Miss
    ("not_quite",    "Not quite."),
    ("almost",       "Almost."),
    ("close_one",    "Close one."),
    ("good_try",     "Good try."),
    ("so_close",     "So close."),
    ("keep_trying",  "Keep trying."),
    ("good_effort",  "Good effort."),
    ("almost_there", "Almost there."),
    ("close_try",    "Close try."),
    ("check_the_letters","Check the letters."),
    ("no_worries",   "No worries."),
    ("try_again",    "Let's try that one again."),
    ("give_it_another_go","Give it another go."),
    ("one_more_try", "One more try."),
    ("reset_and_try","Reset and try again."),
    ("lets_try_again","Let's try again."),
    # Streak
    ("on_fire",      "On fire!"),
    ("three_row",    "Three in a row!"),
    ("unstoppable",  "Unstoppable!"),
    ("hot_streak",   "Hot streak!"),
    ("five_row",     "Five in a row!"),
    ("champion",     "Champion spelling!"),
    ("buzzing_along","You're buzzing along!"),
    ("streak_star",  "Streak star!"),
    ("smooth_run",   "Smooth run!"),
    ("great_rhythm", "Great rhythm!"),
    ("keep_going",   "Keep going!"),
    ("streak_power", "Streak power!"),
    # Session
    ("lets_begin",   "Let's begin."),
    ("test_complete","Test complete!"),
    ("new_best",     "New personal best!"),
    ("lesson_done",  "Lesson done!"),
    ("nice_practice","Nice practice!"),
]

MODEL = "gpt-4o-mini-tts"
VOICE = "nova"      # young, clear, kid-friendly
SPEED = 1.00        # natural pace — slowing below 1.0 adds artifacts

def bee_sentence(word: str) -> str:
    """Varied announce lines, deterministic per word for stable recordings."""
    idx = sum(ord(ch) for ch in word) % len(WORD_PROMPTS)
    return WORD_PROMPTS[idx].format(word=word)

def synth(api_key: str, text: str, dst: Path, *, overwrite: bool = False) -> None:
    if not overwrite and dst.exists() and dst.stat().st_size > 1000:
        return  # already cached
    dst.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=json.dumps({
            "model": MODEL,
            "voice": VOICE,
            "input": text,
            "response_format": "mp3",
            "speed": SPEED,
        }).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            if resp.status != 200:
                print(f"  FAIL [{resp.status}] {dst.name}", flush=True)
                return
            dst.write_bytes(resp.read())
            kb = dst.stat().st_size // 1024
            print(f"  ok  {dst.name}  {kb}KB", flush=True)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")[:200]
        print(f"  FAIL [{e.code}] {dst.name}: {body}", flush=True)
    except Exception as e:
        print(f"  FAIL {dst.name}: {e}", flush=True)

def main() -> int:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    refresh_words = os.environ.get("REFRESH_WORDS", "").strip() == "1"
    if not api_key:
        print("ERROR: set OPENAI_API_KEY in the environment.", file=sys.stderr)
        return 2

    print(f"Pre-generating {len(LEVEL_WORDS)} words + {len(PHRASES)} phrases...\n")

    print(f"-- words into {OUT_WORDS.relative_to(ROOT)} --")
    for w in LEVEL_WORDS:
        synth(
            api_key,
            bee_sentence(w),
            OUT_WORDS / f"{w}.mp3",
            overwrite=refresh_words,
        )
        time.sleep(0.15)  # gentle pacing

    print(f"\n-- phrases into {OUT_PHRASES.relative_to(ROOT)} --")
    for stub, text in PHRASES:
        synth(api_key, text, OUT_PHRASES / f"{stub}.mp3")
        time.sleep(0.15)

    # Summary
    words_ct = sum(1 for _ in OUT_WORDS.glob("*.mp3"))
    phrases_ct = sum(1 for _ in OUT_PHRASES.glob("*.mp3"))
    total_kb = sum(p.stat().st_size
                   for p in list(OUT_WORDS.glob("*.mp3")) +
                            list(OUT_PHRASES.glob("*.mp3"))) // 1024
    print(f"\ndone. {words_ct} words, {phrases_ct} phrases, {total_kb} KB total.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
