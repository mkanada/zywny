#!/usr/bin/env python3
"""Preenche o sw.js de um build Web publicado (chamado por publish_web.sh).

Troca `const VERSION = 'dev';` pelo hash do conteúdo pré-cacheado (o worker
só muda — e o navegador só baixa a versão nova — quando algum arquivo muda)
e `const PRECACHE = [];` pela lista de arquivos que o app precisa para abrir
e tocar sem internet.

Fica de fora o que o app não carrega neste build (renderers skwasm/wimp, só
usados com `--wasm`; símbolos de depuração; imagens do mockup) e o que é
raro (NOTICES, só na tela de licenças): se alguém pedir, o worker guarda na
primeira vez que passar.

Uso: tool/web_precache.py <pasta do build>
"""
import hashlib
import json
import pathlib
import re
import sys

SKIP_FILES = {
    'sw.js', '.nojekyll', 'flutter.js', 'flutter_service_worker.js',
    'version.json', '.last_build_id', 'assets/NOTICES',
}
SKIP_PREFIXES = ('canvaskit/skwasm', 'canvaskit/wimp', 'canvaskit/webparagraph/', 'assets/assets/mockup/')
SKIP_SUFFIXES = ('.symbols', '.copyright')


def wanted(rel: str) -> bool:
    return (rel not in SKIP_FILES and not rel.startswith(SKIP_PREFIXES)
            and not rel.endswith(SKIP_SUFFIXES))


def main(root: pathlib.Path) -> None:
    files = sorted(p.relative_to(root).as_posix() for p in root.rglob('*')
                   if p.is_file() and '.git' not in p.relative_to(root).parts)
    precache = [f for f in files if wanted(f)]
    digest = hashlib.sha256()
    for rel in precache:
        digest.update(rel.encode() + b'\0' + (root / rel).read_bytes())
    version = digest.hexdigest()[:16]

    sw = root / 'sw.js'
    src = sw.read_text()
    src, n1 = re.subn(r"^const VERSION = 'dev';$", f"const VERSION = '{version}';", src, flags=re.M)
    src, n2 = re.subn(r'^const PRECACHE = \[\];$', 'const PRECACHE = ' + json.dumps(precache) + ';', src, flags=re.M)
    if n1 != 1 or n2 != 1:
        sys.exit('sw.js sem os marcadores VERSION/PRECACHE')
    sw.write_text(src)

    size = sum((root / f).stat().st_size for f in precache)
    print(f'sw.js: versão {version}, {len(precache)} arquivos, {size / 1e6:.1f} MB')


if __name__ == '__main__':
    main(pathlib.Path(sys.argv[1]))
