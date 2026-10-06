# Índice de telas

Todas as telas do app num só lugar, em ordem de uso. Capturas do app real num celular Android (emulador 1080×2400); retrato na biblioteca, paisagem na partitura. Cada foto leva o número do arquivo em [`celular/`](celular/).

- Como refazer as fotos e o que elas não mostram: [`celular/README.md`](celular/README.md).
- Análise de UX a partir delas: [`../ux/estudo-ux-celular.md`](../ux/estudo-ux-celular.md).
- As mesmas telas em retrato e em paisagem, lado a lado: [`ORIENTACAO.md`](ORIENTACAO.md); análise em [`../ux/estudo-ux-orientacao.md`](../ux/estudo-ux-orientacao.md).
- Protótipo navegável (não é o app): `lib/mockup/` e `lib/main_mockup.dart` — não entra nas fotos.

Total: 60 telas.

## Abertura e biblioteca

Retrato. O que o aluno vê ao abrir o app e ao escolher um hino.

Código: `lib/splash_screen.dart` · `lib/library/library_screen.dart`

<table><tr><td align="center"><a href="celular/01-abertura.png"><img src="celular/01-abertura.png" width="200"></a><br><sub><b>01</b> · Abertura (splash)</sub></td><td align="center"><a href="celular/02-biblioteca-primeiro-uso.png"><img src="celular/02-biblioteca-primeiro-uso.png" width="200"></a><br><sub><b>02</b> · Biblioteca, primeiro uso</sub></td><td align="center"><a href="celular/03-biblioteca-busca.png"><img src="celular/03-biblioteca-busca.png" width="200"></a><br><sub><b>03</b> · Busca com resultados</sub></td><td align="center"><a href="celular/04-biblioteca-busca-sem-resultado.png"><img src="celular/04-biblioteca-busca-sem-resultado.png" width="200"></a><br><sub><b>04</b> · Busca sem resultado</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/05-biblioteca-por-dificuldade.png"><img src="celular/05-biblioteca-por-dificuldade.png" width="200"></a><br><sub><b>05</b> · Ordenada por dificuldade</sub></td><td align="center"><a href="celular/26-biblioteca-continuar.png"><img src="celular/26-biblioteca-continuar.png" width="200"></a><br><sub><b>26</b> · Biblioteca com “Continuar”</sub></td><td align="center"><a href="celular/27-biblioteca-com-historico.png"><img src="celular/27-biblioteca-com-historico.png" width="200"></a><br><sub><b>27</b> · Biblioteca com histórico</sub></td><td align="center"><a href="celular/28-biblioteca-por-pontuacao.png"><img src="celular/28-biblioteca-por-pontuacao.png" width="200"></a><br><sub><b>28</b> · Ordenada por pontuação</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/46-biblioteca-depois-do-estudo.png"><img src="celular/46-biblioteca-depois-do-estudo.png" width="200"></a><br><sub><b>46</b> · Biblioteca depois do estudo</sub></td></tr></table>

## Teclado MIDI e configurações

Retrato (06, 29, 07–09) e paisagem (43–45). Seletor de teclado, configurações gerais e ferramentas de MIDI.

Código: `lib/midi/midi_device_picker.dart` · `lib/settings/general_settings_panel.dart` · `lib/settings/color_picker.dart` · `lib/midi/midi_monitor_panel.dart`

<table><tr><td align="center"><a href="celular/06-teclado-midi-nenhum.png"><img src="celular/06-teclado-midi-nenhum.png" width="200"></a><br><sub><b>06</b> · Teclado MIDI: nenhum</sub></td><td align="center"><a href="celular/29-teclado-midi-conectado.png"><img src="celular/29-teclado-midi-conectado.png" width="200"></a><br><sub><b>29</b> · Teclado MIDI: conectado</sub></td><td align="center"><a href="celular/07-configuracoes.png"><img src="celular/07-configuracoes.png" width="200"></a><br><sub><b>07</b> · Configurações gerais</sub></td><td align="center"><a href="celular/08-configuracoes-mudar-o-padrao.png"><img src="celular/08-configuracoes-mudar-o-padrao.png" width="200"></a><br><sub><b>08</b> · Confirmação “Mudar o tamanho dos trechos?”</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/09-seletor-de-cor.png"><img src="celular/09-seletor-de-cor.png" width="200"></a><br><sub><b>09</b> · Seletor de cor</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/43-configuracoes-com-teclado.png"><img src="celular/43-configuracoes-com-teclado.png" width="440"></a><br><sub><b>43</b> · Configurações com teclado</sub></td><td align="center"><a href="celular/44-calibrar-latencia.png"><img src="celular/44-calibrar-latencia.png" width="440"></a><br><sub><b>44</b> · Ajustar o atraso</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/45-monitor-midi.png"><img src="celular/45-monitor-midi.png" width="440"></a><br><sub><b>45</b> · Monitor MIDI (“Teclas que chegam”)</sub></td></tr></table>

## Partitura e trilha de estudo

Paisagem. O hino aberto, a trilha por trechos e a gaveta de etapas.

Código: `lib/main.dart` · `lib/trail/trail_widgets.dart` · `lib/ui/side_panel.dart`

<table><tr><td align="center"><a href="celular/10-hino-abrindo.png"><img src="celular/10-hino-abrindo.png" width="440"></a><br><sub><b>10</b> · Partitura sendo gravada</sub></td><td align="center"><a href="celular/11-trilha-sem-teclado.png"><img src="celular/11-trilha-sem-teclado.png" width="440"></a><br><sub><b>11</b> · Trilha sem teclado</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/12-ouvindo-o-trecho.png"><img src="celular/12-ouvindo-o-trecho.png" width="440"></a><br><sub><b>12</b> · Ouvindo o trecho</sub></td><td align="center"><a href="celular/13-gaveta-da-trilha.png"><img src="celular/13-gaveta-da-trilha.png" width="440"></a><br><sub><b>13</b> · Gaveta da trilha</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/30-trilha-retomada.png"><img src="celular/30-trilha-retomada.png" width="440"></a><br><sub><b>30</b> · Trilha retomada</sub></td><td align="center"><a href="celular/31-gaveta-da-trilha-com-progresso.png"><img src="celular/31-gaveta-da-trilha-com-progresso.png" width="440"></a><br><sub><b>31</b> · Gaveta da trilha com progresso</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/36-gaveta-etapas-concluidas.png"><img src="celular/36-gaveta-etapas-concluidas.png" width="440"></a><br><sub><b>36</b> · Gaveta: etapas concluídas</sub></td></tr></table>

## Opções e ajustes da partitura

Paisagem. Painéis laterais abertos sobre a partitura.

Código: `lib/mockup/options_panel.dart` · `lib/layout_panel.dart` · `lib/practice/practice_tools.dart`

<table><tr><td align="center"><a href="celular/14-opcoes-de-estudo.png"><img src="celular/14-opcoes-de-estudo.png" width="440"></a><br><sub><b>14</b> · Opções de estudo (começo)</sub></td><td align="center"><a href="celular/15-opcoes-de-estudo-meio.png"><img src="celular/15-opcoes-de-estudo-meio.png" width="440"></a><br><sub><b>15</b> · Opções de estudo (meio)</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/16-opcoes-de-estudo-fim.png"><img src="celular/16-opcoes-de-estudo-fim.png" width="440"></a><br><sub><b>16</b> · Opções de estudo (fim)</sub></td><td align="center"><a href="celular/17-layout-do-hino.png"><img src="celular/17-layout-do-hino.png" width="440"></a><br><sub><b>17</b> · Ajustes da partitura</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/18-configuracoes-na-partitura.png"><img src="celular/18-configuracoes-na-partitura.png" width="440"></a><br><sub><b>18</b> · Configurações sobre a partitura</sub></td><td align="center"><a href="celular/19-ir-para-compasso.png"><img src="celular/19-ir-para-compasso.png" width="440"></a><br><sub><b>19</b> · Ir para um compasso</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/20-repetir-um-trecho.png"><img src="celular/20-repetir-um-trecho.png" width="440"></a><br><sub><b>20</b> · Repetir um trecho</sub></td></tr></table>

## Treino livre

Paisagem. Tocar o hino sem trilha, com contagem e resumo.

Código: `lib/practice/count_in_overlay.dart` · `lib/practice/practice_tools.dart`

<table><tr><td align="center"><a href="celular/21-treino-livre.png"><img src="celular/21-treino-livre.png" width="440"></a><br><sub><b>21</b> · Treino livre, parado</sub></td><td align="center"><a href="celular/22-contagem.png"><img src="celular/22-contagem.png" width="440"></a><br><sub><b>22</b> · Contagem regressiva</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/23-tocando.png"><img src="celular/23-tocando.png" width="440"></a><br><sub><b>23</b> · Tocando (virada de página)</sub></td><td align="center"><a href="celular/24-opcoes-modo-espera.png"><img src="celular/24-opcoes-modo-espera.png" width="440"></a><br><sub><b>24</b> · Opções com modo Espera</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/25-espera-sem-teclado.png"><img src="celular/25-espera-sem-teclado.png" width="440"></a><br><sub><b>25</b> · Modo espera sem teclado</sub></td><td align="center"><a href="celular/40-opcoes-treino-em-tempo-real.png"><img src="celular/40-opcoes-treino-em-tempo-real.png" width="440"></a><br><sub><b>40</b> · Opções do treino em tempo real</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/41-treino-livre-tempo-real.png"><img src="celular/41-treino-livre-tempo-real.png" width="440"></a><br><sub><b>41</b> · Treino livre em tempo real</sub></td><td align="center"><a href="celular/42-resumo-do-treino.png"><img src="celular/42-resumo-do-treino.png" width="440"></a><br><sub><b>42</b> · Resumo do treino</sub></td></tr></table>

## Etapas da trilha

Paisagem. Uma etapa em andamento, do início ao resumo.

Código: `lib/trail/trail_widgets.dart` · `lib/ui/practice_legend.dart`

<table><tr><td align="center"><a href="celular/32-etapa-espera.png"><img src="celular/32-etapa-espera.png" width="440"></a><br><sub><b>32</b> · Etapa do modo espera</sub></td><td align="center"><a href="celular/33-etapa-nota-errada.png"><img src="celular/33-etapa-nota-errada.png" width="440"></a><br><sub><b>33</b> · Etapa com tecla errada</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/34-resumo-da-etapa.png"><img src="celular/34-resumo-da-etapa.png" width="440"></a><br><sub><b>34</b> · Resumo da etapa aprovada</sub></td><td align="center"><a href="celular/35-proxima-etapa.png"><img src="celular/35-proxima-etapa.png" width="440"></a><br><sub><b>35</b> · Etapa seguinte</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/37-etapa-contagem.png"><img src="celular/37-etapa-contagem.png" width="440"></a><br><sub><b>37</b> · Etapa com contagem</sub></td><td align="center"><a href="celular/38-etapa-tempo-real.png"><img src="celular/38-etapa-tempo-real.png" width="440"></a><br><sub><b>38</b> · Etapa em tempo real</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/39-resumo-da-etapa-reprovada.png"><img src="celular/39-resumo-da-etapa-reprovada.png" width="440"></a><br><sub><b>39</b> · Resumo da etapa reprovada</sub></td></tr></table>

## Cursos da fase I

Retrato (47–58), paisagem no exercício com partitura (59–60). O curso inicial embutido, a lição 2 e os três tipos de exercício com e sem teclado.

Código: `lib/course/ui/courses_screen.dart` · `lib/course/ui/course_screen.dart` · `lib/course/ui/lesson_screen.dart` · `lib/course/ui/exercise_screen.dart`

<table><tr><td align="center"><a href="celular/47-curso-inicial-sem-biblioteca.png"><img src="celular/47-curso-inicial-sem-biblioteca.png" width="200"></a><br><sub><b>47</b> · Curso inicial sem biblioteca</sub></td><td align="center"><a href="celular/48-licao-1-pelo-cartao.png"><img src="celular/48-licao-1-pelo-cartao.png" width="200"></a><br><sub><b>48</b> · Lição 1 pelo cartão</sub></td><td align="center"><a href="celular/49-biblioteca-com-cursos.png"><img src="celular/49-biblioteca-com-cursos.png" width="200"></a><br><sub><b>49</b> · Biblioteca com “Cursos”</sub></td><td align="center"><a href="celular/50-lista-de-cursos.png"><img src="celular/50-lista-de-cursos.png" width="200"></a><br><sub><b>50</b> · Lista de cursos</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/51-tela-do-curso.png"><img src="celular/51-tela-do-curso.png" width="200"></a><br><sub><b>51</b> · Curso: feita, aberta, bloqueadas</sub></td><td align="center"><a href="celular/52-licao-2-topo.png"><img src="celular/52-licao-2-topo.png" width="200"></a><br><sub><b>52</b> · Lição 2 (topo)</sub></td><td align="center"><a href="celular/53-licao-2-partitura.png"><img src="celular/53-licao-2-partitura.png" width="200"></a><br><sub><b>53</b> · Lição 2 (partitura)</sub></td><td align="center"><a href="celular/54-licao-2-exercicio.png"><img src="celular/54-licao-2-exercicio.png" width="200"></a><br><sub><b>54</b> · Lição 2 (“Precisa do teclado”)</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/55-exercicio-conecte-o-teclado.png"><img src="celular/55-exercicio-conecte-o-teclado.png" width="440"></a><br><sub><b>55</b> · “Conecte o teclado”</sub></td><td align="center"><a href="celular/56-exercicio-name-note.png"><img src="celular/56-exercicio-name-note.png" width="440"></a><br><sub><b>56</b> · Exercício `name-note`</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/57-licao-8-choice-cartao.png"><img src="celular/57-licao-8-choice-cartao.png" width="200"></a><br><sub><b>57</b> · Cartão do `choice`</sub></td><td align="center"><a href="celular/58-exercicio-choice.png"><img src="celular/58-exercicio-choice.png" width="440"></a><br><sub><b>58</b> · Exercício `choice`</sub></td></tr></table>

<table><tr><td align="center"><a href="celular/59-exercicio-play-notes-antes.png"><img src="celular/59-exercicio-play-notes-antes.png" width="440"></a><br><sub><b>59</b> · `play-notes` antes</sub></td><td align="center"><a href="celular/60-exercicio-play-notes-depois.png"><img src="celular/60-exercicio-play-notes-depois.png" width="440"></a><br><sub><b>60</b> · `play-notes` aprovado</sub></td></tr></table>
