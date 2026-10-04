#!/usr/bin/env python3
"""Monta um pacote `.zywny` (ver docs/plano/B00): um zip com
`manifest.json`, `indice.json` e `partituras/<id>.musicxml.gz`.

Parte genérica, usada por `build_hymn_assets.py` (hinos) e pelo pacote dos
clássicos. Como módulo:

    from build_library import build_package, fold
    build_package(manifest, pieces, Path("dist/x.zywny"))

O pacote sai sempre cifrado e assinado (`library_crypto.py`, D-BIB-CIFRA)
com a chave privada de `keys/` — que não vai para o git.

`pieces` é uma lista de dicts com `id`, `musicxml` (caminho do arquivo) e os
campos do índice: `t`, `c` e, se quiser, `n`, `l`, `o`, `nv`, `d`, `a`.
`k`, `ck` e `q` são calculados aqui, com o mesmo `fold` do app
(`foldForSearch` em lib/library/hymn.dart); passe-os para sobrescrever.

Como programa, lê uma especificação JSON:

    tool/build_library.py especificacao.json saida.zywny [chave_privada.b64]

    {"manifest": {...}, "pecas": [{"id": "...", "musicxml": "...", ...}]}

com caminhos relativos à pasta da especificação.
"""

import gzip
import io
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path

import library_crypto

FORMAT = 1
LIBRARY_ID = re.compile(r"^[a-z0-9-]{1,40}$")
PIECE_ID = re.compile(r"^[A-Za-z0-9._-]{1,60}$")
INDEX_FIELDS = ("n", "t", "c", "l", "o", "nv", "d", "a", "k", "ck", "q")


def fold(text: str) -> str:
    """Minúsculas sem acento nem pontuação — chave de busca e de ordem."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    plain = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", plain).split())


def gzip_bytes(data: bytes) -> bytes:
    """gzip determinístico (mtime=0): entrada igual, saída igual."""
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9, mtime=0) as gz:
        gz.write(data)
    return buf.getvalue()


def index_entry(piece: dict, numbered: bool) -> dict:
    """Uma linha do `indice.json`, com as chaves de busca calculadas."""
    entry = {"id": piece["id"]}
    if numbered:
        entry["n"] = piece["n"]
    for key in ("t", "c", "l", "o", "nv", "d", "a"):
        if piece.get(key) not in (None, ""):
            entry[key] = piece[key]
    entry["k"] = piece.get("k") or fold(entry["t"])
    entry["ck"] = piece.get("ck") or fold(entry["c"])
    entry["q"] = piece.get("q") or fold(
        " ".join(
            str(x)
            for x in (
                piece.get("n") if numbered else "",
                entry["t"],
                entry.get("o", ""),
                entry["c"],
                entry.get("l", ""),
            )
        )
    )
    return entry


def build_package(
    manifest: dict,
    pieces: list[dict],
    out: Path,
    private_key: Path = library_crypto.KEYS / library_crypto.PRIVATE,
) -> dict:
    """Grava [out] (zip cifrado e assinado com [private_key]) e devolve
    estatísticas (`pecas`, `bytes`)."""
    key = library_crypto.load_private(private_key)
    manifest = {"formato": FORMAT, **manifest}
    if not LIBRARY_ID.match(manifest.get("id", "")):
        raise ValueError(f"id da biblioteca inválido: {manifest.get('id')!r}")
    numbered = bool(manifest["numerada"])
    seen: set[str] = set()
    index = []
    scores = []
    for piece in pieces:
        pid = piece["id"]
        if not PIECE_ID.match(pid):
            raise ValueError(f"id de peça inválido: {pid!r}")
        if pid in seen:
            raise ValueError(f"id de peça repetido: {pid!r}")
        seen.add(pid)
        if numbered and not isinstance(piece.get("n"), int):
            raise ValueError(f"peça {pid!r} sem número, numa biblioteca numerada")
        index.append(index_entry(piece, numbered))
        scores.append((pid, Path(piece["musicxml"])))

    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(out.suffix + ".tmp")
    plain = io.BytesIO()
    with zipfile.ZipFile(plain, "w", zipfile.ZIP_STORED) as z:
        def add(name: str, data: bytes) -> None:
            # Data fixa: o pacote sai idêntico se nada mudou. As partituras já
            # vão em gzip, então o zip só guarda (store).
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            z.writestr(info, data)

        add("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2).encode())
        add(
            "indice.json",
            json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode(),
        )
        for pid, path in scores:
            add(f"partituras/{pid}.musicxml.gz", gzip_bytes(path.read_bytes()))
    # Sal e nonce aleatórios: o arquivo muda a cada geração, mesmo sem mudança
    # no conteúdo (o zip de dentro é determinístico).
    tmp.write_bytes(library_crypto.seal(plain.getvalue(), key))
    tmp.replace(out)
    return {"pecas": len(index), "bytes": out.stat().st_size}


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(__doc__, file=sys.stderr)
        return 2
    spec_path = Path(sys.argv[1])
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    pieces = [
        {**p, "musicxml": spec_path.parent / p["musicxml"]} for p in spec["pecas"]
    ]
    key = (
        {"private_key": Path(sys.argv[3])} if len(sys.argv) == 4 else {}
    )
    stats = build_package(spec["manifest"], pieces, Path(sys.argv[2]), **key)
    print(f"{sys.argv[2]}: {stats['pecas']} peças, {stats['bytes'] / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
