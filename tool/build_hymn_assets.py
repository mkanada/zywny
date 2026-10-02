#!/usr/bin/env python3
"""Regenera assets/hinos/ a partir do Hymn_Grabber: os hinos que o app já
traz embutidos (a biblioteca de lib/library/ — o app não importa partitura).

Lê `musicxml/NNN.musicxml` e `musicxml_special/NNN.musicxml` (o especial
vence se os dois existirem) e grava:

  assets/hinos/NNN.musicxml.gz   a partitura, gzip (61 MB viram ~2,5 MB)
  assets/hinos/indice.json       número, título, autores e dificuldade de
                                 cada hino

A dificuldade vem de `musicxml/_dificuldade.csv` (o
`scripts/classificar-dificuldade.py` de lá): o nível de 1 a 5 e a nota
contínua, por onde a biblioteca ordena. Sem o arquivo, ou para um hino que
não está nele, o índice sai sem esses campos.

Não versionado (ver .gitignore): é derivado do Hymn_Grabber e as partituras
têm direitos de terceiros. Rode de novo depois que o extrator mudar.

  tool/build_hymn_assets.py [PASTA_DO_HYMN_GRABBER]
"""

import csv
import gzip
import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

PROJ = Path(__file__).resolve().parent.parent
DEFAULT_SRC = Path("/home/mauricio/IdeaProjects/Hymn_Grabber")
DST = PROJ / "assets" / "hinos"

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


def fold(text: str) -> str:
    """Minúsculas sem acento nem pontuação — chave de busca e de ordem."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    plain = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", plain).split())


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


def read_difficulty(src: Path) -> dict[int, tuple[int, float]]:
    """número -> (nível 1–5, nota de dificuldade) de `_dificuldade.csv`."""
    path = src / "musicxml" / "_dificuldade.csv"
    if not path.exists():
        print(f"AVISO: sem {path}; índice sem dificuldade", file=sys.stderr)
        return {}
    with open(path, encoding="utf-8", newline="") as f:
        return {
            int(row["hino"]): (int(row["nivel"]), float(row["dificuldade"]))
            for row in csv.DictReader(f)
        }


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    files: dict[int, Path] = {}
    for folder in ("musicxml", "musicxml_special"):
        for path in sorted((src / folder).glob("[0-9][0-9][0-9].musicxml")):
            files[int(path.stem)] = path
    if not files:
        print(f"ERRO: nenhum NNN.musicxml em {src}", file=sys.stderr)
        return 1

    DST.mkdir(parents=True, exist_ok=True)
    for old in DST.glob("*.musicxml.gz"):
        old.unlink()

    difficulty = read_difficulty(src)
    index = []
    total = 0
    for number, path in sorted(files.items()):
        head = read_header(path)
        title = title_case(head.get("title") or f"Hino {number}")
        creators = head["creators"]
        composer = creators.get("composer", "")
        lyricist = creators.get("lyricist", "")
        original = head["misc"].get("dcterms:alternative", "")
        entry = {
            "n": number,
            "t": title,
            "c": composer,
            # Letra só quando é de outra pessoa; título original se houver.
            **({"l": lyricist} if lyricist and lyricist != composer else {}),
            **({"o": original} if original else {}),
            # Nível (1–5) e nota de dificuldade, quando classificado.
            **(
                {"nv": difficulty[number][0], "d": difficulty[number][1]}
                if number in difficulty
                else {}
            ),
            "k": fold(title),
            "ck": fold(composer),
            "q": fold(f"{number} {title} {original} {composer} {lyricist}"),
        }
        index.append(entry)

        out = DST / f"{number:03d}.musicxml.gz"
        # mtime=0: saída idêntica para entrada idêntica.
        with open(out, "wb") as raw, gzip.GzipFile(
            fileobj=raw, mode="wb", compresslevel=9, mtime=0
        ) as gz:
            gz.write(path.read_bytes())
        total += out.stat().st_size

    (DST / "indice.json").write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(
        f"Gerado {DST}: {len(index)} hinos "
        f"({sum('nv' in e for e in index)} com dificuldade), "
        f"{total / 1e6:.1f} MB compactados (de {src})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
