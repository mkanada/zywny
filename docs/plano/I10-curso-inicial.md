# I10 — O curso inicial completo, embutido no app

**Repo:** zywny · **Depende de:** I05, I07, I08 (e I09) · **Decisão
necessária:** não (D-LIC-INICIAL: no app); **pergunta ao usuário** no
item 5 (o link do vídeo)

## Objetivo

As **10 lições** do currículo do I00 escritas no formato v1, com a mídia, em
`assets/cursos/iniciacao/`, lidas pelo mesmo leitor de um curso de
terceiros e abertas pelo cartão "Comece pelo curso inicial" (I09). É o
primeiro curso de verdade e o exemplo vivo da especificação.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "O curso inicial como teste da
  plataforma" (as cinco regras) e "Currículo do curso inicial" (a tabela é
  o roteiro deste passo).
- `docs/licoes/formato-v1.md` (I01) — escreva **só** com o que está lá; o
  que faltar volta para a especificação e o validador (regra 1).
- `lib/course/format/course_files.dart` (I01).
- `tool/build_mockup_images.sh` (como o projeto já gera PNG de partitura
  pela CLI do Verovio + Chrome headless).

## Contexto que você precisa

- **Regra 1 do I00**: nenhum `if` pelo id `iniciacao` no código. O curso
  embutido difere de um instalado só na origem (`AssetCourseFiles`) e em
  não poder ser removido.
- **Regra 2**: o teste de cobertura do I11 exige que **toda chave** do
  vocabulário apareça no curso. A coluna "Exercita da plataforma" do I00
  distribui isso; ao terminar, confira contra `vocabulary.dart` e encaixe
  o que sobrar numa lição onde faça sentido didático (nunca uma chave
  enfiada só para cobrir).
- Público: adulto que nunca leu partitura, sozinho com um teclado e o
  celular. Texto curto por tela (parágrafos de 2–4 linhas), uma ideia por
  seção, sempre "veja → ouça → toque". Tom do app: você, frases simples, sem
  jargão antes de explicá-lo. Nomes Dó-Ré-Mi no texto (o arquivo usa C4 nas
  chaves).
- Assets do Flutter não listam diretórios: o `AssetCourseFiles` usa o
  `AssetManifest` (`AssetManifest.loadFromAssetBundle`) e filtra pelo
  prefixo `assets/cursos/iniciacao/`. Cada subpasta entra no `pubspec.yaml`
  (`assets/cursos/iniciacao/`, `…/lessons/`, `…/media/`).
- Tamanho: o curso inteiro deve ficar **abaixo de ~1 MB** (o app encolheu
  ~3 MB tirando os hinos no B08; não devolva isso aqui). Áudio curto em
  `.ogg` mono (ou `.mp3`, conforme o I05 decidiu), imagens em `.webp`/`.png`
  otimizadas.

## O que fazer

1. **`lib/course/format/asset_course_files.dart`** e o carregamento do
   curso embutido na `CoursesScreen`/cartão (troca a fixture provisória do
   I09).
2. **As 10 lições** em `assets/cursos/iniciacao/lessons/NN-<id>.md` e o
   `course.md`, seguindo a tabela do I00 (explicação, exercícios, recursos).
   Para cada lição: título, 3–6 seções curtas, ao menos uma marca de
   conteúdo antes de cada exercício, e exercícios do mais fácil ao mais
   difícil. Metas: as lições 1–2 com `accuracy` 80 (primeiro contato), as
   demais 90; `rounds: 2` ou `3` onde a fixação importa (lições 3 e 4).
   `requires` em cadeia, e a lição 5 requer as lições 3 **e** 4.
3. **A partitura da lição 10** (`media/*.musicxml`): uma peça curta (8–16
   compassos) **de domínio público**, em Dó maior, duas pautas, mão direita
   melódica e esquerda com notas longas — por exemplo, um arranjo próprio
   da "Ode à Alegria". Escreva o arranjo (é obra nova sua sobre melodia de
   domínio público; registre no `course.md` o crédito) e confira o
   `midi.json` com a CLI do fork.
4. **Mídia** — uma receita reprodutível `tool/build_course_media.sh`:
   - imagens de partitura (clave de sol, clave de fá, pauta dupla,
     armaduras): Verovio CLI → SVG → PNG/WebP, como o
     `build_mockup_images.sh`;
   - áudios curtos (o Sol da 2ª linha, dó-ré-mi, um compasso contado):
     sintetizados com o **soundfont do app** (D-SF) por ferramenta offline —
     `fluidsynth -F` se estiver instalado, ou um exemplo novo no crate
     (`native/zywny_audio/examples/render_wav.rs`, que reaproveite o
     `render` de `examples/play.rs`) — e convertidos com `ffmpeg`/`oggenc`;
   - registre as versões das ferramentas nas notas; os arquivos gerados
     **são versionados** (o curso embutido não depende de rodar a receita).
5. **Vídeo da lição 7** (contar o tempo em voz alta): proponha ao usuário
   **2–3 links** de vídeos públicos em português (YouTube), com título,
   canal e duração, e **pergunte qual usar** — é um link para fora com o
   nome do app ao lado. Até a resposta, a lição fica com um link
   provisório marcado `TODO` e o critério 4 aberto.
6. Valide a cada lição (`just curso-validar assets/cursos/iniciacao`) e
   abra no app (Linux) para ler como aluno.
7. Atualize a especificação com o que a escrita revelou (regra 1) e anote
   nas notas de execução cada mudança no formato que este passo pediu.

## Fora de escopo

Os testes automáticos de cobertura/aluno simulado/cursos quebrados (I11 —
mas rode o que já existe do I03/I07/I08 sobre o curso); pacote (I04).

## Critérios de aceite

1. `just curso-validar assets/cursos/iniciacao` sem erro nem aviso.
2. Todos os exercícios do curso passam nos testes de aluno simulado que já
   existem (I03, I07, I08) — "tudo certo aprova".
3. O curso inteiro ocupa menos de ~1 MB (medir; registrar o tamanho do APK
   arm64 antes/depois).
4. **(manual, usuário)** o usuário lê as 10 lições no app (celular) e
   aprova o texto ou devolve correções; o link do vídeo escolhido por ele.
5. **(manual)** fazer o curso inteiro no celular com o teclado MIDI, da
   lição 1 à 10, anotando onde travou.
6. `just analyze` e `just test` limpos.

## Notas de execução

Concluído em 2026-10-06 (código + conteúdo; manual no aparelho pendente,
critérios 4–5). `just curso-validar assets/cursos/iniciacao` sem erro nem
aviso (exit 0); `just analyze` limpo; `just test` limpo (571 passando, 4
pulados/manuais, com a `libverovio.so` real).

**O que existe**

- `lib/course/asset_course_files.dart` — `AssetCourseFiles(prefix)` via
  `AssetManifest.loadFromAssetBundle` filtrado por
  `assets/cursos/iniciacao/` (fora de `lib/course/format/`, que continua
  Dart puro sem Flutter — o teste `course_validator_test` exige; o primeiro
  rascunho quebrou esse teste e foi movido).
- `lib/course/built_in_course.dart` — `loadBuiltInCourses()` (regra 1 do
  I00: sem `if` pelo id; origem `CourseOrigin.builtIn`), ligado no
  `LibraryScreen` pelo `main.dart` (troca o `loadCourses` vazio do I09).
- `pubspec.yaml`: `assets/cursos/iniciacao/`, `…/lessons/`, `…/media/`.
- As 10 lições em `assets/cursos/iniciacao/lessons/NN-<id>.md` + `course.md`,
  seguindo a tabela do I00 (explicação, exercícios, recursos). Metas:
  lições 1–2 `accuracy: 80`, demais 90 (ritmo/play-score com tempo real
  usam 85, por serem mais difíceis); `rounds: 2` (lições 3, 8) e `3`
  (lição 4); `requires` em cadeia, lição 5 requer 3 **e** 4. 28 exercícios,
  ids únicos no curso, 3–6 seções curtas por lição, uma marca de conteúdo
  antes de cada exercício, texto curto (2–4 linhas, uma ideia por seção,
  "veja → ouça → toque", Dó-Ré-Mi no texto, `C4` no arquivo).
- Cobertura total do vocabulário (prévia do I11, conferida por script
  temporário já removido): todas as marcas/chaves, todos os tipos/chaves,
  `accuracy`/`rounds`/`speed`/`time-limit`, `random`/`count`/`only`,
  `clef` treble/bass/grand, `mode` wait/realtime, `octave` any/exact,
  `hand` right/left/both, `accidentals` none/sharps/flats/mixed, as 10
  figuras, `time` 4/4–3/4–2/4–6/8–C, `key` G–F–D–Bb, imagem e link markdown.
  Faltava só `name-note:key`: entrou como `l9-nomes-em-sol` (`key: G`).
- Partitura da lição 10 (`media/ode-a-alegria.musicxml`): 8 compassos em Dó
  maior, duas pautas, direita melódica e esquerda em semibreves — arranjo
  próprio da "Ode à Alegria" (Beethoven, 1824, domínio público; crédito no
  `course.md`). Abre no Verovio CLI OK; `measures: "1-8"` existe.
- Mídia (`tool/build_course_media.sh`, versionada junto): imagens Verovio
  6.3.0 CLI → SVG → PNG (Chrome headless em `$HOME` + `convert`
  6.9.12-98 trim+borda, como o `build_mockup_images.sh`); áudios com o
  soundfont do app (TimGM6mb) via exemplo novo
  `native/zywny_audio/examples/render_wav.rs` (reaproveita o `render` do
  `play.rs`, WAV mono 16 bits escrito à mão, sem `hound`) + `ffmpeg`
  6.1.1 para `.ogg` mono (`fluidsynth`/`oggenc`/`optipng` ausentes —
  registrado no script). Curso total 160 KB (mídia 108 KB), abaixo de ~1 MB.
  APK arm64: 46 MB (build 2026-09-29, antes do I10); delta estimado +~100 KB
  comprimido — rebuild exato fica para o I13, junto com o aceite no aparelho.
- Vídeo da lição 7 (item 5): usuário escolheu "Figuras musicais: semínima,
  mínima, colcheia e semicolcheia" (`https://www.youtube.com/watch?v=qjmJQov61rg`);
  as outras duas opções apresentadas foram "Semínima, colcheia e
  semicolcheia (exemplos simples)" (`m5eBKvWK1wk`) e "Como Ler Partituras
  com rapidez" (`-h_99IxtJKo`). Canal/duração não verificados
  automaticamente (YouTube exige JS) — confirmar no aparelho.

**Formato (regra 1, item 7)**: a escrita não pediu nenhuma chave nova. Nada
mudou na especificação (`docs/licoes/formato-v1.md`) nem no validador; o
curso usa só o que está lá. Único aprendizado anotado: `lib/course/format`
não pode importar Flutter (o validador roda com `dart run`) — o
`AssetCourseFiles` nasceu lá e foi movido para `lib/course/`.

**Revisão do conteúdo (2026-10-08)**, a pedido do usuário ("coisas fora
do lugar, passos desnecessários, outros faltando"). A tabela do I00 já
mostra o currículo novo. O que mudou:

- Fora do lugar: o tom de Sol e o compasso saíram da lição 2 (a armadura
  é da lição 9; o compasso, da 6); o C no lugar do 4/4 foi da lição 9 para
  a 6; o áudio dó-ré-mi saiu da mão esquerda da Ode; o link do MIDI saiu do
  dó central; o vídeo de figuras ficou como revisão no fim da lição 7.
  Cada figura agora mostra o que o texto da seção diz (antes, "Notas em
  espaços" ilustrava as linhas suplementares, e a clave de fá mostrava um
  teclado).
- Faltavam: oitava e o número da oitava (Dó4) antes da primeira pauta; o
  dó central na linha suplementar já na lição 2, onde aparece; os números
  dos dedos e a posição de Dó (direita na 2, esquerda na 4); pulso, barra e
  fórmula de compasso antes das figuras; tom e meio tom antes do
  sustenido; a ligadura (estava no I00 e não no curso); uma melodia cedo
  ("Brilha, brilha", lição 3, modo espera).
- Desnecessários ou trocados: o `find-key` de oitava exata da lição 4 foi
  para a lição 1 (é geografia do teclado); a "peça em Ré" virou exercícios
  de Sol e Fá maior (Ré e Si♭ só para reconhecer); "quantos sustenidos tem
  Sol maior" virou "que tom é este"; o exercício "O Dó nas duas mãos"
  (`[C3, C4, E4, G3]`) virou Dó-Mi-Sol subindo e descendo nas duas mãos.
- Ode (pedido do aceite de 06/10): primeiro só as notas (modo espera),
  depois no ritmo; as duas mãos também passam antes pelo modo espera. Todos
  os de tempo real com `bpm: 80` (antes a esquerda e as duas mãos ficavam
  nos 120 do arquivo).
- Erros corrigidos: ABC `F#`/`Bb` (no ABC são `^F`/`_B`, e `Bb` vira duas
  notas); `G, A, B, C` na clave de fá mostrava G3–C4 com destaque num F3
  que não estava lá; compasso de 8 tempos em 4/4; colcheias sem barra
  (`C/2 C/2` com espaço não liga); `G ^G G` dizia "Sol de novo" (a
  partitura de verdade leria Sol sustenido); o Fá maior sorteava C4–G4 e
  nunca passava pelo Si♭; o `rhythm` com `abc` pedia Dó, Ré, Mi e Fá ("uma tecla
  só") e ignorava o `bpm` (código consertado em `RhythmKind`); as figuras
  saíam com fundo ciano (o Chrome lê `--default-background-color` como
  RRGGBBAA).
- Achado do formato (regra 1): no ABC o acidente não vale até a barra no
  som — `^F F` toca Fá sustenido e Fá natural, sem bequadro na pauta. A
  especificação dizia o contrário; corrigida. O exemplo da lição 8 é um
  `.musicxml` (`media/vale-ate-a-barra.musicxml`).
- Mídia: saíram `clave-de-sol.png`, `clave-de-fa.png`, `armadura-sol.png`,
  `sol.ogg` e `do-re-mi.ogg` (repetiam uma partitura que já toca);
  entraram `dos.ogg` (Dós do grave ao agudo) e o `.musicxml` da lição 8;
  `compasso.ogg` marca o primeiro tempo. 31 exercícios (eram 28); ids
  mantidos onde o exercício é o mesmo.

**Pendente (manual)**: critério 4 (ler as 10 lições no celular e aprovar o
texto), critério 5 (fazer o curso 1–10 com teclado MIDI anotando travas),
rebuild do APK + medida antes/depois exata (I13).
