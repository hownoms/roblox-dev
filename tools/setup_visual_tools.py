"""Install pinned validation tools locally in this checkout; no system changes."""
import io
import pathlib
import urllib.request
import zipfile

base = pathlib.Path(__file__).resolve().parents[1] / '.tools'
base.mkdir(exist_ok=True)
releases = {
    'stylua': 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-windows-x86_64.zip',
    'luau': 'https://github.com/luau-lang/luau/releases/download/0.741/luau-windows.zip',
    'luau-lsp': 'https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.60.0/luau-lsp-win64.zip',
}
for name, url in releases.items():
    if (base / (name + '.exe')).exists():
        continue
    with urllib.request.urlopen(url) as response:
        data = response.read()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.namelist():
            if pathlib.Path(member).suffix == '.exe':
                (base / pathlib.Path(member).name).write_bytes(archive.read(member))
    print('Installed', name)
defs = base / 'globalTypes.d.luau'
if not defs.exists():
    defs.write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.60.0/scripts/globalTypes.d.luau').read())
print('Validation tools ready in', base)
