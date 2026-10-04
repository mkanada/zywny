#!/usr/bin/env python3
"""Baixa a biblioteca musetrainer/library (MusicXML `.mxl`) para uma pasta fora
do repositório e extrai os metadados de cada partitura (B09).

  tool/fetch_classics.py [PASTA]      padrão: ~/IdeaProjects/zywny_classicos

Grava em PASTA:
  musetrainer_library/   clone raso do GitHub (git pull se já existe)
  xml/<nome>.musicxml    o MusicXML de dentro de cada `.mxl`
  metadados.tsv          título, compositor, direitos, software, compassos…

Não versionado: o repositório de origem não declara licença, então cada
partitura é conferida à mão antes de entrar num pacote (ver docs/plano/B09).
"""

import csv
import subprocess
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = "https://github.com/musetrainer/library"
DEFAULT = Path.home() / "IdeaProjects" / "zywny_classicos"


def inner_xml(mxl: Path) -> bytes:
    with zipfile.ZipFile(mxl) as z:
        container = ET.fromstring(z.read("META-INF/container.xml"))
        rootfile = container.find(".//{*}rootfile").get("full-path")
        return z.read(rootfile)


def metadata(data: bytes) -> dict:
    root = ET.fromstring(data)
    text = lambda path: (root.findtext(path) or "").strip()  # noqa: E731
    creators = {}
    for c in root.findall(".//identification/creator"):
        creators.setdefault(c.get("type") or "?", (c.text or "").strip())
    parts = root.findall("part")
    first = parts[0] if parts else None
    measures = len(first.findall("measure")) if first is not None else 0
    staves = ""
    fifths = ""
    time = ""
    if first is not None:
        s = first.find(".//attributes/staves")
        staves = s.text if s is not None else "1"
        f = first.find(".//attributes/key/fifths")
        fifths = f.text if f is not None else ""
        b = first.find(".//attributes/time/beats")
        t = first.find(".//attributes/time/beat-type")
        time = f"{b.text}/{t.text}" if b is not None and t is not None else ""
    notes = sum(1 for _ in root.iter("note"))
    return {
        "titulo": text("work/work-title") or text("movement-title"),
        "compositor": creators.get("composer", ""),
        "arranjador": creators.get("arranger", ""),
        "letrista": creators.get("lyricist", ""),
        "direitos": " | ".join(r.text.strip() for r in root.findall(".//identification/rights") if r.text),
        "software": text(".//identification/encoding/software"),
        "partes": len(parts),
        "pautas": staves,
        "compassos": measures,
        "armadura": fifths,
        "compasso": time,
        "notas": notes,
    }


def main() -> int:
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    dest.mkdir(parents=True, exist_ok=True)
    clone = dest / "musetrainer_library"
    if clone.exists():
        subprocess.run(["git", "-C", str(clone), "pull", "--ff-only", "-q"], check=True)
    else:
        subprocess.run(["git", "clone", "--depth", "1", "-q", REPO, str(clone)], check=True)
    commit = subprocess.run(
        ["git", "-C", str(clone), "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()
    (dest / "xml").mkdir(exist_ok=True)
    rows = []
    for mxl in sorted((clone / "scores").glob("*.mxl")):
        try:
            data = inner_xml(mxl)
            (dest / "xml" / f"{mxl.stem}.musicxml").write_bytes(data)
            rows.append({"arquivo": mxl.name, **metadata(data)})
        except Exception as e:  # noqa: BLE001
            rows.append({"arquivo": mxl.name, "titulo": f"ERRO: {e}"})
    cols = ["arquivo", "titulo", "compositor", "arranjador", "letrista", "direitos",
            "software", "partes", "pautas", "compassos", "armadura", "compasso", "notas"]
    with open(dest / "metadados.tsv", "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, cols, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} partituras de {REPO}@{commit[:10]} em {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
