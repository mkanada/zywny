#!/usr/bin/env bash
# I10 — receita reprodutível da mídia do curso inicial embutido.
#
# Gera os arquivos versionados em `assets/cursos/iniciacao/media/`:
# - imagens de partitura (clave de sol, clave de fá, pauta dupla,
#   armaduras): Verovio CLI → SVG → PNG (Chrome headless + ImageMagick),
#   como o `tool/build_mockup_images.sh`;
# - áudios curtos (o Sol da 2ª linha, dó-ré-mi, um compasso contado):
#   sintetizados com o soundfont do app (D-SF, `assets/soundfonts/TimGM6mb.sf2`)
#   pelo exemplo `render_wav` do crate (`native/zywny_audio/examples/render_wav.rs`,
#   que reaproveita o `render` de `examples/play.rs`) e convertidos com `ffmpeg`;
# - a partitura da lição 10 (`ode-a-alegria.musicxml`) é escrita à mão
#   (arranjo próprio sobre melodia de domínio público) e só é conferida aqui.
#
# Os arquivos gerados SÃO versionados: o curso embutido não depende de rodar
# esta receita. Rode-a quando quiser refazer a mídia (ela sobrescreve).
#
# Ferramentas medidas em 2026-10-06 (Pop!_OS):
# - verovio 6.3.0-a4637ea (fork em /home/mauricio/rust_projects/verovio_flutter_bridge)
# - google-chrome (headless para rasterizar o SVG)
# - ImageMagick 6.9.12-98 (convert: trim + borda)
# - cargo 1.95.0 + rustysynth 1.3.6 (render_wav, sem fluidsynth — não instalado)
# - ffmpeg 6.1.1-3ubuntu5 (WAV → .ogg mono; `oggenc` não instalado)
set -euo pipefail

proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
media_dir="$proj_dir/assets/cursos/iniciacao/media"
bridge_dir="/home/mauricio/rust_projects/verovio_flutter_bridge"
verovio_bin="$bridge_dir/verovio/tools/verovio"
data_dir="$bridge_dir/verovio/data"
chrome_bin="${CHROME_BIN:-/home/mauricio/bin/google-chrome}"
soundfont="$proj_dir/assets/soundfonts/TimGM6mb.sf2"
crate_dir="$proj_dir/native/zywny_audio"

echo "== versões =="
"$verovio_bin" --version 2>&1 | head -1 || echo "verovio: ausente"
"$chrome_bin" --version 2>&1 | head -1 || echo "chrome: ausente"
convert --version 2>&1 | head -1 || echo "convert: ausente"
cargo --version 2>&1 | head -1 || echo "cargo: ausente"
ffmpeg -version 2>&1 | head -1 || echo "ffmpeg: ausente"
echo

[[ -x "$verovio_bin" ]] || { echo "ERROR: $verovio_bin não existe — compile o fork" >&2; exit 1; }
[[ -x "$chrome_bin" ]] || { echo "ERROR: Chrome não encontrado em $chrome_bin (defina CHROME_BIN)" >&2; exit 1; }
[[ -f "$soundfont" ]] || { echo "ERROR: soundfont não encontrado em $soundfont" >&2; exit 1; }

mkdir -p "$media_dir"
# O Chrome headless (snap) só lê/escreve dentro de $HOME: o trabalho fica em
# $HOME para evitar ERR_FILE_NOT_FOUND silencioso (como no build_mockup_images.sh).
work="$(mktemp -d -p "$HOME" curso-media-XXXXXX)"
trap 'rm -rf "$work"' EXIT

# --- imagens: ABC → SVG (verovio) → PNG (chrome) → trim (convert) ---
render_abc_png() {
  local name="$1" abc_body="$2" extra_header="$3"
  local abc="$work/$name.abc" svg="$work/$name.svg" full="$work/${name}_full.png"
  {
    echo "X:1"
    echo "T:$name"
    echo "L:1/4"
    if [[ -n "$extra_header" ]]; then echo "$extra_header"; fi
    echo "$abc_body"
  } > "$abc"
  "$verovio_bin" -r "$data_dir" -s 100 --page-width 1400 --page-height 500 \
    --header none --footer none --no-instrument-labels --breaks auto \
    -p 1 -o "$svg" "$abc" >/dev/null
  "$chrome_bin" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size=1400,500 --default-background-color=00ffffff \
    --screenshot="$full" "file://$svg" >/dev/null 2>&1
  convert "$full" -trim +repage -bordercolor white -border 12 "$media_dir/$name.png"
  echo "imagem $name.png: $(du -h "$media_dir/$name.png" | cut -f1)"
}

# Clave de sol: cinco notas subindo até o Sol da 2ª linha.
render_abc_png "clave-de-sol" "C D E F G|" "M:4/4
K:C clef=treble"
# Clave de fá: a região grave, com o Fá da 4ª linha.
render_abc_png "clave-de-fa" "G, A, B, C|" "M:4/4
K:C clef=bass"
# Armadura de Sol (1 sustenido) e de Fá (1 bemol).
render_abc_png "armadura-sol" "G A B c|" "M:4/4
K:G clef=treble"
render_abc_png "armadura-fa" "F G A Bb|" "M:4/4
K:F clef=treble"

# Pauta dupla: duas pautas só saem por MusicXML (o ABC não faz duas pautas,
# limite documentado na especificação). Um trecho mínimo em Dó maior.
cat > "$work/pauta-dupla.musicxml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
<part-list><score-part id="P1"><part-name></part-name></score-part></part-list>
<part id="P1">
<measure number="1">
<attributes><divisions>2</divisions><key><fifths>0</fifths><mode>major</mode></key><time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves><clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>F</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<backup><duration>8</duration></backup>
<note><pitch><step>C</step><octave>3</octave></pitch><duration>8</duration><voice>2</voice><type>whole</type><staff>2</staff></note>
</measure>
</part>
</score-partwise>
XML
"$verovio_bin" -r "$data_dir" -s 100 --page-width 1400 --page-height 600 \
  --header none --footer none --no-instrument-labels --breaks auto \
  -p 1 -o "$work/pauta-dupla.svg" "$work/pauta-dupla.musicxml" >/dev/null
"$chrome_bin" --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=1400,600 --default-background-color=00ffffff \
  --screenshot="$work/pauta-dupla_full.png" "file://$work/pauta-dupla.svg" >/dev/null 2>&1
convert "$work/pauta-dupla_full.png" -trim +repage -bordercolor white -border 12 "$media_dir/pauta-dupla.png"
echo "imagem pauta-dupla.png: $(du -h "$media_dir/pauta-dupla.png" | cut -f1)"

# Otimiza os PNGs (sem perda visível; o curso inteiro deve ficar < ~1 MB).
if command -v optipng >/dev/null 2>&1; then
  optipng -o2 -quiet "$media_dir"/*.png
  echo "(optipng aplicado)"
else
  echo "(optipng ausente — PNGs sem otimização extra)"
fi

# --- áudios: soundfont do app via render_wav → ffmpeg → .ogg mono ---
echo
echo "== áudios (soundfont TimGM6mb via render_wav) =="
cargo run --quiet --release --example render_wav --manifest-path "$crate_dir/Cargo.toml" -- \
  "$soundfont" "$work/sol.wav" 67 800 >/dev/null
ffmpeg -y -loglevel error -i "$work/sol.wav" -ac 1 -c:a libvorbis -q:a 3 "$media_dir/sol.ogg"
echo "áudio sol.ogg: $(du -h "$media_dir/sol.ogg" | cut -f1)"

cargo run --quiet --release --example render_wav --manifest-path "$crate_dir/Cargo.toml" -- \
  "$soundfont" "$work/doremi.wav" 60 450 62 64 >/dev/null
ffmpeg -y -loglevel error -i "$work/doremi.wav" -ac 1 -c:a libvorbis -q:a 3 "$media_dir/do-re-mi.ogg"
echo "áudio do-re-mi.ogg: $(du -h "$media_dir/do-re-mi.ogg" | cut -f1)"

cargo run --quiet --release --example render_wav --manifest-path "$crate_dir/Cargo.toml" -- \
  "$soundfont" "$work/compasso.wav" 60 450 60 60 60 >/dev/null
ffmpeg -y -loglevel error -i "$work/compasso.wav" -ac 1 -c:a libvorbis -q:a 3 "$media_dir/compasso.ogg"
echo "áudio compasso.ogg: $(du -h "$media_dir/compasso.ogg" | cut -f1)"

# --- partitura da lição 10: só confere que o Verovio abre ---
echo
echo "== partitura da lição 10 =="
"$verovio_bin" -r "$data_dir" --header none --footer none \
  -o "$work/ode.svg" "$media_dir/ode-a-alegria.musicxml" >/dev/null
echo "ode-a-alegria.musicxml abre no Verovio OK: $(du -h "$media_dir/ode-a-alegria.musicxml" | cut -f1)"

echo
echo "== total =="
du -sh "$media_dir"
du -cb "$media_dir"/* | tail -1
echo "Pronto em $media_dir"
