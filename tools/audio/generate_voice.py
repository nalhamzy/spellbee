"""Create reusable Bee Buddy speech from reviewed catalog scripts, never child data.

Existing production clips stay intact. Content-addressed new clips are cached;
only a complete successful run publishes the runtime manifest atomically.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import requests

ROOT = Path(__file__).resolve().parents[2]
MODEL = 'gpt-4o-mini-tts-2025-12-15'
VOICE = 'marin'
STYLE = ('You are Bee Buddy, a cheerful fictional animated spelling companion for children. '
         'Use a bright, youthful-character energy with a clear natural adult voice, warm curiosity, '
         'and gentle encouragement. Speak in clear standard American English. '
         'Never imitate a real child, use baby talk, squeak, shout, sing, exaggerate pitch, or add words. '
         'Read exactly the supplied text. Articulate every consonant and syllable accurately. '
         'A single word must be pronounced once, naturally, without introducing it or spelling it. '
         'For comma-separated capital letters, pronounce each letter name separately with a short pause. '
         'Keep short phrases lively and longer explanations unhurried. ')
PRONUNCIATION = {
    # Dictionary-backed American pronunciations, reviewed after sample ASR.
    # https://www.merriam-webster.com/dictionary/zeugma
    # https://dictionary.cambridge.org/pronunciation/english/cynosure
    'zeugma': 'Pronounce zeugma as ZOOG-muh, IPA /\u02c8zu\u02d0\u0261m\u0259/: zoo plus a hard g, then muh. Stress the first syllable. ',
    'cynosure': 'Pronounce cynosure as SIGH-nuh-shoor, IPA /\u02c8sa\u026an\u0259\u0283\u028ar/. The first syllable rhymes with eye. Stress the first syllable. ',
}


def credential():
    if os.environ.get('OPENAI_API_KEY'):
        return os.environ['OPENAI_API_KEY'].strip()
    cli = Path.home() / 'AppData/Roaming/npm/firebase.cmd'
    result = subprocess.run([str(cli), 'functions:secrets:access', 'OPENAI_API_KEY',
                             '--project', 'rhyme-aa29b', '--non-interactive'],
                            capture_output=True, text=True, timeout=60)
    key = next((s.strip() for s in result.stdout.splitlines() if s.strip().startswith('sk-')), None)
    if result.returncode or not key:
        raise RuntimeError('Could not load existing speech credential; credential output suppressed.')
    return key


def main():
    scripts = json.loads((ROOT/'tools/audio/scripts.json').read_text(encoding='utf-8-sig'))
    extra = ROOT/'tools/audio/adventure_scripts.json'
    if extra.exists():
        scripts += json.loads(extra.read_text(encoding='utf-8-sig'))
    key = credential()
    manifest = {'profile': 'bee-buddy-marin-v1', 'texts': {}, 'phrases': {}}
    report = {'model': MODEL, 'voice': VOICE, 'instructions': STYLE, 'expected': len(scripts), 'assets': [], 'failures': []}

    def generate(item):
        text = item['text']
        instructions = STYLE + PRONUNCIATION.get(item.get('word'), '')
        digest = hashlib.sha256(f'{MODEL}|{VOICE}|{instructions}|{text}'.encode()).hexdigest()[:24]
        relative = f'audio/words/bee_{digest}.mp3'
        path = ROOT/'assets'/relative
        cached = path.exists() and path.stat().st_size > 1000
        if not cached:
            for attempt in range(4):
                try:
                    response = requests.post('https://api.openai.com/v1/audio/speech',
                        headers={'Authorization': f'Bearer {key}'},
                        json={'model': MODEL, 'voice': VOICE, 'input': text, 'instructions': instructions,
                              'response_format': 'mp3', 'speed': 1.0}, timeout=100)
                    if response.status_code == 200 and len(response.content) > 1000:
                        temp = path.with_suffix('.part')
                        temp.write_bytes(response.content)
                        temp.replace(path)
                        break
                    if response.status_code not in (429,500,502,503,504):
                        raise RuntimeError(f'HTTP {response.status_code}')
                except requests.RequestException:
                    if attempt == 3:
                        raise RuntimeError('Speech provider network request failed') from None
                time.sleep(2 ** attempt)
            else:
                raise RuntimeError('Provider retries exhausted')
        return item, relative, hashlib.sha256(path.read_bytes()).hexdigest(), cached

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(generate,item):item for item in scripts}
        for count,future in enumerate(concurrent.futures.as_completed(futures),1):
            try:
                item,path,digest,cached = future.result()
                manifest['texts'][item['text']] = path
                if item.get('stub'):
                    manifest['phrases'][item['stub']] = path
                report['assets'].append({'path':path, 'kind':item['kind'], 'sha256':digest})
                if count % 25 == 0:
                    print(f'{count}/{len(scripts)} clips ready', flush=True)
            except Exception as error:
                report['failures'].append(futures[future])
                print(f'Clip failed: {type(error).__name__}: {error}', flush=True)
    (ROOT/'tools/audio/generation-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    if report['failures']:
        raise SystemExit(f'{len(report["failures"])} clips failed; runtime manifest not published.')
    path = ROOT/'assets/audio/phrases/voice_manifest.json'
    temporary = path.with_suffix('.part')
    temporary.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    temporary.replace(path)
    print(f'Published {len(manifest["texts"])} exact-text mappings and {len(manifest["phrases"])} phrases.',flush=True)


if __name__ == '__main__':
    main()
