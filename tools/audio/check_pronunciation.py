"""Compare selected provider-original and compacted clips using transcription.

This catches missing/replaced words; it is not a phonetic expert's review.
No expected-word prompt is supplied to the transcription model.
"""
import concurrent.futures
import json
from pathlib import Path
import re
import requests
from generate_voice import credential

ROOT = Path(__file__).resolve().parents[2]
WORDS = ['cat','bag','friend','school','storm','castle','turtle','elephant',
         'accurate','valuable','tranquil','perceive','sarcastic','kaleidoscope',
         'ephemeral','cynosure','logomachy','onomatopoeia','zeugma','floccinaucinihilipilification']


def main():
    key = credential()
    manifest = json.loads((ROOT/'assets/audio/phrases/voice_manifest.json').read_text(encoding='utf-8-sig'))
    def check(word):
        relative = manifest['texts'][word]
        result = {'expected':word}
        for label,path in [('original',ROOT/'.codex-run/voice-source'/Path(relative).name),('compact',ROOT/'assets'/relative)]:
            with path.open('rb') as audio:
                response = requests.post('https://api.openai.com/v1/audio/transcriptions',
                    headers={'Authorization':f'Bearer {key}'}, files={'file':(path.name,audio,'audio/mpeg')},
                    data={'model':'gpt-4o-transcribe','language':'en'}, timeout=90)
            if response.status_code != 200:
                raise RuntimeError(f'Transcription failed: HTTP {response.status_code}')
            heard = response.json()['text'].strip()
            result[label] = heard
            result[label+'_matches'] = re.sub('[^a-z]','',heard.lower()) == re.sub('[^a-z]','',word.lower())
        return result
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(check,WORDS))
    report = {'method':'Unprompted gpt-4o-transcribe, 20 words spanning eight catalog levels',
              'limitation':'Lexical regression check, not a phonetic or child-usability certification',
              'original_matches':sum(i['original_matches'] for i in results),
              'compact_matches':sum(i['compact_matches'] for i in results),'samples':results}
    (ROOT/'tools/audio/pronunciation-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__ == '__main__': main()
