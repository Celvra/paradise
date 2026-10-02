"""Check where the generated adaptive foreground actually lands.

Reads the transform straight out of the generated vector drawable so this can
never drift from what the build actually ships.
"""
import math
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XML = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'drawable',
                   'ic_launcher_foreground.xml')
SCRATCH = '/tmp/paradise_icons'

xml = open(XML, encoding='utf-8').read()
g = re.search(r'<group\b(.*?)>', xml, re.S)
attrs = dict(re.findall(r'android:(\w+)="([-\d.]+)"', g.group(1)))
s = float(attrs['scaleX'])
tx = float(attrs['translateX'])
ty = float(attrs['translateY'])

# Android builds the group matrix as T * R * S, so scale lands before translate
X = lambda x: x * s + tx
Y = lambda y: y * s + ty

a, b, c, d = X(34), Y(24), X(77), Y(77)
print(f'transform scale {s} translate ({tx}, {ty})')
print(f'ink  x[{a:.2f},{c:.2f}] y[{b:.2f},{d:.2f}]  size {c - a:.2f}x{d - b:.2f}')
print(f'centre ({(a + c) / 2:.2f},{(b + d) / 2:.2f})   canvas centre (54.00,54.00)')
print(f'safe square margin  left/right {a - 18:.2f}dp  top/bottom {b - 18:.2f}dp')

# The furthest real ink, not a bounding-box corner. A corner of the bbox is
# empty space; what a mask can actually bite is the round cap on the stem, the
# far side of the bowl and the dot, each grown by its own radius.
marks = [(38, 28, 4), (38, 76, 4), (70, 42, 4), (56, 28, 4), (56, 56, 4),
         (72, 72, 5)]
worst = max(math.hypot(54 - X(x), 54 - Y(y)) + r * s for x, y, r in marks)
print(f'farthest ink {worst:.2f}dp   guaranteed circle radius 33dp   '
      + ('clear' if worst <= 33 else 'CLIPPED'))

os.makedirs(SCRATCH, exist_ok=True)
svg = os.path.join(SCRATCH, 'fg.svg')
open(svg, 'w', encoding='utf-8').write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="432" height="432">
  <rect width="108" height="108" fill="#FFFFFF"/>
  <g transform="translate({tx} {ty}) scale({s})">
    <path d="M38 72 V28 H56 a14 14 0 0 1 0 28 H38" fill="none" stroke="#000000" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="72" cy="72" r="5" fill="#000000"/>
  </g>
  <rect x="18" y="18" width="72" height="72" fill="none" stroke="#00C853" stroke-width="0.7" stroke-dasharray="3 3"/>
  <circle cx="54" cy="54" r="33" fill="none" stroke="#FF1744" stroke-width="0.7"/>
</svg>''')
png = os.path.join(SCRATCH, 'fg_check.png')
subprocess.run(['rsvg-convert', '-w', '432', '-h', '432', '-o', png, svg], check=True)
print(f'wrote {png}')