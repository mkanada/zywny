# I06 — Teclado da tela como entrada de notas

**Status: dispensado** (D-LIC-SEM-TECLADO, decidida pelo usuário em
2026-10-04).

O I00 propunha um teclado de duas oitavas na tela para fazer os exercícios
sem teclado MIDI. A decisão foi **não ter teclado na tela**: os tipos que
tocam notas (`find-key`, `play-notes`, `rhythm`, `play-score`) exigem o
teclado MIDI e mostram "Conecte o teclado" (o fluxo do U15); os de botões
(`name-note`, `count-beats`, `choice`) funcionam sem ele.

O que este passo faria e onde isso foi parar:

| Item | Destino |
| --- | --- |
| Fonte de notas além do MIDI | Não existe. `MidiInputService` continua a única |
| Botões de resposta nos tipos por pergunta | I07 |
| Aviso "Conecte o teclado" no cartão e na tela do exercício | I05 (cartão) e I09 (tela) |

Se a decisão mudar, este arquivo vira o passo: um `MidiInputService` cujas
notas vêm de toques num `PianoKeyboardPainter` tocável (generalizado no
I05), com `atSeconds` do relógio do app.
