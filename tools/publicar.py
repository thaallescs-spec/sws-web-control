#!/usr/bin/env python3
"""Gera o index.xml do ReaPack a partir dos arquivos em Live/.

Uso (na raiz do repositório):
    python tools/publicar.py 2.1.1 "O que mudou nesta versão"
    git add -A && git commit -m "v2.1.1" && git push

O número de versão também é gravado no cabeçalho @version do script principal.
O ReaPack de quem já instalou mostra a atualização na próxima sincronização.
"""
import datetime
import pathlib
import re
import sys
import urllib.parse
import zipfile
from xml.sax.saxutils import escape, quoteattr

GITHUB_USER = "thaallescs-spec"
GITHUB_REPO = "sws-web-control"
BRANCH = "main"
AUTHOR = "Thalles"
INDEX_NAME = "SWS Web Control"
CATEGORY = "Live"
MAIN = "SWS Web Control.lua"
DESC = "SWS Web Control - setlist web (celular/tablet) para a Region Playlist do SWS"

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIVE = ROOT / CATEGORY


def raw_url(name: str) -> str:
    path = urllib.parse.quote(f"{CATEGORY}/{name}")
    return f"https://raw.githubusercontent.com/{GITHUB_USER}/{GITHUB_REPO}/{BRANCH}/{path}"


def provides(main_text: str):
    """Lê o bloco '-- @provides' do script principal: [(arquivo, é_ação)]."""
    out, inside = [], False
    for line in main_text.splitlines():
        if line.startswith("-- @provides"):
            inside = True
            continue
        if inside:
            m = re.match(r"^--\s{2,}(\[main\]\s*)?(.+?)\s*$", line)
            if not m:
                break
            out.append((m.group(2), bool(m.group(1))))
    return out


def build_windows_zip():
    """dist/SWS-Web-Control-Windows.zip: instalador de 2 cliques para quem não usa ReaPack."""
    inst = ROOT / "instalador-windows"
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / "SWS-Web-Control-Windows.zip"
    base = "SWS Web Control"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name in ("Instalar.bat", "Desinstalar.bat", "LEIA-ME.txt"):
            z.write(inst / name, f"{base}/{name}")
        # PowerShell 5 precisa de UTF-8 com BOM para ler os acentos
        ps1 = (inst / "instalador.ps1").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        z.writestr(f"{base}/arquivos/instalador.ps1", ("\ufeff" + ps1.replace("\n", "\r\n")).encode("utf-8"))
        for f in sorted(LIVE.iterdir()):
            if f.is_file():
                z.write(f, f"{base}/arquivos/{f.name}")
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    changelog = sys.argv[2] if len(sys.argv) > 2 else f"Versão {version}"

    main_path = LIVE / MAIN
    text = main_path.read_text(encoding="utf-8")
    text = re.sub(r"^-- @version .*$", f"-- @version {version}", text, count=1, flags=re.M)
    main_path.write_text(text, encoding="utf-8", newline="\n")

    files = provides(text)
    for name, _ in files:
        if not (LIVE / name).exists():
            sys.exit(f"Arquivo listado em @provides não existe: {CATEGORY}/{name}")

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    src = [f'        <source main="main">{escape(raw_url(MAIN))}</source>']
    for name, is_action in files:
        attrs = f'file={quoteattr(name)}' + (' main="main"' if is_action else "")
        src.append(f"        <source {attrs}>{escape(raw_url(name))}</source>")

    xml = f'''<?xml version="1.0" encoding="utf-8"?>
<index version="1" name={quoteattr(INDEX_NAME)}>
  <category name={quoteattr(CATEGORY)}>
    <reapack name={quoteattr(MAIN)} type="script" desc={quoteattr(DESC)}>
      <metadata>
        <link rel="website">https://github.com/{GITHUB_USER}/{GITHUB_REPO}</link>
      </metadata>
      <version name={quoteattr(version)} author={quoteattr(AUTHOR)} time="{now}">
        <changelog><![CDATA[{changelog}]]></changelog>
{chr(10).join(src)}
      </version>
    </reapack>
  </category>
</index>
'''
    (ROOT / "index.xml").write_text(xml, encoding="utf-8", newline="\n")
    z = build_windows_zip()
    print(f"index.xml gerado: versão {version}, {len(files) + 1} arquivos")
    print(f"instalador Windows: {z.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
