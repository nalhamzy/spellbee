"""Compact newly generated clips, decode all and verify exact script coverage.

Provider originals are retained outside the app bundle in ignored .codex-run.
80 kbps / 24 kHz mono MP3 preserves speech bandwidth without pitch changes.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]


def main():
    manifest = json.loads((ROOT/'assets/audio/phrases/voice_manifest.json').read_text(encoding='utf-8-sig'))
    scripts = json.loads((ROOT/'tools/audio/scripts.json').read_text(encoding='utf-8-sig'))
    extra = ROOT/'tools/audio/adventure_scripts.json'
    if extra.exists(): scripts += json.loads(extra.read_text(encoding='utf-8-sig'))
    missing = [item['text'] for item in scripts if item['text'] not in manifest['texts']]
    if missing: raise RuntimeError(f'{len(missing)} scripts are not bundled')
    originals = ROOT/'.codex-run/voice-source'
    originals.mkdir(parents=True,exist_ok=True)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()

    def optimize(relative):
        path = ROOT/'assets'/relative
        if not path.name.startswith('bee_'): raise RuntimeError('Refusing to replace a legacy clip')
        original = originals/path.name
        if not original.exists(): shutil.copy2(path,original)
        temporary = path.with_suffix('.optimized.mp3')
        result = subprocess.run([ffmpeg,'-v','error','-y','-i',str(original),'-codec:a','libmp3lame',
                                 '-b:a','80k','-ac','1','-ar','24000',str(temporary)],capture_output=True,timeout=45)
        if result.returncode: raise RuntimeError(f'Encoding failed: {relative}')
        check = subprocess.run([ffmpeg,'-v','error','-i',str(temporary),'-f','null','-'],capture_output=True,timeout=45)
        if check.returncode or check.stderr: raise RuntimeError(f'Decode failed: {relative}')
        temporary.replace(path)
        return {'path':relative,'before':original.stat().st_size,'after':path.stat().st_size,
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

    paths = sorted(set(manifest['texts'].values()) | set(manifest['phrases'].values()))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        verified = list(pool.map(optimize,paths))
    report = {'format':'MP3, 80 kbps, 24000 Hz, mono; no pitch or silence manipulation',
              'exact_script_mappings':len(manifest['texts']), 'decoded_clips':len(verified),
              'bytes_before':sum(i['before'] for i in verified),
              'bytes_after':sum(i['after'] for i in verified),
              'assets':verified}
    (ROOT/'tools/audio/verification-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(f'{len(verified)} clips decoded; {report["bytes_before"]/1e6:.1f}MB -> {report["bytes_after"]/1e6:.1f}MB')


if __name__ == '__main__': main()
