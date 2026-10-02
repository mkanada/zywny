# Telas no celular

Fotos do app de verdade rodando num celular Android (emulador
`Medium_Phone_2`, 1080×2400, 411×914 dp): a biblioteca em retrato e a
partitura em paisagem. Servem de referência do que o aluno vê hoje — o
estudo de UX em `docs/ux/` parte delas.

## Como refazer

    emulator -avd Medium_Phone_2 -read-only -no-window -no-audio &
    just telas

O roteiro é `integration_test/telas_celular_test.dart`; quem grava os PNGs é
`test_driver/telas_celular.dart`. Precisa do mesmo preparo do `just build-apk`
(`.so` do Verovio e do áudio em `jniLibs/`, hinos e `verovio_data.zip`).

O que as fotos **não** mostram:

- a barra de status e a de navegação do Android (a foto é só da área do
  Flutter — por isso a faixa em branco no topo das telas em paisagem);
- o teclado virtual: nas telas de busca, o espaço vazio embaixo da lista é
  onde ele estaria;
- um teclado MIDI de verdade: o da 2ª passagem é falso (toca as notas que a
  etapa espera e erra algumas de propósito).

## 1ª passagem — primeiro uso, sem teclado

| Arquivo | Tela |
|---|---|
| `01-abertura` | Splash |
| `02-biblioteca-primeiro-uso` | Biblioteca sem histórico |
| `03-biblioteca-busca` | Busca com resultados ("santo") |
| `04-biblioteca-busca-sem-resultado` | Busca sem resultado |
| `05-biblioteca-por-dificuldade` | Ordenada por dificuldade |
| `06-teclado-midi-nenhum` | Seletor de teclado MIDI, vazio |
| `07-configuracoes` | Configurações gerais (tela cheia) |
| `08-configuracoes-mudar-o-padrao` | Confirmação ao mudar os compassos por trecho |
| `09-seletor-de-cor` | Seletor de cor |
| `10-hino-abrindo` | Partitura sendo gravada |
| `11-trilha-sem-teclado` | Partitura com a faixa da trilha |
| `12-trilha-pede-teclado` | Play na trilha sem teclado conectado |
| `13-gaveta-da-trilha` | Gaveta da trilha, nada feito |
| `14`–`16-opcoes-de-estudo…` | Gaveta de opções (começo, meio e fim) |
| `17-layout-do-hino` | Painel "Layout deste hino" |
| `18-configuracoes-na-partitura` | Configurações gerais sobre a partitura |
| `19-ir-para-compasso` | Ir para um compasso |
| `20-repetir-um-trecho` | Repetir um trecho (loop) |
| `21-treino-livre` | Treino livre, parado |
| `22-contagem` | Contagem regressiva antes de tocar |
| `23-tocando` | Tocando, na virada de página |
| `24-opcoes-modo-espera` | Opções com o modo "Espera" escolhido |
| `25-espera-sem-teclado` | Modo espera sem teclado |
| `26-biblioteca-continuar` | Biblioteca com o cartão "Continuar" |

## 2ª passagem — com histórico e teclado MIDI

| Arquivo | Tela |
|---|---|
| `27-biblioteca-com-historico` | Biblioteca com pontuações e trilhas em andamento |
| `28-biblioteca-por-pontuacao` | Ordenada por pontuação |
| `29-teclado-midi-conectado` | Seletor de teclado MIDI, conectado |
| `30-trilha-retomada` | Partitura retomando a trilha no 2º trecho |
| `31-gaveta-da-trilha-com-progresso` | Gaveta da trilha com um trecho feito |
| `32-etapa-espera` | Etapa do modo espera, começando |
| `33-etapa-nota-errada` | Etapa com uma tecla errada (nota fantasma) |
| `34-resumo-da-etapa` | Resumo de etapa aprovada |
| `35-proxima-etapa` | Etapa seguinte selecionada |
| `36-gaveta-etapas-concluidas` | Gaveta com as etapas do trecho concluído |
| `37-etapa-contagem` | Contagem de uma etapa com tempo |
| `38-etapa-tempo-real` | Etapa em tempo real |
| `39-resumo-da-etapa-reprovada` | Resumo de etapa reprovada |
| `40-opcoes-treino-em-tempo-real` | Opções do treino livre em tempo real |
| `41-treino-livre-tempo-real` | Treino livre em tempo real |
| `42-resumo-do-treino` | Resumo de precisão do treino livre |
| `43-configuracoes-com-teclado` | Configurações gerais com o teclado ligado |
| `44-calibrar-latencia` | Calibrar a latência |
| `45-monitor-midi` | Painel do monitor MIDI |
| `46-biblioteca-depois-do-estudo` | Biblioteca ao voltar do estudo |
