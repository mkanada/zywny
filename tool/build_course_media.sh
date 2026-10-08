#!/usr/bin/env bash
# I10 — receita reprodutível da mídia do curso inicial embutido.
#
# Gera os arquivos versionados em `assets/cursos/iniciacao/media/`:
# - imagens de partitura (a pauta dupla da lição 5 e a armadura de Fá da
#   pergunta da lição 9): Verovio CLI → SVG → PNG (Chrome headless +
#   ImageMagick), como o `tool/build_mockup_images.sh`;
# - áudios curtos (cinco Dós do grave ao agudo, dois compassos contados):
#   sintetizados com o soundfont do app (D-SF, `assets/soundfonts/TimGM6mb.sf2`)
#   pelo exemplo `render_wav` do crate (`native/zywny_audio/examples/render_wav.rs`,
#   que reaproveita o `render` de `examples/play.rs`) e convertidos com `ffmpeg`;
# - as partituras `.musicxml` são escritas à mão e só conferidas aqui: a
#   da lição 10 (`ode-a-alegria.musicxml`, arranjo próprio sobre melodia de
#   domínio público) e a da lição 8 (`vale-ate-a-barra.musicxml`: o ABC não
#   estende o acidente até a barra no som).
#
# Os arquivos gerados SÃO versionados: o curso embutido não depende de rodar
# esta receita. Rode-a quando quiser refazer a mídia (ela sobrescreve).
#
# Ferramentas medidas em 2026-10-06 (Pop!_OS):
# - verovio 6.3.0-a4637ea (fork no verovio_flutter_bridge)
# - google-chrome (headless para rasterizar o SVG)
# - ImageMagick 6.9.12-98 (convert: trim + borda)
# - cargo 1.95.0 + rustysynth 1.3.6 (render_wav, sem fluidsynth — não instalado)
# - ffmpeg 6.1.1-3ubuntu5 (WAV → .ogg mono; `oggenc` não instalado)
set -euo pipefail

proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
media_dir="$proj_dir/assets/cursos/iniciacao/media"
source "$(dirname "${BASH_SOURCE[0]}")/verovio_bridge.sh"
bridge_dir="$verovio_bridge"
verovio_bin="$bridge_dir/verovio/tools/verovio"
data_dir="$bridge_dir/verovio/data"
chrome_bin="${CHROME_BIN:-$(command -v google-chrome || echo google-chrome)}"
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
    --window-size=1400,500 --default-background-color=ffffffff \
    --screenshot="$full" "file://$svg" >/dev/null 2>&1
  convert "$full" -trim +repage -bordercolor white -border 12 "$media_dir/$name.png"
  echo "imagem $name.png: $(du -h "$media_dir/$name.png" | cut -f1)"
}

# O fundo é branco opaco: o Chrome lê `--default-background-color` como
# RRGGBBAA (o `00ffffff` de antes saía ciano). Transparente não serve: no
# tema escuro as notas pretas sumiriam.
#
# Armadura de Fá (1 bemol), para a pergunta "Que tom é este?" da lição 9:
# o Si da melodia é bemol pela armadura, sem sinal (`B`, não `Bb`, que no
# ABC são duas notas).
render_abc_png "armadura-fa" "F G A B | c4|" "M:4/4
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
  --window-size=1400,600 --default-background-color=ffffffff \
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
# Lição 1: um Dó de cada região, do grave (Dó2) ao agudo (Dó6). Argumentos
# do render_wav: a primeira nota, a duração da ÚLTIMA (ms) e as demais;
# cada nota antes da última dura 450 ms + 50 ms de silêncio.
cargo run --quiet --release --example render_wav --manifest-path "$crate_dir/Cargo.toml" -- \
  "$soundfont" "$work/dos.wav" 36 900 48 60 72 84 >/dev/null
ffmpeg -y -loglevel error -i "$work/dos.wav" -ac 1 -c:a libvorbis -q:a 3 "$media_dir/dos.ogg"
echo "áudio dos.ogg: $(du -h "$media_dir/dos.ogg" | cut -f1)"

# Lição 6: dois compassos de quatro tempos a 120 bpm; o primeiro tempo de
# cada compasso é o Dó de cima (o render_wav não tem acento de volume).
cargo run --quiet --release --example render_wav --manifest-path "$crate_dir/Cargo.toml" -- \
  "$soundfont" "$work/compasso.wav" 72 450 60 60 60 72 60 60 60 >/dev/null
ffmpeg -y -loglevel error -i "$work/compasso.wav" -ac 1 -c:a libvorbis -q:a 3 "$media_dir/compasso.ogg"
echo "áudio compasso.ogg: $(du -h "$media_dir/compasso.ogg" | cut -f1)"

# --- partituras escritas à mão: só confere que o Verovio abre ---
echo
echo "== partituras .musicxml =="
for score in ode-a-alegria vale-ate-a-barra; do
  "$verovio_bin" -r "$data_dir" --header none --footer none \
    -o "$work/$score.svg" "$media_dir/$score.musicxml" >/dev/null
  echo "$score.musicxml abre no Verovio OK: $(du -h "$media_dir/$score.musicxml" | cut -f1)"
done

echo
echo "== total =="
du -sh "$media_dir"
du -cb "$media_dir"/* | tail -1
echo "Pronto em $media_dir"
