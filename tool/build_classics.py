#!/usr/bin/env python3
"""Gera o pacote dos clássicos (`dist/classicos.zywny`, B10).

Lê os MusicXML que `tool/fetch_classics.py` baixou do musetrainer/library
(`~/IdeaProjects/zywny_classicos/xml/`) e monta, com `build_library.py`, a
biblioteca `classicos` com as 43 peças aprovadas no B09 (grupos A e B). Os
títulos e compositores são os da tabela abaixo, não os do XML (22 arquivos
não trazem nenhum).

Sem dificuldade: a biblioteca não classifica mais as peças (ver
docs/plano/B10 e o `build_hymn_assets.py`).

O pacote sai cifrado e assinado com a chave privada de `keys/`. Não
versionado (`dist/` está no .gitignore): os arquivos são transcrições da
comunidade MuseScore, de direitos não verificáveis — uso privado.

  tool/build_classics.py [PASTA_DOS_CLASSICOS] [PASTA_DO_HYMN_GRABBER]
"""

import datetime
import sys
from pathlib import Path

from build_hymn_assets import read_fifths
from build_library import build_package

PROJ = Path(__file__).resolve().parent.parent
DEFAULT_SRC = Path.home() / "IdeaProjects" / "zywny_classicos"
PACKAGE = PROJ / "dist" / "classicos.zywny"

BACH = "Johann Sebastian Bach"
BEETHOVEN = "Ludwig van Beethoven"
CHOPIN = "Frédéric Chopin"
DEBUSSY = "Claude Debussy"
JOPLIN = "Scott Joplin"
LISZT = "Franz Liszt"
MOZART = "Wolfgang Amadeus Mozart"
PACHELBEL = "Johann Pachelbel"
SATIE = "Erik Satie"
SCHUBERT = "Franz Schubert"
TCHAIKOVSKY = "Piotr Ilitch Tchaikovsky"

# (id, arquivo sem extensão, título, compositor, catálogo) — a lista do B09.
PIECES = [
    # Grupo A
    ("bach-minueto-sol", "Bach_Minuet_in_G_Major_BWV_Anh._114",
     "Minueto em Sol", "Christian Petzold (atrib. Bach)", "BWV Anh. 114"),
    ("bach-preludio-1", "Prelude_I_in_C_major_BWV_846_-_Well_Tempered_Clavier_First_Book",
     "Prelúdio nº 1 em Dó", BACH, "BWV 846"),
    ("bach-preludio-2", "Prelude_No._2_BWV_847_in_C_Minor",
     "Prelúdio nº 2 em Dó menor", BACH, "BWV 847"),
    ("pachelbel-canone-facil", "Canon_in_D_easy",
     "Cânone em Ré (fácil)", PACHELBEL, "P. 37"),
    ("pachelbel-canone", "Canon_in_D", "Cânone em Ré", PACHELBEL, "P. 37"),
    ("beethoven-fur-elise-facil", "Fur_Elise_Easy_Piano",
     "Für Elise (fácil)", BEETHOVEN, "WoO 59"),
    ("beethoven-fur-elise-iniciante", "Fur_Elise_-_Beethoven_-_for_beginner_piano",
     "Für Elise (iniciante)", BEETHOVEN, "WoO 59"),
    ("beethoven-fur-elise", "Fur_Elise", "Für Elise", BEETHOVEN, "WoO 59"),
    ("beethoven-ode-alegria", "Ode_to_Joy_Easy_variation",
     "Ode à Alegria (variação fácil)", BEETHOVEN, "Op. 125"),
    ("satie-gymnopedie-1", "Gymnopdie_No._1__Satie", "Gymnopédie nº 1", SATIE, ""),
    ("satie-gnossienne-1", "Gnossienne_No._1", "Gnossienne nº 1", SATIE, ""),
    ("chopin-preludio-4", "Prlude_No._4_in_E_Minor_Op._28_-_Frdric_Chopin",
     "Prelúdio em Mi menor", CHOPIN, "Op. 28 nº 4"),
    ("chopin-noturno-9-2", "Chopin_-_Nocturne_Op_9_No_2_E_Flat_Major",
     "Noturno em Mi bemol", CHOPIN, "Op. 9 nº 2"),
    ("chopin-noturno-9-1", "Chopin_-_Nocturne_Op._9_No._1",
     "Noturno em Si bemol menor", CHOPIN, "Op. 9 nº 1"),
    ("chopin-valsa-la-menor", "Waltz_in_A_MinorChopin",
     "Valsa em Lá menor", CHOPIN, "B. 150"),
    ("chopin-valsa-64-2", "Waltz_Opus_64_No._2_in_C_Minor",
     "Valsa em Dó# menor", CHOPIN, "Op. 64 nº 2"),
    ("chopin-noturno-postumo", "Nocturne_in_C_sharp_Minor",
     "Noturno em Dó# menor (póstumo)", CHOPIN, "B. 49"),
    ("debussy-arabesque-1", "Arabesque_L._66_No._1_in_E_Major",
     "Arabesque nº 1", DEBUSSY, "L. 66"),
    ("debussy-clair-de-lune", "Clair_de_Lune__Debussy",
     "Clair de Lune", DEBUSSY, "L. 75"),
    ("liszt-liebestraum-3", "Liebestraum_No._3_in_A_Major",
     "Liebestraum nº 3", LISZT, "S. 541"),
    ("beethoven-luar-1", "Sonate_No._14_Moonlight_1st_Movement",
     "Sonata ao Luar, 1º mov.", BEETHOVEN, "Op. 27 nº 2"),
    ("beethoven-patetica-2", "Sonate_No._8_Pathetique_2nd_Movement",
     "Sonata Patética, 2º mov.", BEETHOVEN, "Op. 13"),
    ("mozart-sonata-545-1", "Sonata_No._16_1st_Movement_K._545",
     "Sonata em Dó, 1º mov.", MOZART, "K. 545"),
    ("mozart-rondo-turca", "Piano_Sonata_No._11_K._331_3rd_Movement_Rondo_alla_Turca",
     "Rondo alla Turca", MOZART, "K. 331"),
    ("brahms-danca-hungara-5", "Hungarian_Dance_No_5_in_G_Minor",
     "Dança Húngara nº 5", "Johannes Brahms", "WoO 1"),
    ("joplin-entertainer", "The_Entertainer_-_Scott_Joplin_-_1902",
     "The Entertainer", JOPLIN, ""),
    ("joplin-maple-leaf", "Maple_Leaf_Rag_Scott_Joplin", "Maple Leaf Rag", JOPLIN, ""),
    ("beethoven-luar-3", "moonlight_sonata_3rd_movement",
     "Sonata ao Luar, 3º mov.", BEETHOVEN, "Op. 27 nº 2"),
    ("bach-tocata-fuga", "Bach_Toccata_and_Fugue_in_D_Minor_Piano_solo",
     "Tocata e Fuga em Ré menor", BACH, "BWV 565"),
    ("rimski-voo-besouro", "Flight_of_the_Bumblebee",
     "O Voo do Besouro", "Nikolai Rimski-Kórsakov", ""),
    ("liszt-campanella", "La_Campanella_-_Grandes_Etudes_de_Paganini_No._3_-_Franz_Liszt",
     "La Campanella", LISZT, "S. 141 nº 3"),
    ("chopin-balada-1", "Chopin_-_Ballade_no._1_in_G_minor_Op._23",
     "Balada nº 1", CHOPIN, "Op. 23"),
    ("mozart-variacoes-ah-vous", "12_Variations_of_Twinkle_Twinkle_Little_Star",
     "12 Variações “Ah vous dirai-je, maman”", MOZART, "K. 265"),
    ("beethoven-sinfonia-5-1", "Beethoven_Symphony_No._5_1st_movement_Piano_solo",
     "5ª Sinfonia, 1º mov. (piano solo)", BEETHOVEN, "Op. 67"),
    # Grupo B
    ("tchaikovsky-lago-cisnes", "Swan_Lake",
     "O Lago dos Cisnes (tema)", TCHAIKOVSKY, "Op. 20"),
    ("tchaikovsky-fada-acucarada", "Dance_of_the_sugar_plum_fairy",
     "Dança da Fada Açucarada", TCHAIKOVSKY, "Op. 71"),
    ("tchaikovsky-valsa-flores", "Waltz_of_the_Flowers",
     "Valsa das Flores", TCHAIKOVSKY, "Op. 71"),
    ("mozart-lacrimosa", "Lacrimosa_-_Requiem", "Lacrimosa (Réquiem)", MOZART, "K. 626"),
    ("bach-aria-corda-sol", "J._S._Bach_-_Air_on_the_G_String_Piano_arrangement",
     "Ária na Corda Sol", BACH, "BWV 1068"),
    ("schubert-ave-maria", "Ave_Maria_D839_-_Schubert_-_Solo_Piano_Arrg.",
     "Ave Maria", SCHUBERT, "D. 839"),
    ("schubert-serenata", "Schubert_Serenade_-_Standchen_-_By_Lizst",
     "Serenata (Ständchen)", "Franz Schubert / Franz Liszt", "D. 957 / S. 560"),
    ("bach-minueto-sol-menor", "G_Minor_Bach_Original",
     "Minueto em Sol menor", BACH, "BWV Anh. 115"),
    ("chopin-noturno-9-2-facil", "Nocturne_in_E-flat_Major_Op._9_No._2_Easy",
     "Noturno em Mi bemol (fácil)", CHOPIN, "Op. 9 nº 2"),
]  # fmt: skip


def main() -> int:
    args = sys.argv[1:]
    if len(args) > 1 or any(a.startswith("-") for a in args):
        print(__doc__, file=sys.stderr)
        return 2
    src = Path(args[0]) if args else DEFAULT_SRC

    paths = {pid: src / "xml" / f"{stem}.musicxml" for pid, stem, *_ in PIECES}
    missing = [str(p) for p in paths.values() if not p.exists()]
    if missing:
        print("ERRO: faltam arquivos:", *missing, sep="\n  ", file=sys.stderr)
        return 1

    pieces = []
    for pid, _, title, composer, catalog in PIECES:
        fifths = read_fifths(paths[pid])
        pieces.append(
            {
                "id": pid,
                "musicxml": paths[pid],
                "t": title,
                "c": composer,
                **({"o": catalog} if catalog else {}),
                **({"a": fifths} if fifths is not None else {}),
            }
        )

    manifest = {
        "id": "classicos",
        "nome": "Clássicos para piano",
        "versao": datetime.date.today().strftime("%Y.%m.%d"),
        "termo": {"singular": "peça", "plural": "peças", "genero": "f"},
        "numerada": False,
        "creditos": "Transcrições da comunidade MuseScore, reunidas em "
        "github.com/musetrainer/library. Composições em domínio público; "
        "as edições são de terceiros — uso privado. Compositores: "
        + ", ".join(sorted({p[3] for p in PIECES})) + ".",
        "idioma": "pt-BR",
    }
    stats = build_package(manifest, pieces, PACKAGE)
    print(f"Gerado {PACKAGE}: {stats['pecas']} peças, {stats['bytes'] / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
