"""Preview candidate launcher-icon sizes side by side.

Picking ADAPTIVE_DP by rebuilding the APK and installing on a device is a slow
loop, and eyeballing the numbers does not tell you how it reads once a launcher
has put its own mask over it. This renders the same composite a launcher shows
-- white backdrop, artwork centred, the standard 72dp circle mask -- for a
range of sizes at once.

    python3 tool/preview_icon_sizes.py            # the usual suspects
    python3 tool/preview_icon_sizes.py 30 34 38   # specific values

Writes /tmp/paradise_icons/sheet.png.
"""
import os
import subprocess
import sys

SCRATCH = '/tmp/paradise_icons'
# ink bounds of the artwork, in its own viewBox units. Regenerate the icon
# first if the source svg has changed, then copy the numbers that
# generate_launcher_icons.py measured.
X0, Y0, X1, Y1 = 34.0, 24.0, 77.0, 77.0

GLYPH = (
    '<path d="M38 72 V28 H56 a14 14 0 0 1 0 28 H38" fill="none" stroke="#000" '
    'stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
    '<circle cx="72" cy="72" r="5" fill="#000"/>'
)

CELL = 200
PAD = 18
TOP = 26


def cell(index, dp):
    scale = dp / max(X1 - X0, Y1 - Y0)
    # this group already sits on the mask centre, so its origin is (0,0)
    # rather than the 54,54 canvas centre
    tx = -(X0 + (X1 - X0) / 2) * scale
    ty = -(Y0 + (Y1 - Y0) / 2) * scale
    ox = PAD + index * (CELL + PAD)
    return f'''<clipPath id="m{index}"><circle cx="0" cy="0" r="36"/></clipPath>
  <g transform="translate({ox + CELL / 2} {TOP + CELL / 2}) scale({CELL / 108})">
    <g clip-path="url(#m{index})">
      <rect x="-54" y="-54" width="108" height="108" fill="#fff"/>
      <g transform="translate({tx:.4f} {ty:.4f}) scale({scale:.4f})">{GLYPH}</g>
    </g>
  </g>
  <text x="{ox + CELL / 2}" y="{TOP + CELL + 22}" fill="#fff" font-size="17"
        font-family="monospace" text-anchor="middle">{dp}dp</text>'''


def main():
    values = [float(a) for a in sys.argv[1:]] or [26, 30, 34, 38, 42, 48]
    w = int(len(values) * (CELL + PAD) + PAD)
    h = TOP + CELL + 40
    os.makedirs(SCRATCH, exist_ok=True)
    svg = os.path.join(SCRATCH, 'sheet.svg')
    with open(svg, 'w', encoding='utf-8') as fh:
        fh.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" '
                 f'height="{h}" viewBox="0 0 {w} {h}">'
                 f'<rect width="{w}" height="{h}" fill="#5A6472"/>'
                 + ''.join(cell(i, v) for i, v in enumerate(values))
                 + '</svg>')
    png = os.path.join(SCRATCH, 'sheet.png')
    subprocess.run(['rsvg-convert', '-o', png, svg], check=True)
    print(f'{png}  values: {", ".join(f"{v:g}" for v in values)}')


if __name__ == '__main__':
    main()