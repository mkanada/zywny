import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zywny • dotLottie',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const DotLottieHomePage(),
    );
  }
}

enum AnimFonte { assetLottie, assetJson, rede }

class DotLottieHomePage extends StatefulWidget {
  const DotLottieHomePage({super.key});

  @override
  State<DotLottieHomePage> createState() => _DotLottieHomePageState();
}

class _DotLottieHomePageState extends State<DotLottieHomePage> {
  AnimFonte _fonte = AnimFonte.assetJson;
  DotLottieViewController? _controller;
  String _status = 'pronto';
  double _velocidade = 1.0;

  // Animação interessante encontrada na internet (exemplo oficial LottieFiles):
  // ilustração "Add Music" (480x360, 370 frames, 60fps) hospedada no lottie.host.
  static const _urlRede =
      'https://lottie.host/d12158de-44c9-4079-b980-3bf63694f918/VrgZppaPQ8.json';

  // NOTA: o plugin faz `rootBundle.load('assets/$source')` internamente,
  // por isso aqui vai só o nome do arquivo (sem o prefixo `assets/`).
  String get _source => switch (_fonte) {
    AnimFonte.assetLottie => 'animacao.lottie',
    AnimFonte.assetJson => 'musica.json',
    AnimFonte.rede => _urlRede,
  };

  String get _sourceType => _fonte == AnimFonte.rede ? 'url' : 'asset';

  String get _descricao => switch (_fonte) {
    AnimFonte.assetLottie => 'dotLottie oficial de exemplo (.lottie, offline)',
    AnimFonte.assetJson => '"Add Music" em JSON (offline, 370 frames)',
    AnimFonte.rede => '"Add Music" via rede (lottie.host, online)',
  };

  void _setStatus(String s) => setState(() => _status = s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('zywny • dotLottie'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              SegmentedButton<AnimFonte>(
                segments: const [
                  ButtonSegment(
                    value: AnimFonte.assetLottie,
                    label: Text('.lottie'),
                    icon: Icon(Icons.folder),
                  ),
                  ButtonSegment(
                    value: AnimFonte.assetJson,
                    label: Text('.json'),
                    icon: Icon(Icons.music_note),
                  ),
                  ButtonSegment(
                    value: AnimFonte.rede,
                    label: Text('rede'),
                    icon: Icon(Icons.cloud),
                  ),
                ],
                selected: {_fonte},
                onSelectionChanged: (s) => setState(() {
                  _fonte = s.first;
                  _controller = null;
                  _status = 'trocando fonte…';
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _descricao,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                clipBehavior: Clip.antiAlias,
                child: DotLottieView(
                  key: ValueKey(_source),
                  source: _source,
                  sourceType: _sourceType,
                  autoplay: true,
                  loop: true,
                  speed: _velocidade,
                  onViewCreated: (c) => _controller = c,
                  onLoad: () => _setStatus('carregada ✓'),
                  onLoadError: () => _setStatus('erro ao carregar ✗'),
                  onPlay: () => _setStatus('tocando ▶'),
                  onPause: () => _setStatus('pausada ⏸'),
                  onStop: () => _setStatus('parada ⏹'),
                  onComplete: () => _setStatus('concluída ✓'),
                  onLoop: (n) => _setStatus('loop ${n.toInt()} 🔁'),
                ),
              ),
              const SizedBox(height: 12),
              Text('status: $_status'),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _controller?.play(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _controller?.pause(),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _controller?.stop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: .min,
                children: [
                  const Text('Velocidade: '),
                  DropdownButton<double>(
                    value: _velocidade,
                    items: const [0.5, 1.0, 1.5, 2.0]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('${v}x'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _velocidade = v);
                      await _controller?.setSpeed(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Fonte: lottie.host (doc oficial dotLottie) + LottieFiles',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
