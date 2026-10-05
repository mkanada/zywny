# I04 — Pacote de curso: `.zywny` assinado, instalar, guardar e remover

**Repo:** zywny · **Depende de:** I01, I09 · **Decisão necessária:** não
(D-LIC-CONFIANCA decidida: **só cursos que o usuário assina**, com a chave
das bibliotecas)

## Objetivo

Um curso escrito por um professor chega ao aluno como um `.zywny` gerado e
assinado **pelo usuário** (`just pacote-curso <pasta>`), instalado pelo
mesmo "Abrir arquivo…" das bibliotecas. O app reconhece que o pacote é um
curso, valida, guarda, lista em "Cursos" e permite remover. Pacote sem
assinatura válida é recusado como hoje.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md): "A divisão de papéis" (quem
  publica) e "Decisões" (CONFIANCA).
- [B00](B00-bibliotecas-instalaveis.md) "O envelope: cifra e assinatura
  (D-BIB-CIFRA)".
- `lib/library/library_envelope.dart` (`LibraryEnvelope.open` L53,
  `libraryKeyFromEnvironment` L14).
- `lib/library/library_installer.dart` (`pickLibraryBytes` L15,
  `installLibraryFromFile` L30–L127, `_ReplaceDialog` L157).
- `lib/library/library_store.dart` (`LibraryStore` L75: lista em
  `shared_preferences`, blobs em `library_blob_store*.dart`).
- `lib/settings/libraries_section.dart` (a seção de bibliotecas nas
  configurações).
- `tool/build_library.py`, `tool/library_crypto.py` (como o pacote é selado).
- `lib/course/format/course_files.dart` (`ZipCourseFiles`, I01) e
  `course_progress.dart` (I09).

## Contexto que você precisa

- O envelope é o mesmo (`ZYWN`, AES-256-GCM + Ed25519, chave pública no
  build por `--dart-define=ZYWNY_LIBRARY_KEY`). **Não** crie outro par de
  chaves: D-LIC-CONFIANCA = "só o que eu assino", e quem assina bibliotecas
  é a mesma pessoa.
- O **zip de dentro** de um curso é a pasta do curso como está:
  `course.md` na raiz, `lessons/`, `media/`. É assim que o instalador sabe
  que é curso (biblioteca tem `manifest.json`; ter os dois é erro).
- Abrir o envelope do pacote de hinos (3,1 MB) leva ~460 ms no Linux (B01,
  notas). Um curso com áudio pode ser maior: meça e, se passar de ~1 s no
  celular, mostre o mesmo `_BusyDialog` das bibliotecas.
- O id `iniciacao` é do curso embutido (D-LIC-INICIAL): pacote com esse
  id é recusado ("Este curso já vem no app").

## O que fazer

1. **`tool/build_course.py <pasta> [-o dist/<id>.zywny]`** — roda antes
   `dart run tool/zywny_course.dart validate <pasta>` (para no erro), zipa
   a pasta (só `course.md`, `lessons/*.md` e `media/**`; ignora ocultos e
   lixo de editor, avisando), sela com `library_crypto.py` e imprime o
   tamanho. Receita `just pacote-curso PASTA`.
2. **Instalação genérica** — `installLibraryFromFile` vira
   `installPackageFromFile` (mantenha o nome antigo chamando o novo, se
   houver muitos usos): abre o envelope, olha a raiz do zip e despacha:
   biblioteca → fluxo de hoje; curso → `readCourse(ZipCourseFiles(bytes))`
   (I01). Curso com erro de validação: recusa mostrando as **três
   primeiras** mensagens com arquivo e linha (o pacote saiu errado; quem
   precisa ver é você, não o aluno).
3. **`lib/course/course_store.dart`** — `CourseStore` (`ChangeNotifier`):
   lista de instalados em `shared_preferences` (`course_installed`: id,
   título, autor, versão, data), bytes do **envelope** no mesmo blob store
   das bibliotecas com prefixo `course:` no id (reaproveite
   `library_blob_store*.dart`; Web = IndexedDB). Abrir = decifrar e
   `readCourse`. Vários cursos instalados ao mesmo tempo (diferente das
   bibliotecas, sem "em uso").
4. Mesmo id já instalado: o `_ReplaceDialog` ("Substituir a versão 1 por
   2?"); o progresso **fica** (é por id). Versão igual: "já instalado".
5. **Lista** — a `CoursesScreen` do I09 passa a mostrar o embutido e os
   instalados; o cartão "Instalar curso…" no fim da lista abre o seletor
   (aceita também bibliotecas: é o mesmo instalador).
6. **Remover** — configurações gerais, seção "Cursos" ao lado de
   "Bibliotecas" (`libraries_section.dart` como modelo): lista dos
   instalados com "Remover" (confirmação dizendo que o progresso fica
   guardado, para o caso de reinstalar). O embutido não aparece para
   remover.

## Fora de escopo

Rascunho e pasta sem assinatura (I12). Baixar por URL, loja (I00 "Fora de
escopo"). Atualização automática.

## Critérios de aceite

1. `test/course_install_test.dart` (como `library_install_test.dart`):
   curso válido instala e aparece na lista; envelope com outra chave
   recusado; zip sem envelope recusado; zip com `course.md` **e**
   `manifest.json` recusado; curso com erro de validação recusado com a
   mensagem; id `iniciacao` recusado; substituir mantém o progresso;
   remover some da lista e o progresso fica.
2. `just pacote-curso test/fixtures/cursos/minimo` gera o `.zywny`; uma
   pasta quebrada para no validador com código ≠ 0.
3. **(manual)** Linux, Web e celular: instalar o pacote do critério 2 pelo
   "Abrir arquivo…", abrir uma lição, remover. Tempo de abrir o envelope no
   celular, nas notas.
4. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
