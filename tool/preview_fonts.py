"""Injects the preview-only font into pubspec.yaml, under the flutter section.

Android supplies Roboto itself, so the shipped app does not bundle it.
CanvasKit has no such fallback and fetches it from a CDN, which fails offline.
An emoji font is deliberately not injected: CanvasKit promotes it over Roboto
and then renders no Latin text at all.
"""

FONTS = (
    '  fonts:\n'
    '    - family: Roboto\n'
    '      fonts:\n'
    '        - asset: assets/fonts/Roboto-Regular.ttf\n'
    '        - asset: assets/fonts/Roboto-Medium.ttf\n'
    '          weight: 500\n'
)

ANCHOR = 'flutter:\n  uses-material-design: true\n'

path = 'pubspec.yaml'
source = open(path).read()
if ANCHOR not in source:
    raise SystemExit('pubspec.yaml has no flutter: uses-material-design anchor')
open(path, 'w').write(source.replace(ANCHOR, ANCHOR + FONTS))
print('preview fonts injected')
