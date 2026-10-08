#!/usr/bin/env python3
"""Gera o pacote de hinos (`dist/hinos.zywny`) a partir do Hymn_Grabber.

Lê `musicxml/NNN.musicxml` e `musicxml_special/NNN.musicxml` (o especial
vence se os dois existirem) e monta, com `build_library.py`, a biblioteca
`hinos` (formato `.zywny`, ver docs/plano/B00): manifesto, índice (número,
título, autores e armadura de cada hino) e as partituras em gzip.

Cada hino leva também a versão simplificada de `musicxml_simplificado/NNN.musicxml`
(melodia, baixo e quinta; ver docs/versao-simplificada.md do Hymn_Grabber), quando
ela existe. Ela não é um hino a mais: vai como `partituras/NNN.simples.musicxml.gz`
e o índice marca `s` no mesmo hino. Não há classificação de dificuldade.

O pacote sai cifrado e assinado com a chave privada de `keys/` (gere o par
com `tool/library_crypto.py gen`; as chaves nunca vão para o git).

Não versionado (`dist/` está no .gitignore): é derivado do Hymn_Grabber e as
partituras têm direitos de terceiros — o pacote passa de mão em mão, o app não
diz de onde baixar e não traz hino nenhum. Rode de novo depois que o extrator
mudar.

  tool/build_hymn_assets.py [PASTA_DO_HYMN_GRABBER]
"""

import datetime
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from build_library import build_package, fold

PROJ = Path(__file__).resolve().parent.parent
# Vizinho deste repositório (pode ser symlink); HYMN_GRABBER sobrescreve.
DEFAULT_SRC = Path(os.environ.get("HYMN_GRABBER") or PROJ.parent / "Hymn_Grabber")
PACKAGE = PROJ / "dist" / "hinos.zywny"

# Palavras que ficam em minúscula no meio do título ("Ao Deus de Abraão
# Louvai"). Os PDFs trazem o título todo em maiúsculas.
MINOR = {
    "a", "à", "ao", "aos", "as", "às", "com", "da", "das", "de", "do", "dos",
    "e", "em", "na", "nas", "no", "nos", "o", "os", "ou", "para", "pela",
    "pelas", "pelo", "pelos", "por", "que", "se", "sem", "um", "uma",
}  # fmt: skip


def title_case(text: str) -> str:
    """'SANTO, SANTO, SANTO!' -> 'Santo, Santo, Santo!'."""
    if text != text.upper():
        return text  # já veio com caixa própria
    out = []
    for i, word in enumerate(text.lower().split()):
        core = word.strip("\"'“”‘’(),.;:!?…")
        if i > 0 and core in MINOR:
            out.append(word)
            continue
        # Só a primeira letra: depois de hífen quase sempre vem um pronome
        # ("Faz-me um Servo", "Achou-me").
        out.append(re.sub(r"^(\W*)(\w)", lambda m: m[1] + m[2].upper(), word))
    return " ".join(out)


def read_header(path: Path) -> dict:
    """Metadados do cabeçalho, sem carregar as notas (param no <part-list>)."""
    info: dict = {"creators": {}, "misc": {}}
    for _, el in ET.iterparse(path, events=("end",)):
        tag = el.tag
        if tag == "work-title":
            info["title"] = (el.text or "").strip()
        elif tag == "creator":
            info["creators"][el.get("type")] = (el.text or "").strip()
        elif tag == "miscellaneous-field":
            info["misc"][el.get("name")] = (el.text or "").strip()
        elif tag == "part-list":
            break
    return info


def read_fifths(path: Path) -> int | None:
    """Armadura do início: `<fifths>` do primeiro compasso (positivo =
    sustenidos, negativo = bemóis), ou None sem armadura."""
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == "fifths":
            try:
                return int((el.text or "").strip())
            except ValueError:
                return None
    return None


def build_entries(src: Path) -> list[dict]:
    """Os hinos do Hymn_Grabber como peças de pacote: `id`, `musicxml` e os
    campos do índice (as chaves de busca já calculadas, como sempre foram)."""
    files: dict[int, Path] = {}
    for folder in ("musicxml", "musicxml_special"):
        for path in sorted((src / folder).glob("[0-9][0-9][0-9].musicxml")):
            files[int(path.stem)] = path

    simplified = {
        int(path.stem): path
        for path in sorted((src / "musicxml_simplificado").glob("[0-9][0-9][0-9].musicxml"))
    }
    pieces = []
    for number, path in sorted(files.items()):
        head = read_header(path)
        title = title_case(head.get("title") or f"Hino {number}")
        creators = head["creators"]
        composer = creators.get("composer", "")
        lyricist = creators.get("lyricist", "")
        original = head["misc"].get("dcterms:alternative", "")
        fifths = read_fifths(path)
        pieces.append(
            {
                "id": f"{number:03d}",
                "musicxml": path,
                "n": number,
                "t": title,
                "c": composer,
                # Letra só quando é de outra pessoa; título original se houver.
                **({"l": lyricist} if lyricist and lyricist != composer else {}),
                **({"o": original} if original else {}),
                # Versão simplificada, quando o Hymn_Grabber a gerou.
                **({"simples": simplified[number]} if number in simplified else {}),
                # Armadura: sustenidos (+) ou bemóis (−) do início.
                **({"a": fifths} if fifths is not None else {}),
                "k": fold(title),
                "ck": fold(composer),
                "q": fold(f"{number} {title} {original} {composer} {lyricist}"),
            }
        )
    return pieces


def main() -> int:
    args = sys.argv[1:]
    if len(args) > 1 or any(a.startswith("-") for a in args):
        print(__doc__, file=sys.stderr)
        return 2
    src = Path(args[0]) if args else DEFAULT_SRC
    pieces = build_entries(src)
    if not pieces:
        print(f"ERRO: nenhum NNN.musicxml em {src}", file=sys.stderr)
        return 1

    manifest = {
        "id": "hinos",
        "nome": "Hinário",
        "versao": datetime.date.today().strftime("%Y.%m.%d"),
        "termo": {"singular": "hino", "plural": "hinos", "genero": "m"},
        "numerada": True,
        "creditos": "Hinos montados do Hymn_Grabber. Uso privado: as "
        "partituras têm direitos de terceiros.",
        "idioma": "pt-BR",
    }
    stats = build_package(manifest, pieces, PACKAGE)
    simples = sum("simples" in p for p in pieces)
    print(
        f"Gerado {PACKAGE}: {stats['pecas']} hinos ({simples} com versão simplificada), "
        f"{stats['bytes'] / 1e6:.1f} MB (de {src})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
