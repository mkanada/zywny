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

(vazio)
