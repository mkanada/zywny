# B11 — Abrir `.zywny` pelo sistema (associação de arquivos)

**Repo:** zywny · **Depende de:** B05, I04 (o fluxo de instalar) ·
**Decisão necessária:** nenhuma

## Objetivo

O app se registra como o programa que abre arquivos `.zywny`: toque no arquivo
no gerenciador de arquivos (ou num download) e o Zywny abre e instala o
pacote, como se ele tivesse saído do "Abrir arquivo…". Pedido em 2026-10-08.

## Como funciona

| Peça | Onde |
| --- | --- |
| A fila entre o sistema e a tela, os argumentos de `main` e o canal `zywny/incoming` | `lib/incoming/incoming_packages.dart` |
| Instalar o que chegou (lê, depois o mesmo despacho de biblioteca/curso) | `installIncomingPackage` em `lib/course/course_installer.dart` |
| A tela da biblioteca instala um por vez e volta a ela | `_drainIncoming` em `lib/app/library_screen.dart` |
| Android: filtros de intent, cópia para o cache, canal | `AndroidManifest.xml`, `MainActivity.kt` |
| Linux: um só processo em release, encaminha o arquivo | `linux/runner/my_application.cc` |

- **Protocolo do canal** (`zywny/incoming`): o Dart chama `initial` e recebe os
  arquivos que chegaram antes dele estar pronto; depois o nativo chama `file`.
  Cada arquivo é `{name, path}` (+ `temporary: true` se é cópia do cache, que o
  Dart apaga depois de ler — nunca o arquivo do usuário) ou `{name, error}`.
- **Instalar.** Um arquivo por vez; o instalador é o mesmo do "Abrir arquivo…"
  (pergunta antes de substituir, explica erro). Se instalou, a tela volta à
  biblioteca (fecha partitura, cursos ou configurações que estiverem por cima).
- **Passeio de primeiro uso.** Cede a vez ao arquivo recebido e começa quando a
  fila esvazia (o Android só avisa depois de copiar o arquivo, então o aviso
  pode chegar depois de o passeio já ter decidido começar).
- **A abertura (splash)** vale também: o primeiro arquivo espera 2,4 s.

### Android

- Dois filtros `VIEW`: um pelo nome (`.*\.zywny`, com até 3 pontos extras no
  nome) em `content`/`file`, e um pelo tipo `application/octet-stream` /
  `application/x-zywny` em `content`, para quando o provedor esconde o nome
  (Downloads, Drive). O Android não conhece a extensão; o preço do segundo
  filtro é o Zywny aparecer em "Abrir com…" para qualquer arquivo genérico — o
  app valida o conteúdo e explica se não for um pacote.
- **`launchMode="singleTask"`** (era `singleTop`). Com `singleTop`, abrir pelo
  app Arquivos criava um segundo `MainActivity` na tarefa dele, com o app antigo
  vivo em segundo plano (dois motores, dois áudios). Medido com `dumpsys` no
  emulador: com `singleTask` há uma instância só.
- O conteúdo é copiado para `cache/incoming/` numa thread à parte e o Dart lê o
  caminho (o pacote dos hinos tem 3 MB). `file://` sem permissão dá o erro "o
  Android não deixou o app ler o arquivo".
- Intent reentregue (atividade recriada, reaberto pelos recentes) não instala de
  novo.

### Linux (parcial)

- `my_application.cc`: em release o app é **único** (`GApplication` com
  `HANDLES_OPEN`): abrir um `.zywny` com o app aberto leva o arquivo à janela
  que existe e o segundo processo sai. Em debug fica `NON_UNIQUE` (um
  `flutter run` não pode sair passando o arquivo a um release aberto).
  Testado: bundle de release sob Xvfb com D-Bus próprio; o segundo processo saiu
  com 0 e a biblioteca foi instalada na primeira janela.
- **Não terminado:** `linux/packaging/` (`.desktop` e tipo MIME) e
  `tool/install_linux.sh` foram escritos e **não testados**; falta a receita
  `just instalar-linux` e conferir o clique duplo num gerenciador de arquivos.
  O Linux foi deixado de lado a pedido do usuário.
- Ambiente: o `flutter build linux` quebra aqui porque o `libunwind.pc` sumiu
  (`libunwind-18-dev` no lugar de `libunwind-dev`) e o plugin de áudio exige o
  `gstreamer-1.0`. Os testes usaram um `libunwind.pc` de mentira só no
  `PKG_CONFIG_PATH`.

### Windows e Web

- Windows (fase X02): o runner já repassa a linha de comando a `main(args)`, que
  entende `.zywny`; falta o registro no instalador e o encaminhamento ao app
  aberto.
- Web: não feito. Seria `file_handlers` no `manifest.json` do PWA e
  `launchQueue` (só Chromium instalado).

## Testes

- `test/incoming_packages_test.dart` — extensão, argumentos, `file://`, a fila e
  o canal (cópia temporária apagada, arquivo do usuário não).
- `test/incoming_install_test.dart` — instalar na abertura a frio e com o app
  aberto, substituir, dois seguidos, erro de leitura e de pacote, voltar à
  biblioteca, e a vez do passeio (inclusive o aviso que chega durante a espera).
- No emulador (Android 10): abertura a frio e com o app já aberto, pelo
  seletor "Abrir com" e pelo app Arquivos; erro de `file://`; uma só instância.

## Pendente (manual)

1. No celular de verdade: tocar num `.zywny` no gerenciador de arquivos e num
   download no Chrome/WhatsApp/Drive (cada provedor entrega o URI de um jeito).
2. Linux: terminar e testar o registro (acima).
