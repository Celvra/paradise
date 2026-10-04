#!/usr/bin/env python3
"""Rewrite the three arb files in the layout this repository already uses.
The checked in files put every "@key" metadata object on one line right under
its entry, and json.dump with indent=2 reflows the whole thing into a
thousand-line diff that hides the actual change. This puts the existing layout
back so a review sees only the keys that were added.
Run after editing an arb by hand, or after the generation scripts:
    python3 tool/format_arb.py
"""
import json
import re
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
ARB = ROOT / 'lib' / 'l10n' / 'arb'
def meta_inline(value):
    """One metadata object on one line, the way the files already had them."""
    parts = []
    for k, v in value.items():
        parts.append('%s: %s' % (json.dumps(k, ensure_ascii=False), json.dumps(v, ensure_ascii=False)))
    return '{ ' + ', '.join(parts) + ' }'
def write(path, data):
    out = []
    keys = list(data)
    first = True
    for key in keys:
        value = data[key]
        if key.startswith('@'):
            continue
        # the original files use no blank lines between entries, only after the
        # locale marker. inserting one per entry is a 1400 line diff
        if not first and key == 'appTitle':
            out.append('')
        first = False
        out.append('  %s: %s,' % (json.dumps(key, ensure_ascii=False), json.dumps(value, ensure_ascii=False)))
        meta = data.get('@' + key)
        if isinstance(meta, dict):
            out.append('  "@%s": %s,' % (key, meta_inline(meta)))
    # @@locale goes first, the generator wants it at the top
    if '@@locale' in data:
        out.insert(0, '  "@@locale": %s,' % json.dumps(data['@@locale']))
        out.insert(1, '')
    body = '\n'.join(out)
    # no trailing comma on the last entry. json.load rejects one, and a file this
    # tool wrote has to be readable by this tool
    body = re.sub(r',(\s*)$', r'\1', body)
    path.write_text('{\n' + body + '\n}\n', encoding='utf-8')
    print('%s: %d keys' % (path.name, len([k for k in keys if not k.startswith('@')])))
def main():
    for name in ('app_en.arb', 'app_zh.arb', 'app_zh_Hant.arb'):
        p = ARB / name
        write(p, json.loads(p.read_text(encoding='utf-8'), object_pairs_hook=dict))
    return 0
if __name__ == '__main__':
    sys.exit(main())