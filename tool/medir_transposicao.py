#!/usr/bin/env python3
"""Q01: mede o Verovio transpondo (docs/plano/Q01-verovio-transpondo.md).

Para cada hino do Hymn_Grabber (os mesmos que entram em `dist/hinos.zywny`:
`musicxml/` e `musicxml_special/`, o especial vence), gera pelo CLI do fork
o `.vsb` original e o transposto pelo intervalo da tabela do Q00 ("Como
escolher a transposição") e compara os dois:

  * `midi.json`: mesmas entradas, na mesma ordem, com o mesmo tempo, pauta,
    camada e ligaduras, e `p` = original + k em TODAS (inclui os ids
    `-rend<N>` das repetições: se o documento expandido fosse transposto
    duas vezes, apareceria aqui);
  * `timemap.json` e `alternates.json`: iguais (mesmos ids, mesmos tempos);
  * `pitchpos.json`: o invariante do formato (`p` = altura(pn, o, alt) + sh)
    continua valendo no transposto; a armadura vigente em cada compasso (para
    o aviso "a partir do compasso N…") e os dobrados (alt = ±2);
  * `scene.json`: armadura inicial desenhada, acidentes visíveis (glifos
    E260-E264 numa classe `accid`) e os ids dos elementos musicais (notas, acordes, compassos, pautas,
    camadas, sílabas…) que sumiram;
  * faixa: a nota mais grave e a mais aguda nas duas direções, contra as 88
    teclas (21-108) e as 61 (36-96).

O catálogo só tem armaduras de 5♭ a 4♯; `--tabela` cobre as 14 linhas do Q00
com um hino em Dó levado ao tom da linha e de volta (as linhas +5, ±6 e ±7
não aparecem em nenhum hino).

Os ids do Verovio são aleatórios a cada render (dois renders do mesmo hino
já diferem), então os dois lados saem com `--xml-id-seed=1`, só para poder
comparar por id. `--determinismo` mede isso à parte.

O resultado é a tabela por armadura do Q01; `--json ARQUIVO` guarda os
números de cada hino. Nada é escrito no repo (os `.vsb` vão para um
diretório temporário).

  tool/medir_transposicao.py [--amostra N] [--hinos 013 200 …] [--jobs 4]
                             [--json saida.json] [--determinismo]
  tool/medir_transposicao.py --tabela
"""

import argparse
import collections
import json
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

BRIDGE = Path("/home/mauricio/rust_projects/verovio_flutter_bridge")
CLI = BRIDGE / "verovio" / "tools" / "verovio"
DATA = BRIDGE / "verovio" / "data"
FONTE = Path("/home/mauricio/IdeaProjects/Hymn_Grabber")

# Tabela do Q00: armadura (quintas, + sustenidos) -> (intervalo do Verovio, k).
# O trítono (±6) desce (D-TRP-DIRECAO); a outra direção fica em ALTERNATIVA.
TABELA = {
    1: ("P4", 5), 2: ("-M2", -2), 3: ("m3", 3), 4: ("-M3", -4),
    5: ("m2", 1), 6: ("-A4", -6), 7: ("-A1", -1),
    -1: ("-P4", -5), -2: ("M2", 2), -3: ("-m3", -3), -4: ("M3", 4),
    -5: ("-m2", -1), -6: ("-d5", -6), -7: ("A1", 1),
}  # fmt: skip
ALTERNATIVA = {6: ("d5", 6), -6: ("A4", 6)}

SUSTENIDOS = "fcgdaeb"
BEMOIS = "beadgcf"
LETRAS = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
FAIXA_88 = (21, 108)
FAIXA_61 = (36, 96)
REND = re.compile(r"-rend\d+$")
# Elementos que vêm da partitura (e mantêm o id ao transpor, com a mesma
# semente); hastes, sistemas, claves e armaduras são criados no layout, depois
# da transposição, e a sequência de ids deles se desloca.
MUSICAIS = {
    "note", "chord", "rest", "mRest", "measure", "staff", "layer", "syl",
    "verse", "harm", "beam", "barLine", "accid",
}  # fmt: skip
ACIDENTES = {
    "E260": "bemol", "E261": "bequadro", "E262": "sustenido",
    "E263": "dobrado sustenido", "E264": "dobrado bemol",
}  # fmt: skip


# ----------------------------------------------------------------- fonte


def listar_hinos(fonte: Path) -> dict[int, Path]:
    """número -> MusicXML, como `build_hymn_assets.build_entries`."""
    files: dict[int, Path] = {}
    for pasta in ("musicxml", "musicxml_special"):
        for path in sorted((fonte / pasta).glob("[0-9][0-9][0-9].musicxml")):
            files[int(path.stem)] = path
    return files


def ler_armaduras(path: Path) -> tuple[int | None, list[tuple[int, int]], bool]:
    """(armadura inicial, mudanças [(compasso, quintas)], tem <transpose>).

    O compasso é a posição (1 = primeiro `<measure>`), a mesma conta que
    `ordem_dos_compassos` faz no timemap. Mudança = valor diferente do vigente.
    """
    inicial: int | None = None
    mudancas: list[tuple[int, int]] = []
    compasso = 0
    parte = 0
    vigente: int | None = None
    transposto = False
    for evento, el in ET.iterparse(path, events=("start", "end")):
        if evento == "start":
            if el.tag == "part":
                parte += 1
                compasso = 0
            elif el.tag == "measure":
                compasso += 1
            continue
        if el.tag == "transpose":
            transposto = True
        elif el.tag == "fifths" and parte <= 1:  # as outras partes repetem
            try:
                valor = int((el.text or "").strip())
            except ValueError:
                continue
            if inicial is None:
                inicial = valor
            elif valor != vigente:
                mudancas.append((compasso, valor))
            vigente = valor
    return inicial, mudancas, transposto


# ----------------------------------------------------------------- render


def renderizar(origem: Path, saida: Path, transpor: str | None, seed: bool) -> None:
    cmd = [str(CLI), "--resource-path", str(DATA), "-t", "vsb", "-o", str(saida)]
    if seed:
        cmd.append("--xml-id-seed=1")
    if transpor:
        cmd.append(f"--transpose={transpor}")
    cmd.append(str(origem))
    subprocess.run(cmd, check=True, capture_output=True)


class Vsb:
    """Os arquivos do `.vsb` que a medição usa, lidos sob demanda."""

    def __init__(self, path: Path):
        self.zip = zipfile.ZipFile(path)
        self._cache: dict[str, object] = {}

    def __getitem__(self, nome: str):
        if nome not in self._cache:
            self._cache[nome] = json.loads(self.zip.read(f"{nome}.json"))
        return self._cache[nome]

    def tem(self, nome: str) -> bool:
        return f"{nome}.json" in self.zip.namelist()

    def bytes(self, nome: str) -> bytes:
        return self.zip.read(f"{nome}.json")


# ----------------------------------------------------------------- medidas


def quintas_da_armadura(key: dict | None) -> int | None:
    """`key` do pitchpos (alteração por letra) como quintas; `None` se a
    armadura não é uma das 15 padronizadas."""
    if not key:
        return 0
    valores = set(key.values())
    if valores == {1}:
        n = len(key)
        return n if set(key) == set(SUSTENIDOS[:n]) else None
    if valores == {-1}:
        n = len(key)
        return -n if set(key) == set(BEMOIS[:n]) else None
    return None


def ordem_dos_compassos(timemap: list, pitchpos: dict) -> list[tuple[int, int | None]]:
    """[(compasso, quintas)] do primeiro compasso de cada mudança de
    armadura, lendo só o timemap e o pitchpos.

    O compasso é a posição entre os `measureOn` sem `-rend<N>` (a ordem da
    primeira passagem). A armadura do compasso é a da primeira nota com
    entrada no pitchpos.
    """
    eventos = pitchpos["events"]
    compasso = 0
    ativo = False
    por_compasso: dict[int, int | None] = {}
    for entrada in timemap:
        medida = entrada.get("measureOn")
        if medida is not None:
            ativo = not REND.search(medida)
            if ativo:
                compasso += 1
        if not ativo:
            continue
        for id_ in entrada.get("on", []):
            ev = eventos.get(id_)
            if ev is not None and compasso not in por_compasso:
                por_compasso[compasso] = quintas_da_armadura(ev.get("key"))
    mudancas = []
    vigente: object = "?"
    for c in sorted(por_compasso):
        if por_compasso[c] != vigente:
            mudancas.append((c, por_compasso[c]))
            vigente = por_compasso[c]
    return mudancas


def altura(pn: str, oitava: int, alt: int) -> int:
    return 12 * (oitava + 1) + LETRAS[pn] + alt


def invariante_pitchpos(midi: dict, pitchpos: dict) -> int:
    """Quantas notas violam `p = altura(pn, o, alt) + sh` (o invariante do
    §2.8, que o documento transposto também precisa cumprir)."""
    eventos = pitchpos["events"]
    ruins = 0
    for n in midi["notes"]:
        if n.get("orn"):
            continue
        ev = eventos.get(REND.sub("", n["id"]))
        if ev is None or ev["t"] != "n":
            continue
        if altura(ev["pn"], ev["o"], ev["alt"]) + ev.get("sh", 0) != n["p"]:
            ruins += 1
    return ruins


def dobrados(pitchpos: dict) -> int:
    return sum(
        1
        for ev in pitchpos["events"].values()
        if ev["t"] == "n" and abs(ev["alt"]) == 2
    )


def percorrer_cena(cena: dict) -> dict:
    """Acidentes visíveis (por glifo), keyAccid da primeira armadura da
    página 1 e todos os ids."""
    visiveis: collections.Counter = collections.Counter()
    ids: set[str] = set()
    primeira_armadura: list[int] = []
    total_key_accid = 0

    def glifos(no: dict) -> list[str]:
        saida = []
        pilha = [no]
        while pilha:
            atual = pilha.pop()
            if atual.get("t") == "u":
                saida.append(atual["g"].split(":")[-1])
            pilha.extend(atual.get("children", []))
        return saida

    def andar(no: dict, pagina: int) -> None:
        nonlocal total_key_accid
        classe = no.get("class", "")
        if "id" in no and classe in MUSICAIS:
            ids.add(no["id"])
        if classe == "accid":
            for g in glifos(no):
                visiveis[ACIDENTES.get(g, "outro")] += 1
        elif classe == "keyAccid":
            total_key_accid += 1
        elif classe == "keySig" and pagina == 0 and not primeira_armadura:
            primeira_armadura.append(
                sum(1 for f in no.get("children", []) if f.get("class") == "keyAccid")
            )
        for filho in no.get("children", []):
            andar(filho, pagina)

    for i, pagina in enumerate(cena["pages"]):
        andar(pagina["root"], i)
    return {
        "visiveis": dict(visiveis),
        "total_visiveis": sum(visiveis.values()),
        "key_accid": total_key_accid,
        "armadura_inicial": primeira_armadura[0] if primeira_armadura else 0,
        "ids": ids,
    }


def ids_de(valor, saida: set) -> set:
    """Ids dos elementos musicais de `alternates`, sem `accid`: a
    transposição acrescenta acidentes gestuais (sem glifo) a quase toda nota."""
    if isinstance(valor, dict):
        classe = valor.get("class")
        if (
            isinstance(valor.get("id"), str)
            and classe in MUSICAIS
            and classe != "accid"
        ):
            saida.add(valor["id"])
        for v in valor.values():
            ids_de(v, saida)
    elif isinstance(valor, list):
        for v in valor:
            ids_de(v, saida)
    return saida


def comparar_midi(orig: dict, transp: dict, k: int) -> list[str]:
    a, b = orig["notes"], transp["notes"]
    if len(a) != len(b):
        return [f"midi: {len(a)} notas no original, {len(b)} no transposto"]
    problemas = []
    for i, (x, y) in enumerate(zip(a, b)):
        esperado = dict(x, p=x["p"] + k)
        if x["p"] + k != y["p"]:
            problemas.append(f"midi[{i}] {x['id']}: p {x['p']} -> {y['p']} (k={k})")
        elif esperado != y:
            problemas.append(f"midi[{i}] {x['id']}: {x} != {y}")
        if len(problemas) >= 3:
            break
    return problemas


def faixa(midi: dict, k: int) -> dict:
    ps = [n["p"] for n in midi["notes"]]
    return {"min": min(ps) + k, "max": max(ps) + k}


def fora(extremos: dict, limites: tuple[int, int]) -> bool:
    return extremos["min"] < limites[0] or extremos["max"] > limites[1]


# ----------------------------------------------------------------- um hino


def medir_hino(args: tuple[int, str, int, list]) -> dict:
    numero, caminho, fifths, mudancas_xml = args
    origem = Path(caminho)
    intervalo, k = TABELA[fifths]
    r: dict = {"hino": f"{numero:03d}", "fifths": fifths, "intervalo": intervalo, "k": k}
    tmp = Path(tempfile.mkdtemp(prefix=f"q01_{numero:03d}_"))
    problemas: list[str] = []
    try:
        renderizar(origem, tmp / "o.vsb", None, True)
        renderizar(origem, tmp / "t.vsb", intervalo, True)
        o, t = Vsb(tmp / "o.vsb"), Vsb(tmp / "t.vsb")
        problemas += comparar_midi(o["midi"], t["midi"], k)
        notas = o["midi"]["notes"]
        r["notas"] = len(notas)
        r["rend"] = sum(1 for n in notas if REND.search(n["id"]))
        r["ornamentos"] = sum(1 for n in notas if n.get("orn"))

        r["timemap_igual"] = o["timemap"] == t["timemap"]
        if not r["timemap_igual"]:
            problemas.append("timemap diferente")
        # `alternates.json` só existe quando o hino tem casas ou repetições com
        # páginas próprias; ausente nos dois lados conta como igual.
        sem = {"sequences": []}
        alt_o = o["alternates"] if o.tem("alternates") else sem
        alt_t = t["alternates"] if t.tem("alternates") else sem
        r["alternates_igual"] = (
            o.tem("alternates") == t.tem("alternates")
            and ids_de(alt_o, set()) == ids_de(alt_t, set())
            and len(alt_o["sequences"]) == len(alt_t["sequences"])
        )
        if not r["alternates_igual"]:
            problemas.append("alternates diferente")
        r["alternates"] = len(alt_o["sequences"])

        po, pt = o["pitchpos"], t["pitchpos"]
        r["invariante_antes"] = invariante_pitchpos(o["midi"], po)
        r["invariante_depois"] = invariante_pitchpos(t["midi"], pt)
        if r["invariante_depois"] > r["invariante_antes"]:
            problemas.append(
                f"pitchpos: {r['invariante_depois']} notas violam p = altura + sh"
            )
        r["dobrados_antes"] = dobrados(po)
        r["dobrados_depois"] = dobrados(pt)
        r["armaduras_antes"] = ordem_dos_compassos(o["timemap"], po)
        r["armaduras_depois"] = ordem_dos_compassos(t["timemap"], pt)
        # O que o pitchpos diz da armadura de cada compasso bate com o que o
        # MusicXML declara? (a via do aviso "a partir do compasso N…")
        r["armaduras_conferem"] = [list(m) for m in r["armaduras_antes"]] == [
            [1, fifths],
            *mudancas_xml,
        ]
        if not r["armaduras_depois"] or r["armaduras_depois"][0] != (1, 0):
            problemas.append(
                f"armadura inicial depois: {r['armaduras_depois'][:1]} (esperado 0)"
            )

        co, ct = percorrer_cena(o["scene"]), percorrer_cena(t["scene"])
        r["cena"] = {
            "key_accid_antes": co["key_accid"],
            "key_accid_depois": ct["key_accid"],
            "armadura_inicial_antes": co["armadura_inicial"],
            "armadura_inicial_depois": ct["armadura_inicial"],
            "visiveis_antes": co["total_visiveis"],
            "visiveis_depois": ct["total_visiveis"],
            "detalhe_antes": co["visiveis"],
            "detalhe_depois": ct["visiveis"],
            "ids_sumidos": len(co["ids"] - ct["ids"]),
            "ids_novos": len(ct["ids"] - co["ids"]),
        }
        if ct["armadura_inicial"] != 0:
            problemas.append(f"cena: armadura inicial com {ct['armadura_inicial']} acidentes")
        if co["ids"] - ct["ids"]:
            problemas.append(
                f"cena: {len(co['ids'] - ct['ids'])} ids musicais do original sumiram"
            )

        escolhida = faixa(o["midi"], k)
        outra = ALTERNATIVA.get(fifths)
        alternativa_k = k + 12 if k < 0 else k - 12
        r["faixa"] = {
            "original": faixa(o["midi"], 0),
            "transposta": faixa(t["midi"], 0),
            "escolhida": escolhida,
            "oposta": faixa(o["midi"], alternativa_k),
        }
        if r["faixa"]["transposta"] != escolhida:
            problemas.append("faixa do transposto != original + k")
        if outra is not None:
            r["tritono"] = True
    except Exception as erro:  # um hino que quebra não derruba a medição
        problemas.append(f"{type(erro).__name__}: {erro}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    r["problemas"] = problemas
    return r


# ----------------------------------------------------------------- relatório


def relatorio(todos_os_resultados: list[dict], todos: dict[int, dict]) -> None:
    # Um hino que quebrou no meio (render, JSON) não tem as medidas; aparece só
    # em "Problemas".
    resultados = [r for r in todos_os_resultados if "cena" in r]
    print("\n== Por armadura (transposto pelo intervalo da tabela do Q00) ==\n")
    cab = (
        "arm  intervalo   k  no catálogo testados notas   tudo igual a k      "
        "armadura ini a→d  acid. visíveis a→d  dobrados a→d"
    )
    print(cab)
    por = collections.defaultdict(list)
    for r in resultados:
        por[r["fifths"]].append(r)
    for f in sorted(por, key=lambda x: (x < 0, abs(x))):
        grupo = por[f]
        ok = sum(1 for r in grupo if not r["problemas"])
        print(
            f"{f:+3d}  {grupo[0]['intervalo']:>8} {grupo[0]['k']:+3d}  "
            f"{todos[f]['hinos']:>10} {len(grupo):>8} {sum(r['notas'] for r in grupo):>5}  "
            f"{ok:>3}/{len(grupo):<3} sem problema      "
            f"{max(r['cena']['armadura_inicial_antes'] for r in grupo):>4}→"
            f"{max(r['cena']['armadura_inicial_depois'] for r in grupo):<4}      "
            f"{sum(r['cena']['visiveis_antes'] for r in grupo):>5}→"
            f"{sum(r['cena']['visiveis_depois'] for r in grupo):<5}      "
            f"{sum(r['dobrados_antes'] for r in grupo):>3}→"
            f"{sum(r['dobrados_depois'] for r in grupo):<3}"
        )

    falhas = [r for r in todos_os_resultados if r["problemas"]]
    print(f"\n== Problemas: {len(falhas)} de {len(todos_os_resultados)} hinos ==")
    for r in falhas[:20]:
        print(f"  {r['hino']} ({r['fifths']:+d}): {'; '.join(r['problemas'])}")

    com_rend = [r for r in resultados if r["rend"]]
    print(f"\n== Repetições (ids -rend<N>) ==\n{len(com_rend)} hinos, "
          f"{sum(r['rend'] for r in com_rend)} notas expandidas, todas deslocadas "
          f"por k exatamente uma vez em "
          f"{sum(1 for r in com_rend if not r['problemas'])}/{len(com_rend)}.")
    if com_rend:
        exemplo = max(com_rend, key=lambda r: r["rend"])
        print(f"Maior: hino {exemplo['hino']} ({exemplo['rend']} notas -rend, "
              f"{exemplo['alternates']} sequências alternativas).")
    com_alt = [r for r in resultados if r["alternates"] > 1]
    print(f"Com páginas alternativas (alternates > 1 sequência): {len(com_alt)} hinos, "
          f"ids iguais em {sum(1 for r in com_alt if r['alternates_igual'])}.")
    print(f"Com ornamentos expandidos (orn): "
          f"{sum(1 for r in resultados if r['ornamentos'])} hinos.")

    print("\n== Dobrados (alt = ±2 no pitchpos) ==")
    d_antes = sum(r["dobrados_antes"] for r in resultados)
    d_depois = sum(r["dobrados_depois"] for r in resultados)
    com_dobrado = sum(1 for r in resultados if r["dobrados_depois"])
    print(f"Hinos com algum dobrado: {sum(1 for r in resultados if r['dobrados_antes'])} "
          f"antes, {com_dobrado} depois (de {len(resultados)}).")
    print(f"Antes {d_antes}, depois {d_depois} notas, em "
          f"{sum(1 for r in resultados if r['dobrados_depois'] > r['dobrados_antes'])} "
          f"hinos com mais dobrados que o original.")
    novos = sorted(
        (r for r in resultados if r["dobrados_depois"] > r["dobrados_antes"]),
        key=lambda r: -r["dobrados_depois"],
    )
    for r in novos[:8]:
        print(f"  {r['hino']} ({r['fifths']:+d}, {r['intervalo']}): "
              f"{r['dobrados_antes']} → {r['dobrados_depois']} "
              f"({r['cena']['detalhe_depois']})")

    print("\n== Mudança de armadura no meio ==")
    mudam = [r for r in resultados if len(r["armaduras_antes"]) > 1]
    print(f"{len(mudam)} de {len(resultados)} hinos testados têm mais de uma armadura.")
    piores = [
        r for r in mudam
        if any(
            fd is not None and abs(fd) > abs(fa)
            for (_, fa), (_, fd) in zip(r["armaduras_antes"][1:], r["armaduras_depois"][1:])
        )
    ]  # fmt: skip
    print(f"Em {len(piores)} deles a armadura que sobra tem MAIS acidentes que a "
          f"original nesse trecho; com 5 ou mais acidentes depois: "
          f"{sum(1 for r in mudam if any(f is not None and abs(f) >= 5 for _, f in r['armaduras_depois'][1:]))}.")
    sobra = collections.Counter()
    for r in mudam:
        for c, f in r["armaduras_depois"][1:]:
            sobra[f] += 1
    print(f"O pitchpos+timemap reproduz as armaduras do MusicXML (compasso e valor) em "
          f"{sum(1 for r in resultados if r['armaduras_conferem'])}/{len(resultados)} hinos.")
    print("Armaduras que sobram depois de transpor (quintas: ocorrências):",
          dict(sorted(sobra.items(), key=lambda kv: (kv[0] is None, kv[0] or 0))))
    for r in mudam[:12]:
        antes = " ".join(f"c{c}:{f:+d}" for c, f in r["armaduras_antes"])
        depois = " ".join(f"c{c}:{f if f is None else format(f, '+d')}"
                          for c, f in r["armaduras_depois"])
        print(f"  {r['hino']} ({r['intervalo']}): antes [{antes}] depois [{depois}]")

    print("\n== Faixa ==")
    for nome, lim in (("88 teclas (A0–C8)", FAIXA_88), ("61 teclas (C2–C7)", FAIXA_61)):
        orig = [r for r in resultados if fora(r["faixa"]["original"], lim)]
        esc = [r for r in resultados if fora(r["faixa"]["escolhida"], lim)]
        opo = [r for r in resultados if fora(r["faixa"]["oposta"], lim)]
        ambas = [r for r in esc if fora(r["faixa"]["oposta"], lim)]
        print(f"{nome}: fora no original {len(orig)}; fora na direção escolhida "
              f"{len(esc)}; fora na direção oposta {len(opo)}; fora nas duas {len(ambas)}")
    graves = min(resultados, key=lambda r: r["faixa"]["escolhida"]["min"])
    agudos = max(resultados, key=lambda r: r["faixa"]["escolhida"]["max"])
    print(f"Mais grave depois de transpor: {graves['faixa']['escolhida']['min']} "
          f"(hino {graves['hino']}); mais aguda: {agudos['faixa']['escolhida']['max']} "
          f"(hino {agudos['hino']}).")
    print(f"Mais grave do catálogo original: "
          f"{min(r['faixa']['original']['min'] for r in resultados)}; mais aguda: "
          f"{max(r['faixa']['original']['max'] for r in resultados)}.")


def sem_ids(texto: bytes) -> str:
    """O `scene.json` com cada id trocado pela ordem em que aparece: dois
    renders sem semente só podem diferir nos ids se o layout é o mesmo."""
    vistos: dict[str, str] = {}
    texto_ = re.sub(
        r'"id"\s*:\s*"([^"]+)"',
        lambda m: '"id": "#%d"' % vistos.setdefault(m[1], len(vistos)),
        texto.decode("utf-8"),
    )
    # Os marcadores de fim de sistema/página levam o id na classe.
    return re.sub(r"(MilestoneEnd) [a-z0-9]+", r"\1", texto_)


def determinismo(origem: Path, fifths: int) -> None:
    """Dois renders do mesmo hino: sem semente, com semente e transposto."""
    intervalo = TABELA[fifths][0]
    tmp = Path(tempfile.mkdtemp(prefix="q01_det_"))
    try:
        for rotulo, transpor, seed in (
            ("original sem semente", None, False),
            ("original com semente", None, True),
            (f"transposto ({intervalo}) com semente", intervalo, True),
        ):
            renderizar(origem, tmp / "a.vsb", transpor, seed)
            renderizar(origem, tmp / "b.vsb", transpor, seed)
            a, b = Vsb(tmp / "a.vsb"), Vsb(tmp / "b.vsb")
            difere = [n for n in a.zip.namelist() if a.zip.read(n) != b.zip.read(n)]
            bytes_iguais = (tmp / "a.vsb").read_bytes() == (tmp / "b.vsb").read_bytes()
            layout = sem_ids(a.bytes("scene")) == sem_ids(b.bytes("scene"))
            # O zip grava a hora de cada membro (resolução de 2 s): o arquivo
            # pode diferir por isso mesmo com o conteúdo igual.
            print(f"  {rotulo}: conteúdo dos membros "
                  f"{'IGUAL' if not difere else 'diferente em ' + ', '.join(difere)}; "
                  f"arquivo {'igual' if bytes_iguais else 'diferente'} byte a byte; "
                  f"cena igual descontados os ids: {'sim' if layout else 'NÃO'}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def tabela_completa(hinos: dict[int, Path]) -> bool:
    """As 14 linhas da tabela do Q00, inclusive as que o catálogo não tem
    (+5, ±6, ±7): leva um hino sem armadura para o tom da linha (o intervalo
    da linha oposta, em MEI), transpõe de volta pela linha e confere que
    volta ao hino original — mesma grafia (letra e alteração), armadura inicial
    vazia e altura = original + k de ida + k de volta."""
    base = None
    for numero, path in sorted(hinos.items()):
        inicial, mudancas, _ = ler_armaduras(path)
        if inicial == 0 and not mudancas:
            base = (numero, path)
            break
    if base is None:
        print("sem hino em Dó maior/Lá menor para usar de base", file=sys.stderr)
        return False
    numero, path = base
    print(f"\n== As 14 linhas da tabela (ida e volta com o hino {numero:03d}) ==\n")
    print("arm  volta      k   no tom da linha: armadura  voltou: armadura  grafia  altura")
    tudo_ok = True
    tmp = Path(tempfile.mkdtemp(prefix="q01_tab_"))
    try:
        renderizar(path, tmp / "base.vsb", None, True)
        base_vsb = Vsb(tmp / "base.vsb")
        ps_base = [n["p"] for n in base_vsb["midi"]["notes"]]
        spell_base = {
            i: (e["pn"], e["alt"])
            for i, e in base_vsb["pitchpos"]["events"].items()
            if e["t"] == "n"
        }
        ordem_base = [n["id"] for n in base_vsb["midi"]["notes"]]
        for f in sorted(TABELA, key=lambda x: (x < 0, abs(x))):
            ida, k_ida = TABELA[-f]
            volta, k_volta = TABELA[f]
            # MEI no tom da linha (a armadura vira |f| acidentes).
            mei = tmp / f"tom{f}.mei"
            subprocess.run(
                [str(CLI), "--resource-path", str(DATA), "-t", "mei",
                 "--xml-id-seed=1", f"--transpose={ida}", "-o", str(mei), str(path)],
                check=True, capture_output=True,
            )  # fmt: skip
            renderizar(mei, tmp / "no_tom.vsb", None, True)
            renderizar(mei, tmp / "volta.vsb", volta, True)
            no_tom, vo = Vsb(tmp / "no_tom.vsb"), Vsb(tmp / "volta.vsb")
            arm_no_tom = quintas_da_armadura(
                next(iter(no_tom["pitchpos"]["events"].values())).get("key")
            )
            desenhada = percorrer_cena(no_tom["scene"])["armadura_inicial"]
            arm_volta = ordem_dos_compassos(vo["timemap"], vo["pitchpos"])[:1]
            notas = vo["midi"]["notes"]
            spell_vo = {
                i: (e["pn"], e["alt"])
                for i, e in vo["pitchpos"]["events"].items()
                if e["t"] == "n"
            }
            grafia = spell_vo == spell_base
            alturas = [n["p"] for n in notas] == [p + k_ida + k_volta for p in ps_base]
            ids = [n["id"] for n in notas] == ordem_base
            ok = (
                arm_no_tom == f
                and desenhada == abs(f)
                and arm_volta == [(1, 0)]
                and grafia and alturas and ids
            )  # fmt: skip
            tudo_ok &= ok
            print(f"{f:+3d}  {volta:>6} {k_volta:+3d}   "
                  f"{arm_no_tom if arm_no_tom is None else format(arm_no_tom, '+d'):>7} "
                  f"({desenhada} desenhados)      "
                  f"{arm_volta[0][1] if arm_volta else '?':>4}          "
                  f"{'ok' if grafia else 'NÃO':>5}  {'ok' if alturas else 'NÃO':>5}"
                  f"{'' if ok else '   <- FALHOU'}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return tudo_ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--fonte", type=Path, default=FONTE)
    ap.add_argument("--hinos", nargs="*", help="só estes números (ex.: 013 200)")
    ap.add_argument("--amostra", type=int, help="no máximo N hinos por armadura")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--json", type=Path, help="grava o resultado de cada hino")
    ap.add_argument("--determinismo", action="store_true")
    ap.add_argument(
        "--tabela", action="store_true", help="só a ida e volta das 14 linhas"
    )
    args = ap.parse_args()

    if not CLI.exists():
        print(f"sem o CLI do fork: {CLI}", file=sys.stderr)
        return 1

    hinos = listar_hinos(args.fonte)
    if args.tabela:
        return 0 if tabela_completa(hinos) else 1
    if args.hinos:
        querem = {int(h) for h in args.hinos}
        hinos = {n: p for n, p in hinos.items() if n in querem}

    trabalhos: list[tuple[int, str, int, list]] = []
    totais: dict[int, dict] = collections.defaultdict(lambda: {"hinos": 0})
    sem_armadura = transpostores = 0
    por_armadura: collections.Counter = collections.Counter()
    for numero, path in sorted(hinos.items()):
        inicial, mudancas, tem_transpose = ler_armaduras(path)
        transpostores += tem_transpose
        if inicial is None:
            sem_armadura += 1
            continue
        totais[inicial]["hinos"] += 1
        if inicial == 0:
            continue
        if args.amostra and por_armadura[inicial] >= args.amostra:
            continue
        por_armadura[inicial] += 1
        trabalhos.append((numero, str(path), inicial, [list(m) for m in mudancas]))

    print(f"{len(hinos)} hinos; sem <fifths>: {sem_armadura}; com <transpose> "
          f"(instrumento transpositor): {transpostores}")
    print("Armaduras no catálogo (quintas: hinos):",
          dict(sorted((f, v["hinos"]) for f, v in totais.items())))
    print(f"Medindo {len(trabalhos)} hinos com armadura ≠ 0…", flush=True)

    with ProcessPoolExecutor(args.jobs) as pool:
        resultados = list(pool.map(medir_hino, trabalhos, chunksize=4))

    relatorio(resultados, totais)

    if args.determinismo and trabalhos:
        print("\n== Determinismo (hino "
              f"{trabalhos[0][0]:03d}, {trabalhos[0][2]:+d}) ==")
        determinismo(Path(trabalhos[0][1]), trabalhos[0][2])

    if args.json:
        args.json.write_text(
            json.dumps(resultados, ensure_ascii=False, indent=1), encoding="utf-8"
        )
    return 1 if any(r["problemas"] for r in resultados) else 0


if __name__ == "__main__":
    sys.exit(main())
