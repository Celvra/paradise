#!/usr/bin/env python3
"""Restore the hand formatting of the arb files after a json round trip.

json.dump expands every object onto its own lines. The committed style here
keeps each "@key": { "description": ..., "placeholders": {...} } on a single
line, which is why the files read as one key pair per line instead of four.

Rewriting that back by hand is not safe, several metadata objects carry a nested
placeholders map. So this re-emits the parsed document instead: top level keys
one per line, and any object value collapsed onto one line with json.dumps.

Usage: python3 tool/format_arb.py lib/l10n/arb/app_en.arb ...
"""
import json
import sys


def render(doc):
    # assembled without trailing commas on the last entry, neither JSON nor the
    # arb parser accepts one there
    entries = []
    for key, value in doc.items():
        if key == '@@locale':
            # the committed style leaves a blank line after the locale marker
            entries.append(f'  "{key}": {json.dumps(value, ensure_ascii=False)},')
            entries.append('')
        else:
            entries.append(f'  "{key}": {spaced(value)},')
    entries[-1] = entries[-1].rstrip(',')
    return '{\n' + '\n'.join(entries) + '\n}\n'


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(', ', ': '))


def spaced(value):
    """An object gets a space inside its braces, anything nested stays tight:
    { "description": "x", "placeholders": {"count": {"type": "int"}} }"""
    if isinstance(value, dict):
        return '{ ' + compact(value)[1:-1] + ' }'
    return compact(value)


def main(paths):
    for path in paths:
        with open(path, encoding='utf-8') as fh:
            original = fh.read()
        doc = json.loads(original)
        text = render(doc)
        if text == original:
            print(f'{path}: already formatted')
            continue
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)
        print(f'{path}: reformatted')


if __name__ == '__main__':
    main(sys.argv[1:])