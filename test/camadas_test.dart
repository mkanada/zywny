// R01 — teste de camadas: lê os imports e exports de `lib/` e barra os que
// cruzam camadas no sentido proibido (achados 7–9 de
// docs/revisao/2026-10-06-qualidade-e-divisao.md). Os desvios de hoje estão
// em `_desviosConhecidos`; cada passo R apaga as linhas que resolveu, e o
// teste falha tanto com um desvio novo quanto com um que já sumiu do código.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Uma camada: um conjunto de arquivos (caminhos relativos a `lib/`) e os
/// grupos de que eles podem depender, além de si mesmos.
class _Grupo {
  const _Grupo(this.nome, this.contem, this.podeImportar);

  final String nome;
  final bool Function(String arquivo) contem;
  final List<String> podeImportar;
}

bool _sob(String arquivo, String pasta) => arquivo.startsWith('$pasta/');

const _midiDoPacote = {
  'midi/midi_input_service.dart',
  'midi/midi_device_manager.dart',
  'midi/midi_out_sound_engine.dart',
  'midi/midi_monitor.dart',
  'midi/midi_labels.dart',
};

final _grupos = <_Grupo>[
  _Grupo('music', (f) => _sob(f, 'music'), []),
  _Grupo(
    'formato',
    (f) =>
        _sob(f, 'course/format') &&
        f != 'course/format/course_render_check.dart',
    ['music'],
  ),
  _Grupo(
    'áudio',
    (f) => _sob(f, 'audio') && !f.startsWith('audio/sound_engine_debug_panel'),
    ['music', 'core'],
  ),
  _Grupo(
    'midi',
    (f) => _midiDoPacote.contains(f) || f.startsWith('midi/web_midi_access'),
    ['áudio', 'music', 'core'],
  ),
  _Grupo('biblioteca', (f) => _sob(f, 'library'), ['music', 'core']),
  _Grupo('core', (f) => _sob(f, 'core'), []),
];

const _appSettings = 'settings/app_settings.dart';
const _folhasDeAppSettings = {
  'practice/practice_mode.dart',
  'practice/practice_colors.dart',
  'trail/trail_stage.dart',
};
const _entradasDoApp = {'main.dart', 'main_mockup.dart'};

/// As regras que o par `origem → alvo` quebra (vazia se nenhuma).
List<String> _regrasQuebradas(String origem, String alvo) {
  final quebradas = <String>[];
  for (final g in _grupos.where((g) => g.contem(origem))) {
    if (g.contem(alvo)) continue;
    final permitido = g.podeImportar.any(
      (nome) => _grupos.firstWhere((o) => o.nome == nome).contem(alvo),
    );
    if (!permitido) {
      quebradas.add(
        g.podeImportar.isEmpty
            ? 'a camada ${g.nome} não importa outras pastas de lib/'
            : 'a camada ${g.nome} só importa de ${g.podeImportar.join(', ')}',
      );
    }
  }
  if (_sob(origem, 'practice') && _sob(alvo, 'trail')) {
    quebradas.add('practice/ não importa trail/');
  }
  if (origem == _appSettings &&
      !_sob(alvo, 'music') &&
      !_folhasDeAppSettings.contains(alvo)) {
    quebradas.add(
      '$_appSettings só importa music/ e '
      '${_folhasDeAppSettings.join(', ')}',
    );
  }
  for (final pasta in ['app', 'mockup']) {
    if (_sob(alvo, pasta) &&
        !_sob(origem, pasta) &&
        !_entradasDoApp.contains(origem)) {
      quebradas.add(
        'só ${_entradasDoApp.join(' e ')} e a própria pasta importam $pasta/',
      );
    }
  }
  return quebradas;
}

final _diretiva = RegExp(
  r"^\s*(?:import|export)\s+'([^']+)'((?:\s*if\s*\([^)]*\)\s*'[^']+')*)",
  multiLine: true,
);
final _alvoCondicional = RegExp(r"if\s*\([^)]*\)\s*'([^']+)'");

/// Os alvos dentro de `lib/` dos imports e exports de [fonte], o arquivo
/// [origem] (relativo a `lib/`). Import condicional conta os dois alvos.
List<String> _alvos(String origem, String fonte) {
  final base = Uri.parse(origem);
  final alvos = <String>[];
  for (final m in _diretiva.allMatches(fonte)) {
    final uris = [
      m.group(1)!,
      for (final c in _alvoCondicional.allMatches(m.group(2)!)) c.group(1)!,
    ];
    for (final uri in uris) {
      if (uri.startsWith('package:zywny/')) {
        alvos.add(uri.substring('package:zywny/'.length));
      } else if (!uri.contains(':')) {
        alvos.add(base.resolve(uri).path);
      }
    }
  }
  return alvos;
}

/// Todo par `origem → alvo` de `lib/` que quebra alguma regra, com as
/// regras quebradas.
Map<String, List<String>> _desviosDeHoje() {
  final lib = Directory('lib');
  final desvios = <String, List<String>>{};
  final arquivos = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final arquivo in arquivos) {
    final origem = arquivo.path
        .substring(lib.path.length + 1)
        .replaceAll(r'\', '/');
    for (final alvo in _alvos(origem, arquivo.readAsStringSync())) {
      final regras = _regrasQuebradas(origem, alvo);
      if (regras.isNotEmpty) desvios['$origem → $alvo'] = regras;
    }
  }
  return desvios;
}

/// Os pares que violam as regras hoje, agrupados pelo passo que os resolve.
/// Quem resolve um desvio apaga a linha; não acrescente linhas novas.
const _desviosConhecidos = <String>{};

void main() {
  test('import condicional conta os dois alvos', () {
    const fonte = '''
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../music/a.dart';
import 'package:zywny/core/b.dart' show B;
export 'c_stub.dart'
    if (dart.library.js_interop) 'c_web.dart'
    show C;
// import '../trail/comentado.dart';
''';
    expect(_alvos('audio/x.dart', fonte), [
      'music/a.dart',
      'core/b.dart',
      'audio/c_stub.dart',
      'audio/c_web.dart',
    ]);
  });

  test('as regras pegam um import proibido', () {
    expect(_regrasQuebradas('music/transposition.dart', 'practice/hand.dart'), [
      'a camada music não importa outras pastas de lib/',
    ]);
    expect(
      _regrasQuebradas('midi/midi_monitor.dart', 'audio/sound_engine.dart'),
      isEmpty,
    );
  });

  test('nenhum import cruza camadas fora dos desvios conhecidos', () {
    final hoje = _desviosDeHoje();
    final novos = hoje.keys.where((p) => !_desviosConhecidos.contains(p));
    final sumidos = _desviosConhecidos.where((p) => !hoje.containsKey(p));
    final erros = [
      for (final par in novos)
        'Import proibido: $par — ${hoje[par]!.join('; ')}.',
      for (final par in sumidos)
        'Desvio resolvido: $par não existe mais; apague a linha de '
            '_desviosConhecidos em test/camadas_test.dart.',
    ];
    expect(erros, isEmpty, reason: erros.join('\n'));
  });
}
