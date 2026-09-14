"""Points the built web app at its bundled CanvasKit instead of the CDN."""

path = 'build/web/flutter_bootstrap.js'
source = open(path).read()
source = source.replace(
    '_flutter.loader.load({\n  serviceWorkerSettings: {',
    '_flutter.loader.load({\n'
    '  config: { canvasKitBaseUrl: "canvaskit/" },\n'
    '  serviceWorkerSettings: {')
open(path, 'w').write(source)
print('canvaskit pinned to the local copy')
