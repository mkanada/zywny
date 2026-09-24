# Windows a partir do Linux — o que dá e o que não dá (pesquisa, 2026-09-24)

Achados para a decisão **D-WIN** (ver README, "Decisões"). Nada aqui foi
aplicado ao zywny nem ao fork; os testes rodaram num container descartável.

## Resumo

- **DLLs nativas (Verovio, `zywny_audio`)**: compilam no Linux. A
  `verovio.dll` com mingw-w64 foi **testada**: compila, carrega e responde
  pela API C.
- **App Flutter para Windows**: **não** compila no Linux por nenhum caminho
  suportado. Precisa de Windows (máquina, VM ou CI).

## 1. `verovio.dll` com mingw-w64 (testado)

Ambiente: Docker `ubuntu:24.04` + `apt install mingw-w64 cmake ninja-build`,
cópia gravável do fork (o `tools/get_git_commit.sh` escreve em
`include/vrv/git_commit.h`, então montar o fonte só-leitura falha).

Toolchain do CMake:

```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc-posix)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++-posix)
```

Configuração (mesmas flags de `build_linux_so.sh` + `-static`):

```sh
cmake -G Ninja -S verovio/cmake -B build-win \
  -DBUILD_AS_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=mingw.cmake -DCMAKE_SHARED_LINKER_FLAGS="-static"
cmake --build build-win -j4
x86_64-w64-mingw32-strip --strip-unneeded -o verovio.dll build-win/libverovio.dll
```

Resultado:

- `verovio.dll` com 14,9 MB após `strip`; 62 exports `vrvToolkit_*` (o
  mingw exporta tudo por padrão, sem `__declspec(dllexport)`).
- Com `-static`, as dependências são só `KERNEL32.dll` e `msvcrt.dll` — nada
  de `libstdc++-6.dll`/`libgcc_s`/`libwinpthread-1.dll` ao lado do `.exe`.
  (Tentar só `-static-libgcc -static-libstdc++` ainda deixou a
  `libwinpthread-1.dll`.)
- Carga testada no Wine 9.0 com um `.exe` mínimo: `LoadLibrary` +
  `GetProcAddress` + `vrvToolkit_constructorResourcePath` +
  `vrvToolkit_getVersion` → `6.3.0`. **Não** testado: gerar um `.vsb` de
  verdade (o teste passou um caminho de dados falso, por isso os erros de
  fonte Bravura/Leipzig no log).
- Tempo: ~5-8 min de build completo em 4 núcleos.

O fork precisa de **dois ajustes** para o mingw (hoje o código do Windows
assume MSVC):

1. `include/win32/win_time.h`: `#include <Windows.h>` → `<windows.h>`. Os
   headers do mingw são minúsculos e o sistema de arquivos do Linux
   diferencia; o MSVC aceita os dois. (No teste foi contornado com um
   symlink `Windows.h → windows.h` no include do mingw.)
2. `src/vrv.cpp:21` e `include/vrv/vrv.h:19`: `#ifndef _WIN32` →
   `#if !defined(_WIN32) || defined(__MINGW32__)`. O shim de `gettimeofday`
   em `win_time.h` redefine `timeval` e conflita com o do mingw, que já tem
   `<sys/time.h>` e `<dirent.h>`.

**CRT**: a DLL do mingw usa `msvcrt`; o app Flutter (MSVC) usa o UCRT. Não há
problema enquanto memória não for alocada de um lado e liberada do outro. As
funções vistas em `verovio/bindings/dart/lib/src/verovio_toolkit.dart` estão
seguras: o Dart aloca as strings de entrada num `Arena` próprio e só lê as
que a DLL devolve, que continuam sendo da DLL. Conferir o mesmo na função do
`.vsb` ao implementar o X02.

## 2. Outras rotas para código nativo (não testadas)

- **clang-cl + lld-link + [`xwin`](https://github.com/Jake-Shadle/xwin)**:
  baixa os headers e as libs do MSVC e do Windows SDK (exige aceitar a
  licença da Microsoft) e gera binários com o ABI do MSVC e o UCRT, iguais
  aos de um build no Windows. Aqui: `clang` 18 já instalado; `lld-18` e
  `clang-tools-18` (clang-cl) estão no apt. Vale a pena se quiser a mesma CRT
  do app, ou para compilar o runner (seção 3).
- **Rust (`zywny_audio`, K06)**: `rustup target add x86_64-pc-windows-gnu`
  (linker do mingw) ou `cargo-xwin` para `x86_64-pc-windows-msvc`. O cpal usa
  WASAPI nos dois alvos.

## 3. O app Flutter

Bloqueios verificados no SDK 3.47.4:

- `packages/flutter_tools/lib/src/commands/build_windows.dart:64`:
  `"build windows" only supported on Windows hosts.`
- `windows/flutter/CMakeLists.txt` executa
  `flutter_tools/bin/tool_backend.bat`, e o runner é compilado pelo gerador
  do Visual Studio.
- Os artefatos da engine para Windows (engine `06a2e2a110…`) só existem como
  binários Windows. `windows-x64-release/windows-x64-flutter.zip` traz
  `flutter_windows.dll`, `flutter_windows.dll.lib` e `gen_snapshot.exe`;
  `windows-x64/artifacts.zip` traz `gen_snapshot.exe`, `flutter_tester.exe`,
  `impellerc.exe` e outros. O `dart compile` só cross-compila para alvos
  Linux.

**Rota não suportada (não testada)**: compilar o kernel Dart no Linux (o
`frontend_server` não depende da plataforma), gerar o `app.so` rodando o
`gen_snapshot.exe` no Wine, compilar o runner e o plugin
`file_selector_windows` com clang-cl + xwin contra o
`flutter_windows.dll.lib`, e montar o bundle à mão. É possível em tese, mas
quebraria a cada atualização do Flutter — **descartada**. Rodar o app
Flutter no Wine (ANGLE/D3D11) como teste rápido também é incerto.

## 4. Onde rodar o build do Flutter

### VM local

- `/dev/kvm` está acessível para o usuário; a máquina tem 4 núcleos e 23 GB
  de RAM. O disco está no limite: 113 GB livres em `/home` contra ~60 GB de
  Windows 11 + VS Build Tools + Flutter.
- Opções: libvirt/virt-manager, ou
  [`dockur/windows`](https://github.com/dockur/windows), que roda o Windows
  em QEMU/KVM de dentro do Docker (já instalado).
- É o único lugar para os testes manuais de X02/K06/M01: latência de áudio,
  troca de dispositivo, MIDI.

### CI (planos gratuitos, consultados em 2026-09-24)

| Serviço | Grátis com Windows | Observações |
|---|---|---|
| [GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions) | Repo público: runners padrão sem custo. Privado: 2.000 min/mês (conta Free) | Minuto Windows US$ 0,010 contra US$ 0,006 do Linux. `windows-latest` já traz VS + CMake; Flutter via `subosito/flutter-action` |
| [Azure Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/licensing/concurrent-jobs) | Privado: 1 job por vez, ≤ 60 min cada, 1.800 min/mês | Exige ligar a organização a uma assinatura Azure. Projetos públicos foram descontinuados (os existentes viram privados em 2027) |
| [GitLab.com](https://docs.gitlab.com/ci/pipelines/compute_minutes/) | 400 min/mês de compute no Free; runner Windows com fator 1 | Runners Windows em beta |
| [AppVeyor](https://www.appveyor.com/pricing/) | Só open source: ilimitado, 1 job por vez | Privado a partir de US$ 29/mês |
| [Codemagic](https://codemagic.io/pricing/) | Não: o gratuito é só macOS (500 min/mês) | Windows só nos planos pagos |

Pré-requisitos e dicas para qualquer CI:

- **Dependências por caminho local**: o `pubspec.yaml` aponta `verovio` e
  `score_bridge` para `/home/mauricio/rust_projects/...`, o que nenhum CI
  enxerga. Viram dependências `git:` ou um submódulo.
- **Economizar minutos de Windows**: cross-compilar a `verovio.dll` com
  mingw num job Linux e passá-la como artefato (ou guardá-la em cache pelo
  commit do fork). O job Windows fica só com o `flutter build windows
  --release`.
- O CI resolve o **build**, não o **teste manual** (som, MIDI).

## Recomendação (a confirmar na D-WIN)

Um híbrido das opções (a) e (b) do X02:

1. DLLs cross-compiladas no Linux com mingw (script
   `tool/build_verovio_windows.sh` + receita no `justfile`), depois dos dois
   ajustes no fork.
2. Build e teste do app numa VM Windows 11 no KVM.
3. Opcional: GitHub Actions (Linux → DLL, Windows → bundle) quando as
   dependências deixarem de ser caminhos locais.
