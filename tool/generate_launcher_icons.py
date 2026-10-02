#!/usr/bin/env python3
"""Generate the Android launcher icon from assets/icon/icon.svg.

Run this after editing the source svg:

    python3 tool/generate_launcher_icons.py

It writes:

  android/app/src/main/res/drawable/ic_launcher_foreground.xml   adaptive foreground
  android/app/src/main/res/values/ic_launcher_background.xml     adaptive background colour
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml     adaptive icon
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml
  android/app/src/main/res/mipmap-*/ic_launcher.png              legacy, five densities
  android/app/src/main/res/mipmap-*/ic_launcher_round.png

Why this is a script and not a handful of exported files: the artwork has to land
in two geometries and six sizes, and doing that by hand means the next edit to
the source silently leaves five of the six stale.

The two geometries:

  adaptive  Android 8 and up. The canvas is 108dp but the launcher draws its own
            mask over it, so only the middle 72dp is reliably visible and only a
            66dp circle is safe on every device. The artwork is laid out for that
            smaller box and the background is a separate layer.

  legacy    Android 7 and below, and anything asking for a raw bitmap. No mask,
            so the artwork gets its own backdrop and may fill more of the frame.

The ink bounds are measured by rendering the source and asking ImageMagick for
its trim box, rather than parsed out of the path data. Editing the svg then does
not require touching this file.
"""

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'icon', 'icon.svg')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

GLYPH = '#000000'
BACKDROP = '#FFFFFF'

VIEWBOX = 100.0
# The artwork's height in dp on the 108dp adaptive canvas. The geometric bound
# is about 52, past which a round mask starts clipping the P, but filling the
# safe zone that tightly reads as oversized on a home screen, so this sits well
# under it. Run tool/preview_icon_sizes.py to see a range composited under the
# standard circle mask before changing it.
ADAPTIVE_DP = 30.0
# legacy has no mask over it, so it is allowed to sit larger in its frame
LEGACY_BOX = 40.0
# corner radius of the legacy backdrop, as a share of the canvas
LEGACY_RADIUS = 22.0

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def tool(name):
    path = shutil.which(name)
    if not path:
        sys.exit(f'{name} not found; needed to measure and render the artwork')
    return path


def measure():
    """Ink bounding box of the source, in its own viewBox units."""
    scratch = '/tmp/paradise_icons'
    os.makedirs(scratch, exist_ok=True)
    probe = os.path.join(scratch, 'probe.png')
    # 1000px wide makes the measured box accurate to a hundredth of a unit
    subprocess.run([tool('rsvg-convert'), '-w', '1000', '-h', '1000', '-o', probe, SRC], check=True)
    out = subprocess.run(
        [tool('magick'), probe, '-background', 'none', '-format', '%@', 'info:'],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    # WxH+X+Y
    wh, x, y = out.split('+', 1)[0], *out.split('+')[1:]
    w, h = (float(v) for v in wh.split('x'))
    x, y = float(x), float(y)
    k = VIEWBOX / 1000.0
    return x * k, y * k, (x + w) * k, (y + h) * k


def read_shape():
    """The path data, stroke width and the dot, straight out of the source."""
    import re
    svg = open(SRC, encoding='utf-8').read()
    m = re.search(r'<path\s+d="([^"]+)"(.*?)/>', svg, re.S)
    if not m:
        sys.exit('no <path d="..."> in the source svg')
    path = ' '.join(m.group(1).split())
    width = float(re.search(r'stroke-width="([\d.]+)"', m.group(2)).group(1))
    c = re.search(r'<circle\s+cx="([\d.]+)"\s+cy="([\d.]+)"\s+r="([\d.]+)"', svg)
    if not c:
        sys.exit('no <circle ...> in the source svg')
    return path, width, tuple(float(c.group(i)) for i in (1, 2, 3))


def fit(bbox, box, canvas):
    """Scale and translation centring the artwork in a canvas-long `box`."""
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    scale = box / max(w, h)
    tx = canvas / 2 - (x0 + w / 2) * scale
    ty = canvas / 2 - (y0 + h / 2) * scale
    return scale, tx, ty


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8').write(text)


def main():
    bbox = measure()
    path, width, (cx, cy, cr) = read_shape()
    print(f'ink bounds {bbox[0]:.1f},{bbox[1]:.1f} to {bbox[2]:.1f},{bbox[3]:.1f} '
          f'({bbox[2]-bbox[0]:.1f}x{bbox[3]-bbox[1]:.1f})')

    # ---------------------------------------------------------------- adaptive
    # viewport is the real 108 so the layout can be checked against the spec
    s, tx, ty = fit(bbox, ADAPTIVE_DP, 108)
    dot = (f'M{cx - cr:g} {cy:g} a{cr:g} {cr:g} 0 1 0 {cr * 2:g} 0 '
           f'a{cr:g} {cr:g} 0 1 0 -{cr * 2:g} 0')
    write(os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml'), f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_launcher_icons.py, do not edit by hand. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="{s:.6f}"
        android:scaleY="{s:.6f}"
        android:translateX="{tx:.6f}"
        android:translateY="{ty:.6f}">
        <path
            android:pathData="{path}"
            android:strokeColor="{GLYPH}"
            android:strokeWidth="{width:g}"
            android:strokeLineCap="round"
            android:strokeLineJoin="round" />
        <path
            android:pathData="{dot}"
            android:fillColor="{GLYPH}" />
    </group>
</vector>
''')

    write(os.path.join(RES, 'values', 'ic_launcher_background.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{BACKDROP}</color>\n'
          '</resources>\n')

    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_launcher_icons.py, do not edit by hand. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'''
    write(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), adaptive)
    write(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher_round.xml'), adaptive)
    print('adaptive icon and vector foreground written')

    # ------------------------------------------------------------------ legacy
    ls, ltx, lty = fit(bbox, LEGACY_BOX, VIEWBOX)

    def sheet(backdrop):
        if backdrop == 'square':
            bg = (f'  <rect x="0" y="0" width="{VIEWBOX:g}" height="{VIEWBOX:g}" '
                  f'rx="{LEGACY_RADIUS:g}" ry="{LEGACY_RADIUS:g}" fill="{BACKDROP}"/>\n')
        else:
            bg = f'  <circle cx="50" cy="50" r="50" fill="{BACKDROP}"/>\n'
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {VIEWBOX:g} {VIEWBOX:g}" '
                f'width="100" height="100">\n{bg}'
                f'  <g transform="translate({ltx:.4f} {lty:.4f}) scale({ls:.4f})">\n'
                f'    <path d="{path}" fill="none" stroke="{GLYPH}" stroke-width="{width:g}" '
                f'stroke-linecap="round" stroke-linejoin="round"/>\n'
                f'    <circle cx="{cx:g}" cy="{cy:g}" r="{cr:g}" fill="{GLYPH}"/>\n'
                f'  </g>\n</svg>\n')

    scratch = '/tmp/paradise_icons'
    os.makedirs(scratch, exist_ok=True)
    sources = {}
    for kind, backdrop in (('square', 'square'), ('round', 'circle')):
        p = os.path.join(scratch, f'legacy_{kind}.svg')
        open(p, 'w', encoding='utf-8').write(sheet(backdrop))
        sources[kind] = p

    for name, px in DENSITIES.items():
        out = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(out, exist_ok=True)
        for kind, target in (('square', 'ic_launcher.png'), ('round', 'ic_launcher_round.png')):
            subprocess.run(
                [tool('rsvg-convert'), '-w', str(px), '-h', str(px),
                 '-o', os.path.join(out, target), sources[kind]],
                check=True,
            )
    print('legacy pngs written: ' + ', '.join(f'{k} {v}px' for k, v in DENSITIES.items()))


if __name__ == '__main__':
    main()
