#!/usr/bin/env python3
"""Gera um pacote de curso `.zywny` (docs/plano/I04) a partir da pasta do
curso: `course.md` na raiz, `lessons/`, `media/`.

O zip de dentro é a pasta como está (só `course.md`, `lessons/*.md` e
`media/**`; ocultos e lixo de editor são ignorados, com aviso). O pacote
sai cifrado e assinado com a mesma chave das bibliotecas
(`tool/library_crypto.py`, D-LIC-CONFIANCA) — sem par novo.

    tool/build_course.py <pasta> [-o dist/<id>.zywny]

Antes de zipar, roda `dart run tool/zywny_course.dart validate <pasta>` e
para no erro (código != 0): pacote só sai de curso válido.
"""

import io
import re
import subprocess
import sys
import zipfile
from pathlib import Path

import library_crypto

PROJ = Path(__file__).resolve().parent.parent

# Lixo de editor que não entra no pacote (além de tudo que começa com ponto).
JUNK_NAMES = {
    "Thumbs.db",
    "desktop.ini",
}
JUNK_SUFFIXES = ("~", ".bak", ".swp", ".swo")
JUNK_PREFIXES = ("#",)


def is_junk(name: str) -> bool:
    return (
        name in JUNK_NAMES
        or name.endswith(JUNK_SUFFIXES)
        or name.startswith(JUNK_PREFIXES)
        or (name.startswith("#") and name.endswith("#"))
    )


def course_id(folder: Path) -> str:
    """O `id` do front matter de `course.md` (para o nome de saída)."""
    text = (folder / "course.md").read_text(encoding="utf-8")
    match = re.search(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    head = match.group(1) if match else text
    found = re.search(r"^id:\s*(.+?)\s*$", head, re.MULTILINE)
    if not found:
        raise ValueError("course.md sem `id` no front matter")
    return found.group(1).strip().strip("\"'")


def collect(folder: Path) -> tuple[list[tuple[str, Path]], list[str]]:
    """Os arquivos que entram no zip (`nome_no_zip`, caminho), mais os
    ignorados (para o aviso)."""
    kept: list[tuple[str, Path]] = []
    skipped: list[str] = []
    for path in sorted(folder.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(folder).as_posix()
        parts = relative.split("/")
        if any(part.startswith(".") for part in parts):
            skipped.append(relative)
            continue
        if parts[0] == "course.md" and len(parts) == 1 and path.suffix == ".md":
            kept.append((relative, path))
        elif (
            parts[0] == "lessons"
            and len(parts) == 2
            and path.suffix == ".md"
        ):
            kept.append((relative, path))
        elif parts[0] == "media" and len(parts) >= 2:
            if is_junk(parts[-1]):
                skipped.append(relative)
                continue
            kept.append((relative, path))
        else:
            skipped.append(relative)
    return kept, skipped


def main() -> int:
    args = sys.argv[1:]
    out: Path | None = None
    rest: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "-o" and i + 1 < len(args):
            out = Path(args[i + 1])
            i += 2
        else:
            rest.append(args[i])
            i += 1
    if len(rest) != 1 or any(a.startswith("-") for a in rest):
        print(__doc__, file=sys.stderr)
        return 2
    folder = Path(rest[0])
    if not folder.is_dir():
        print(f"ERRO: {folder} não é uma pasta.", file=sys.stderr)
        return 1

    validated = subprocess.run(
        ["dart", "run", "tool/zywny_course.dart", "validate", str(folder)],
        cwd=PROJ,
    )
    if validated.returncode != 0:
        print("ERRO: o curso não passou no validador; sem pacote.", file=sys.stderr)
        return validated.returncode or 1

    kept, skipped = collect(folder)
    if not any(name == "course.md" for name, _ in kept):
        print("ERRO: sem course.md na raiz da pasta.", file=sys.stderr)
        return 1
    for relative in skipped:
        print(f"AVISO: ignorado no pacote: {relative}", file=sys.stderr)

    if out is None:
        out = PROJ / "dist" / f"{course_id(folder)}.zywny"
    out.parent.mkdir(parents=True, exist_ok=True)

    plain = io.BytesIO()
    with zipfile.ZipFile(plain, "w", zipfile.ZIP_STORED) as z:
        for name, path in kept:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            # Data fixa + sem compressão: o zip de dentro é determinístico
            # (como em `tool/build_library.py`).
            z.writestr(info, path.read_bytes())
    key = library_crypto.load_private()
    tmp = out.with_suffix(out.suffix + ".tmp")
    tmp.write_bytes(library_crypto.seal(plain.getvalue(), key))
    tmp.replace(out)
    print(f"{out}: {len(kept)} arquivos, {out.stat().st_size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
