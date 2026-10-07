# Teste no celular — 07/10/2026

Roteiro para conferir, no Galaxy M14, o que foi feito em 07/10/2026 e o que
estava esperando a sua avaliação. Este documento se basta: não depende da
conversa em que foi escrito.

- **Versão testada:** commit `cf59f67` (main), APK arm64 release com a chave
  da biblioteca.
- **Como gerar e instalar** (quando a árvore estiver em outro estado):
  `just build-apk`, depois `just instalar-apk` (mantém os dados). Nunca
  `flutter build apk` direto: sem `--dart-define=ZYWNY_LIBRARY_KEY` o app não
  abre nenhuma biblioteca. O APK sai em
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~51 MB).
- **Instalar pelo Wi-Fi:** o `adb` está em `~/Android/Sdk/platform-tools/adb`
  (fora do PATH). Ligue a depuração sem fio no celular, na mesma rede do
  computador; `adb mdns services` mostra a porta; `adb connect IP:porta`.
  Em 07/10 o celular não estava na rede (IP antigo: 192.168.0.192) e o APK
  **ainda não foi instalado**.
- **Como responder:** preencha a coluna "Resultado" (OK / falhou / mudar) e
  escreva o que viu na coluna "Observação". Onde pedir uma opinião, ela vale
  mais que o OK.

---

## A. O que mudou em 07/10 — revisão do treino e páginas

Precisa do teclado MIDI conectado. Use uma música com acordes e outra com
notas soltas (a Gymnopédie mostra os dois casos).

### O que o app faz agora

- **Nota tocada errada** (tecla de altura errada, ou a tecla certa fora do
  tempo) vira uma bolinha laranja (fantasma) ao lado da coluna esperada:
  - **tempo real:** à esquerda se foi tocada antes do tempo, à direita se
    depois, a meia cabeça de nota de distância (decisão sua);
  - **modo espera:** em cima da coluna, sem lado (não existe tempo certo).
- **Fim do treino** (livre ou etapa da trilha): a barra no pé da partitura diz
  "N notas para rever" com o botão **Revisar**. O resumo do tempo real tem o
  botão equivalente.
- **Revisão:** as notas ficam fixas na partitura; abre na primeira página com
  erro; os botões « » pulam entre as páginas com erro; o **X** fecha.
- **Botões de página** (só no celular): parado, uma pílula `‹ 2 / 5 ›` no pé
  da partitura. Some durante treino e música tocando, e quando a música tem
  uma página só. Fora de treino/música a página muda **sem animação**.

### Como o tempo é julgado (para interpretar o que você vir)

No tempo real, a tecla de uma nota esperada conta como:

| Desvio do tempo certo | Veredito | Aparece na revisão? |
|---|---|---|
| até a tolerância (padrão 75 ms) | certa | não |
| de 75 até 150 ms, antes | adiantada | sim, à esquerda |
| de 75 até 150 ms, depois | atrasada | sim, à direita |
| além de 150 ms | errada (e a nota esperada vira "perdida") | sim, como altura errada, na coluna mais próxima no tempo (até 1 s) |

A tolerância é configurável (ritmo); a janela máxima é o dobro dela.

### Testes

| # | O que fazer | O que deve acontecer | Resultado | Observação |
|---|---|---|---|---|
| A1 | Tempo real. Toque uma nota certa uns 100–130 ms **atrasada** | Bolinha laranja **à direita** da nota, colada nela. **Opinião:** a distância está boa? | | |
| A2 | O mesmo, **adiantada** | Bolinha à **esquerda** | | |
| A3 | Toque uma tecla de altura errada antes do tempo e outra depois | As duas aparecem, do lado certo | | |
| A4 | Compare A1 com A3 | Hoje as duas saem no mesmo laranja. **Opinião:** quer cor diferente para "fora do tempo" e "altura errada"? | | |
| A5 | Modo espera, toque uma tecla errada | A bolinha fica em cima da coluna, sem lado. É o que você esperava? | | |
| A6 | Termine um treino livre com erros | Barra "N notas para rever" com **Revisar** e X | | |
| A7 | Termine uma etapa da trilha com erros | A barra aparece depois de fechar o resumo da etapa | | |
| A8 | Termine um treino em tempo real | O resumo tem o botão "Ver as N notas para rever na partitura" | | |
| A9 | Toque em **Revisar** | Notas fixas na partitura; abre na primeira página com erro | | |
| A10 | Na revisão, use « » | Pula para a página com erro anterior/seguinte (desabilita quando não há) | | |
| A11 | Na revisão, em paisagem | A legenda "à esquerda da nota: antes do tempo · à direita: depois" cabe sem estragar a tela | | |
| A12 | Feche com o X; toque a música; comece outro treino; troque de etapa | Em todos a revisão some | | |
| A13 | Parado, sem treino | Pílula `‹ 2 / 5 ›` visível; botões funcionam; página muda de uma vez | | |
| A14 | A pílula cobre alguma nota? | Não deveria cobrir a música; se cobrir, anote em que música/página | | |
| A15 | Comece o treino e a música | A pílula some; a virada de página volta a ser animada | | |
| A16 | Abra uma música de uma página só | Sem pílula | | |
| A17 | Acorde tocado fora do tempo | As fantasmas ficam legíveis? Num acorde errado eu vi sobreposição parcial com as notas reais | | |
| A18 | Gaveta ⋯ → Página anterior / Próxima | Funcionam; tocando animam, parados não | | |

### Limites conhecidos (já sabidos, não precisa reportar de novo)

- O afastamento é **fixo** (0,5 cabeça), não cresce com o tamanho do atraso.
- Uma nota muito atrasada (além de 150 ms) é tratada como altura errada e vai
  para a coluna mais próxima no tempo, que pode ser a nota seguinte.
- Fantasma de nota atrasada pode ficar perto da nota seguinte quando as notas
  estão juntas.
- A revisão some ao regravar a partitura (mudar tamanho da notação, etc.).

### Como refazer a imagem de exemplo

`REVISAO_CENARIO=atrasada REVISAO_PNG=/tmp/atrasada.png flutter test test/revisao_imagem_manual_test.dart`
gera `atrasada.png` e `atrasada_zoom.png` com o código real (sessão de tempo
real simulada sobre a Gymnopédie). Sem `REVISAO_CENARIO`, gera o cenário misto.

---

## B. Pendências antigas que dependem de você

### B1. Refatoração R08–R11 (mexeu no coração do app)

Os planos dizem "manual" em cada um; nada disto foi conferido no aparelho.

| # | O que fazer | Resultado | Observação |
|---|---|---|---|
| B1.1 | Som: ligar e desligar; trocar entre sintetizador e teclado MIDI e voltar; ligar o monitor MIDI (R08) | | |
| B1.2 | Com som e sem som: tocar, pausar, repetir um trecho, metrônomo, contagem, mudar o andamento tocando (R10) | | |
| B1.3 | Uma etapa da trilha do começo ao fim (R11) | | |
| B1.4 | Uma etapa com erro de propósito (R11) | | |
| B1.5 | Trocar de tom no meio da trilha (R11) | | |

### B2. Pacotes (R15–R17)

| # | O que fazer | Resultado | Observação |
|---|---|---|---|
| B2.1 | Conectar o teclado, tocar com o monitor ligado, desconectar e reconectar sozinho (R16) | | |
| B2.2 | `just pacote-hinos` gera o pacote e o app o instala por arquivo (R17), se tiver um à mão | | |
| B2.3 | `just run` com som no Linux e `just web-smoke` tocam como antes (R15) | | |

Obs.: o build Linux desta máquina estava parado em `libunwind.pc` (gstreamer
do `audioplayers_linux`), problema do ambiente, não do código.

### B3. Transpor (Q08) — a tabela de aceite está em branco

O roteiro original está em `docs/plano/Q08-tela-e-aceite.md`. Resumo, com o seu
teclado:

| # | O que fazer | Resultado | Observação |
|---|---|---|---|
| B3.1 | Hino em Mi♭ (3♭): "Sem acidentes" → partitura em Dó; a conferência pede +3; tocar Dó soa Mi♭. **Anote:** o teclado transpõe a saída? E a entrada? Qual o modelo? | | |
| B3.2 | Modo espera e tempo real passam tocando as teclas de Dó maior; "ouvir o trecho" soa em Mi♭ junto com o teclado | | |
| B3.3 | Hino com 2♯ ou 4♯: o mesmo, com o TRANSPOSE do outro sinal | | |
| B3.4 | Voltar a "Não" com o teclado ainda em +3: o detector avisa em até 6 notas erradas (se o teclado transpõe a saída) ou aparece o lembrete de voltar a 0 (se não transpõe). Se avisar tarde ou cedo demais, ajustar o N | | |
| B3.5 | Hino em 6♯ ou 6♭ (se existir): o trítono desce | | |

O passo Q08 só vira "concluído" quando esta tabela estiver preenchida.

### B4. Exercício do curso — dois pedidos seus ainda não feitos

1. **"Continuar tocando"** no exercício em tempo real: você se perdeu no tempo
   e errou várias notas; hoje a rodada segue e conta erro. Falta definir o
   que significa (esperar? retomar? não parar?). **Decisão sua.**
2. **Lição 10 (Ode):** a primeira vez só com notas, sem ritmo (modo espera);
   depois com ritmo. Arquivo: `assets/cursos/iniciacao/lessons/10-juntando-tudo.md`
   (hoje os três exercícios estão em `mode: realtime`).

Também decidir o diagnóstico temporário `lib/render/score_size_log.dart`
(grava `ZYWNY_TAMANHO` no diag.log e um PNG por partitura): tirar o PNG ou tudo.

### B5. Telas em retrato e paisagem (docs/ux/estudo-ux-orientacao.md)

| # | Achado | O que conferir | Resultado | Observação |
|---|---|---|---|---|
| B5.1 | X1 | O exercício não percebe que o teclado caiu | | |
| B5.2 | X2 | O markdown das lições mantém a quebra de linha das linhas suaves | | |
| B5.3 | P1 | A página fica parada no meio da virada ao retomar a trilha (precisa de aparelho) | | |

### B6. Decisões abertas da fase U (docs/plano/README.md)

São recomendações minhas, **não aprovadas por você**. Cada uma mexe em algo que
você desenhou de propósito; passo U com decisão só avança depois da sua resposta.

| Decisão | Resposta |
|---|---|
| D-FAIXA | |
| D-OUVIR | |
| D-SOM | |
| D-SELO | |
| D-VIRADA | |
| D-CONTAGEM | |
| D-SISTEMAS | |
| D-MODOS | |
| D-ORDEM | |

---

## Como me passar o retorno

Cole a tabela preenchida (ou só as linhas que falharam ou pedem mudança) e,
nos itens de opinião (A1, A4, A5, A17, B4, B6), diga o que prefere. Com isso
eu ajusto a distância e as cores das fantasmas, a regra da nota muito
atrasada, e sigo com os passos que dependiam das suas decisões.
