// R01 — teste de camadas: lê os imports e exports de `lib/` e barra os que
// cruzam camadas no sentido proibido (achados 7–9 de
// docs/revisao/2026-10-06-qualidade-e-divisao.md). Os desvios de hoje estão
// em `_desviosConhecidos`; cada passo R apaga as linhas que resolveu, e o
// teste falha tanto com um desvio novo quanto com um que já sumiu do código.
//
// As camadas de baixo (base musical, formato dos cursos, som, diagnóstico,
// MIDI e bibliotecas) viraram pacotes do workspace nos passos R13–R17: o
// compilador já impede que importem o app, e os grupos delas saíram daqui.
// Ficam as regras entre pastas que continuam no app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _sob(String arquivo, String pasta) => arquivo.startsWith('$pasta/');

const _appSettings = 'settings/app_settings.dart';
const _folhasDeAppSettings = {
  'practice/practice_mode.dart',
  'practice/practice_colors.dart',
  'trail/trail_stage.dart',
};
const _entradasDoApp = {'main.dart'};

/// As regras que o par `origem → alvo` quebra (vazia se nenhuma).
List<String> _regrasQuebradas(String origem, String alvo) {
  final quebradas = <String>[];
  if (_sob(origem, 'practice') && _sob(alvo, 'trail')) {
    quebradas.add('practice/ não importa trail/');
  }
  // Fora de lib/, só a base musical (`package:zywny_music`), que o
  // compilador já separa.
  if (origem == _appSettings && !_folhasDeAppSettings.contains(alvo)) {
    quebradas.add(
      '$_appSettings só importa ${_folhasDeAppSettings.join(', ')}',
    );
  }
  if (_sob(alvo, 'app') &&
      !_sob(origem, 'app') &&
      !_entradasDoApp.contains(origem)) {
    quebradas.add(
      'só ${_entradasDoApp.join(' e ')} e a própria pasta importam app/',
    );
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
    expect(_regrasQuebradas('practice/hand.dart', 'trail/trail_stage.dart'), [
      'practice/ não importa trail/',
    ]);
    expect(
      _regrasQuebradas('trail/trail_stage.dart', 'practice/hand.dart'),
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
