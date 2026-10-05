# I12 — Autoria: `validate --render` e o modo rascunho (desktop e Web)

**Repo:** zywny · **Depende de:** I05, I09 (e I07/I08 para rodar todos os
tipos no rascunho) · **Decisão necessária:** não (D-LIC-AUTORIA: validador
na linha de comando + rascunho no desktop **e na Web**; no Android, não)

## Objetivo

O professor escreve a pasta num editor e vê o resultado **no app**, sem
pacote e sem assinatura: "Abrir pasta de curso…" carrega a pasta como
**rascunho** — faixa "Rascunho · não verificado", botão **Recarregar**,
nada instalado, progresso só na memória. Os erros do validador aparecem
na tela, com arquivo e linha. O comando de linha ganha `--render`, que
confere que toda partitura do curso renderiza.

O rascunho é a única porta para conteúdo sem assinatura, e ela não guarda
nada: fechar o app (ou a aba) apaga o curso. É o compromisso entre
D-LIC-CONFIANCA ("só o que eu assino" se instala) e D-LIC-AUTORIA.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "Decisões" (CONFIANCA, AUTORIA) e
  "O curso inicial como teste", regra 5.
- `lib/course/format/course_files.dart`, `directory_course_files.dart`,
  `course_reader.dart` e `tool/zywny_course.dart` (I01).
- `lib/course/course_progress.dart` (`MemoryCourseProgressStore`, I09) e o
  `LoadedCourse.origin` (I09).
- `lib/library/library_installer.dart` `pickLibraryBytes` L15 (o
  `file_selector` já usado).
- `lib/midi/web_midi_access_web.dart` (o padrão de `js_interop` do
  projeto na Web).

## Contexto que você precisa

- `file_selector` tem `getDirectoryPath()` no Linux e no Windows; **não**
  na Web.
- Na Web, a pasta vem pela **File System Access API**
  (`window.showDirectoryPicker()`, Chrome/Edge; `js_interop` + `package:web`).
  O handle fica guardado na sessão: Recarregar relê os arquivos sem pedir a
  pasta de novo. Firefox e Safari não têm: lá o rascunho aceita um
  **`.zip` da pasta, sem envelope** (Recarregar pede o arquivo de novo).
  Esse `.zip` só é aceito pelo rascunho; o instalador continua recusando
  pacote sem assinatura (I04, critério 1 — não pode regredir).
- `score_bridge` (e portanto `lib/verovio_render.dart`) importa Flutter,
  então o `dart run tool/zywny_course.dart` **não** pode usá-los. O
  `--render` usa direto os bindings `package:verovio` (FFI) — confira que
  eles não puxam Flutter; se puxarem, o `--render` vira um
  `flutter test`-script (`just curso-validar --render` chamando um teste
  com a pasta por `--dart-define`) e anote.
- No Android não há o item (D-LIC-AUTORIA). No celular, o professor vê o
  resultado pelo desktop ou pela Web no próprio celular (Chrome Android tem
  `showDirectoryPicker`? confira; se não, o `.zip`).

## O que fazer

1. **`validate --render`** — para cada `zywny-score`, `choice` com `abc` e
   exercício com `abc`/`file`, carrega no Verovio (com o cabeçalho do I02
   quando for corpo de ABC) e confere: carregou, tem ao menos uma nota, o
   MIDI não está vazio, e `measures` cabe na partitura. Erro na linha da
   marca: "A partitura não renderiza (o Verovio disse: …)". Sem a
   `libverovio.so`: aviso único "--render indisponível" e código 0. A
   fixture "ABC que não renderiza" do I11 passa a valer.
2. **Abrir pasta** — configurações gerais, seção "Cursos" (I04): "Abrir
   pasta de curso (rascunho)…" em Linux, Windows e Web; ausente no Android.
   Também pela linha de comando no desktop: `just curso PASTA` roda o app
   abrindo direto o rascunho (argumento `--curso <pasta>` em `main`, como o
   `--debug` — ver `run-debug` no `justfile`).
3. **Leitura** — `readCourse` sobre a `DirectoryCourseFiles` (desktop), a
   `WebDirectoryCourseFiles` (handle da Web, arquivo novo
   `lib/course/format/web_directory_course_files.dart` com import
   condicional) ou a `ZipCourseFiles` (`.zip` sem envelope).
4. **Com erros** — `CourseIssuesScreen`: a lista do validador, agrupada por
   arquivo, linha e mensagem, erros primeiro; Recarregar no topo. Só
   avisos: o curso abre e uma tira recolhível mostra "3 avisos".
5. **Rascunho aberto** — as telas do I09 com `origin: draft`:
   - faixa fixa no topo, cor de alerta do tema: "Rascunho · não
     verificado · <pasta>" + **Recarregar**;
   - progresso no `MemoryCourseProgressStore` (Recarregar **mantém** o
     progresso da sessão, para o professor não refazer exercícios a cada
     ajuste de texto);
   - Recarregar mantém a tela atual (curso → mesma lição → mesma posição de
     rolagem, se a lição ainda existir; senão, a lista);
   - na lista de cursos o rascunho aparece primeiro, com o rótulo
     "rascunho", e some ao fechar o app.
6. **Atalho do autor no desktop**: `Ctrl+R` = Recarregar.
7. **Especificação**: seção "Como ver sua lição" em
   `docs/licoes/formato-v1.md` (desktop, Web com Chrome, `.zip` nos outros
   navegadores, `validate` e `--render`), e "Como publicar" (mandar a pasta
   ao usuário, que roda `just pacote-curso`).

## Fora de escopo

Recarregar sozinho ao salvar (observar a pasta); editor no app; rascunho no
Android; assinar no app.

## Critérios de aceite

1. `test/course_draft_test.dart`: rascunho de uma `MemoryCourseFiles`
   abre com a faixa; com erro, mostra a lista com arquivo e linha;
   Recarregar depois de corrigir abre o curso e mantém progresso e lição;
   nada aparece em `shared_preferences` nem no blob store.
2. O instalador **continua** recusando `.zip` sem envelope (teste do I04
   rodando).
3. `just curso-validar --render assets/cursos/iniciacao` passa; a fixture
   de ABC quebrado dá a mensagem esperada.
4. **(manual)** Linux: `just curso test/fixtures/cursos/minimo`, editar uma
   lição no editor, Recarregar, ver a mudança no lugar. Web (Chrome):
   abrir a pasta, editar, Recarregar sem pedir a pasta. Firefox: `.zip`.
5. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
