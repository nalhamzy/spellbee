"""Export exact existing catalog prompts for offline speech; no child data.

The Dart coverage test checks these scripts against TtsService's real builders.
This deliberately rejects unexpected catalog syntax instead of skipping words.
"""
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DEFINITIONS = ['{word}. The meaning is: {definition}', 'Here is what {word} means: {definition}',
               'A clue for {word}: {definition}', 'Definition for {word}: {definition}',
               'Think about this meaning for {word}: {definition}']
EXAMPLES = ['Here is {word} in a sentence. {example}', 'Listen for {word} in this sentence. {example}',
            'A sentence with {word}. {example}', 'Here is one example for {word}. {example}',
            'In context, {word} sounds like this. {example}']
SPELLINGS = ['{word}. Spell it with me: {letters}.', 'Here are the letters for {word}: {letters}.',
             'Listen letter by letter. {word}: {letters}.', '{word}. The letters are: {letters}.']


def seed(word):
    value = 0
    for char in word:
        value = (value * 31 + ord(char)) & 0x7fffffff
    return value


def export():
    source = (ROOT/'lib/core/data/words_catalog.dart').read_text(encoding='utf-8-sig')
    quoted = r"'((?:\\.|[^'\\])*)'"
    raw = re.findall(r'Word\(\s*'+quoted+r'\s*,\s*'+quoted+r'\s*,\s*'+quoted, source)
    if len(raw) != len(re.findall(r'\bWord\(', source)):
        raise RuntimeError('Catalog syntax changed; refusing incomplete export')
    def unescape(text):
        return text.replace("\\'", "'").replace('\\n', '\n').replace('\\\\', '\\')
    lines = []
    for word, definition, example in (tuple(map(unescape, item)) for item in raw):
        value = seed(word)
        prompts = [('word', word),
                   ('definition', DEFINITIONS[value % len(DEFINITIONS)].format(word=word, definition=definition)),
                   ('example', EXAMPLES[value % len(EXAMPLES)].format(word=word, example=example)),
                   ('spelling', SPELLINGS[value % len(SPELLINGS)].format(word=word, letters=', '.join(word.upper())))]
        lines += [{'kind':kind, 'word':word, 'text':text} for kind,text in prompts]
    spec = importlib.util.spec_from_file_location('legacy_voice', ROOT/'tools/pregenerate_tts.py')
    legacy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(legacy)
    lines += [{'kind':'phrase', 'stub':stub, 'text':text} for stub,text in legacy.PHRASES]
    (ROOT/'tools/audio/scripts.json').write_text(json.dumps(lines,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Exported {len(raw)} words and {len(lines)} exact-source utterances.')


if __name__ == '__main__':
    export()
