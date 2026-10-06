import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/engine_opener.dart';
import '../audio/sound_engine.dart';
import '../course/course_installer.dart';
import '../course/course_progress.dart';
import '../course/course_store.dart';
import '../course/draft/course_draft.dart';
import '../course/draft/course_draft_screen.dart';
import '../course/draft/draft_folder.dart';
import '../course/format/course_files.dart';
import '../course/loaded_course.dart';
import '../course/ui/course_flow.dart';
import '../course/ui/courses_screen.dart';
import '../course/ui/course_screen.dart' show openLessonScreen;
import '../midi/midi_device_manager.dart';
import '../midi/midi_device_picker.dart';
import '../midi/midi_input_service.dart';
import '../midi/midi_out_sound_engine.dart';
import '../settings/app_settings.dart';
import '../settings/general_settings_panel.dart';
import '../settings/piece_settings.dart';
import '../trail/trail_progress.dart';
import '../trail/trail_widgets.dart' show TrailProgressBar, trailResumeText;
import '../ui/orientation.dart';
import '../ui/theme.dart';
import 'piece.dart';
import 'piece_progress.dart';
import 'library_installer.dart';
import 'library_package.dart' show LibraryTerm;
import 'library_term_scope.dart';
import 'library_sort.dart';
import 'library_store.dart';

/// O que a tela de partitura recebe da biblioteca ao abrir um hino.
@immutable
class OpenedPiece {
  const OpenedPiece({
    required this.piece,
    required this.scoreXml,
    required this.midiDeviceManager,
    required this.onPracticeScore,
    required this.appSettings,
    required this.pieceSettings,
    required this.onPieceSettingsChanged,
    required this.trailProgress,
    this.term = LibraryTerm.hymn,
    this.numbered = true,
  });

  final Piece piece;

  /// Como a biblioteca chama a música e se ela é numerada (B07).
  final LibraryTerm term;
  final bool numbered;

  /// O `.musicxml` do hino já descompactado, em memória.
  final Uint8List scoreXml;

  /// O mesmo gerenciador da biblioteca: o teclado conectado aqui continua
  /// conectado na partitura (e vice-versa).
  final MidiDeviceManager midiDeviceManager;

  /// Precisão (0–100) de um treino avaliado que terminou.
  final ValueChanged<int> onPracticeScore;

  /// As configurações gerais do app (som, MIDI, cores) — as mesmas que a
  /// biblioteca edita.
  final AppSettings appSettings;

  /// O que este hino tinha guardado (layout, andamento, mão), e para onde
  /// vai o que o usuário mudar nele.
  final PieceSettings pieceSettings;
  final ValueChanged<PieceSettings> onPieceSettingsChanged;

  /// O progresso da trilha (o mesmo da biblioteca, para a linha do hino
  /// atualizar ao voltar da partitura sem reabrir nada — J09).
  final TrailProgressStore trailProgress;
}

/// Tela inicial, em retrato — artboard `CelularBiblioteca.dc.html` do
/// artefato "zywny — interface de estudo", com os hinos embutidos no lugar
/// das partituras de exemplo. Não há "abrir arquivo": o app não importa
/// música.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.scoreBuilder,
    this.loadCatalog,
    this.loadScore,
    this.libraryStore,
    this.pickLibraryFile = pickLibraryBytes,
    this.progress,
    this.appSettings,
    this.pieceSettings,
    this.trailProgress,
    this.loadCourses,
    this.courseProgress,
    this.courseStore,
    this.initialDraftPath,
  });

  /// Constrói a tela de partitura do hino aberto (`ScoreHomePage`).
  final Widget Function(BuildContext context, OpenedPiece opened) scoreBuilder;

  /// Trocáveis nos testes, que não têm biblioteca instalada nem disco. Sem
  /// eles: o catálogo da biblioteca em uso e a partitura dele.
  final Future<PieceCatalog> Function()? loadCatalog;
  final Future<Uint8List> Function(Piece piece)? loadScore;
  final LibraryStore? libraryStore;

  /// O seletor do arquivo `.zywny` (biblioteca ou curso, I04); os testes
  /// trocam por um falso.
  final Future<Uint8List?> Function() pickLibraryFile;
  final PieceProgressStore? progress;
  final AppSettings? appSettings;
  final PieceSettingsStore? pieceSettings;

  /// Resumos da trilha por hino (J09); os testes injetam com dados.
  final TrailProgressStore? trailProgress;

  /// Cursos para a entrada de cursos (I09, D-LIC-ENTRADA); `null` (padrão)
  /// esconde a entrada — o embutido chega no I10, os testes injetam fixture.
  final Future<List<LoadedCourse>> Function()? loadCourses;

  /// Progresso dos cursos; os testes injetam com dados.
  final CourseProgressStore? courseProgress;

  /// Cursos instalados de pacotes `.zywny` (I04); os testes injetam.
  final CourseStore? courseStore;

  /// I12 (`just curso <pasta>`): abre direto no rascunho da pasta.
  final String? initialDraftPath;

  /// O seletor de arquivos `.zywny` (biblioteca ou curso, I04); os testes
  /// trocam por um falso.

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LibraryStore _libraries = widget.libraryStore ?? LibraryStore();
  late Future<PieceCatalog> _catalog = _loadCatalog();
  late final PieceProgressStore _progress =
      widget.progress ?? PieceProgressStore();
  final MidiDeviceManager _midi = MidiDeviceManager();

  /// Configurações gerais (uma só para o app inteiro, lida ao abrir) e as
  /// de cada hino (lidas quando o hino abre).
  late final AppSettings _settings = widget.appSettings ?? AppSettings();
  late final Future<void> _settingsLoaded = _settings.load();
  late final PieceSettingsStore _pieceSettings =
      widget.pieceSettings ?? PieceSettingsStore();
  late final TrailProgressStore _trail =
      widget.trailProgress ?? TrailProgressStore();

  /// Cursos (I09): o embutido mais os instalados (I04), carregados uma vez;
  /// `[]` sem provedor e sem instalado (até o I10).
  late Future<List<LoadedCourse>> _courses = _loadCourses();
  late final CourseStore _coursesStore = widget.courseStore ?? CourseStore();
  late final CourseProgressStore _courseProgress =
      widget.courseProgress ?? CourseProgressStore();

  /// I12: a pasta aberta como rascunho (some ao fechar o app). `null` sem
  /// rascunho. O progresso é o do controlador (só memória).
  CourseDraftController? _draft;

  /// Entrada MIDI do fluxo de cursos (só ele usa). O carimbo sai do relógio
  /// do motor de som em uso, como na `ScoreHomePage`: o tempo real compara
  /// a tecla com o relógio do motor, e com o cronômetro do app (outra
  /// origem) toda nota caía fora da janela — o exercício de ritmo não
  /// acertava nenhuma. Sem motor ainda, o cronômetro.
  final Stopwatch _courseClock = Stopwatch()..start();
  late final MidiInputService _courseMidi = FlutterMidiInputService(
    nowSeconds: () =>
        _courseCurrentEngine?.nowSeconds ??
        _courseClock.elapsedMicroseconds / 1e6,
  );

  /// O último motor entregue por [_ensureCourseEngine] (o que a lição ou o
  /// exercício aberto está usando).
  SoundEngine? _courseCurrentEngine;

  /// Motores de som do fluxo de cursos, um por saída (como a `ScoreHomePage`,
  /// M03): o sintetizador do app (memoizado; `.sf2` carregado uma vez) e a
  /// saída para o teclado MIDI (recriada se o teclado conectado mudar).
  /// Descartados com a biblioteca.
  SoundEngine? _courseEngine;
  Future<SoundEngine?>? _courseEngineOpening;
  MidiOutSoundEngine? _courseMidiOutEngine;
  String? _courseMidiOutDeviceId;

  /// O motor da saída escolhida nas configurações gerais: com "teclado MIDI"
  /// e um teclado conectado, o som sai nele; senão, no sintetizador do app.
  Future<SoundEngine?> _ensureCourseEngine() async {
    final engine = await _openCourseEngine();
    _courseCurrentEngine = engine;
    return engine;
  }

  Future<SoundEngine?> _openCourseEngine() async {
    await _settingsLoaded;
    final device = _midi.connected.value;
    if (_settings.output == SoundOutput.midiKeyboard && device != null) {
      final existing = _courseMidiOutEngine;
      if (existing != null && _courseMidiOutDeviceId == device.id) {
        existing.useScoreInstruments = _settings.useScoreInstruments;
        return existing;
      }
      unawaited(existing?.dispose());
      _courseMidiOutDeviceId = device.id;
      return _courseMidiOutEngine = MidiOutSoundEngine(
        sender: FlutterMidiSender(),
        deviceId: device.id,
        useScoreInstruments: _settings.useScoreInstruments,
      );
    }
    final existing = _courseEngine;
    if (existing != null) return existing;
    return _courseEngineOpening ??= openAppSoundEngine().then((engine) {
      _courseEngineOpening = null;
      if (engine != null) _courseEngine = engine;
      return engine;
    });
  }

  Future<List<LoadedCourse>> _loadCourses() async {
    List<LoadedCourse> builtin = const [];
    final load = widget.loadCourses;
    if (load != null) {
      try {
        builtin = await load();
      } on Object {
        builtin = const [];
      }
    }
    try {
      await _coursesStore.load();
      final all = [...builtin, ...await _coursesStore.openAll()];
      // O progresso guardado vale ao abrir (a lista mostra "X de Y").
      for (final course in all) {
        await _courseProgress.ensureLoaded(course.id);
      }
      return all;
    } on Object {
      return builtin;
    }
  }

  /// A lista de cursos mudou (instalou, removeu): recarrega sem mexer no
  /// resto.
  void _refreshCourses() {
    final courses = _loadCourses();
    setState(() {
      _courses = courses;
    });
  }

  CourseScreenDeps _courseDeps() => CourseScreenDeps(
    settings: _settings,
    deviceManager: _midi,
    midiInput: _courseMidi,
    progress: _courseProgress,
    ensureEngine: _ensureCourseEngine,
  );

  void _openCourses(List<LoadedCourse> courses) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _LiveCoursesScreen(
          initial: courses,
          libraries: _libraries,
          courses: _coursesStore,
          progress: _courseProgress,
          deps: _courseDeps(),
          pickPackage: widget.pickLibraryFile,
          onLibraryInstalled: _reloadCatalog,
          draftController: _draft,
        ),
      ),
    );
  }

  /// I12: abre o rascunho (a tela com faixa + Recarregar). Com [path] (o
  /// `just curso`), sem pedir a pasta; sem ele, pede ao usuário.
  Future<void> _openDraft({String? path}) async {
    if (path != null) {
      final controller = CourseDraftController(
        loadFiles: () => openDraftFolder(path),
      );
      _draft?.dispose();
      _draft = controller;
      await controller.reload();
      if (!mounted) return;
      _openDraftScreen(controller);
      return;
    }
    final picked = await pickDraftCourseFiles();
    if (picked == null || !mounted) return;
    // `.zip` sem envelope (Web sem a API): Recarregar pede o arquivo de
    // novo; pasta/handle: relê sem pedir (o próprio `CourseFiles` é vivo).
    var current = picked;
    final controller = CourseDraftController(
      loadFiles: () async {
        if (current is ZipCourseFiles) {
          final again = await pickDraftCourseFiles();
          if (again != null) current = again;
        }
        return current;
      },
    );
    _draft?.dispose();
    _draft = controller;
    await controller.reload();
    if (!mounted) return;
    _openDraftScreen(controller);
  }

  void _openDraftScreen(CourseDraftController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            CourseDraftScreen(controller: controller, deps: _courseDeps()),
      ),
    );
  }

  SortState _sort = const SortState();
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScroll = ScrollController();

  /// O histórico já foi lido: antes disso não se sabe se é o primeiro uso, e
  /// o cartão de começo não pode piscar para quem já estudou (U16).
  bool _progressLoaded = false;
  bool _opening = false;

  /// Há pastilhas de ordenação fora da tela, à direita (o esmaecido na borda
  /// avisa; some ao rolar até o fim — U14).
  bool _moreChips = true;

  @override
  void initState() {
    super.initState();
    _followDevice();
    unawaited(_loadProgress());
    unawaited(_settingsLoaded);
    final initial = widget.initialDraftPath;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openDraft(path: initial));
      });
    }
  }

  @override
  void dispose() {
    _listScroll.dispose();
    _searchController.dispose();
    _midi.dispose();
    _courseMidi.dispose();
    unawaited(_courseEngine?.dispose());
    unawaited(_courseMidiOutEngine?.dispose());
    _draft?.dispose();
    if (widget.progress == null) _progress.dispose();
    if (widget.trailProgress == null) _trail.dispose();
    if (widget.courseProgress == null) _courseProgress.dispose();
    if (widget.appSettings == null) _settings.dispose();
    super.dispose();
  }

  /// A biblioteca segue a posição do celular ([kFollowDeviceOrientations]);
  /// a partitura do hino trava em paisagem e aqui solta de novo quando
  /// fecha. No desktop isto não vale nada.
  void _followDevice() {
    unawaited(SystemChrome.setPreferredOrientations(kFollowDeviceOrientations));
    // A biblioteca mostra a barra de status (a partitura a esconde, U10).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  /// O catálogo da biblioteca em uso. Sem nenhuma instalada: vazio
  /// ([PieceCatalog.none], que não é erro). Erro ao abrir o pacote sai como
  /// exceção.
  Future<PieceCatalog> _loadCatalog() async {
    final custom = widget.loadCatalog;
    if (custom != null) return custom();
    await _libraries.load();
    _shownLibrary = _librarySignature();
    final id = _libraries.activeId;
    if (id != null) {
      final package = await _libraries.open(id);
      if (package != null) return PieceCatalog.fromPackage(package);
    }
    return const PieceCatalog.none();
  }

  /// Escolhe um `.zywny` (biblioteca ou curso, I04), instala e, se deu
  /// certo, recarrega o que mudou (a biblioteca nova vira a em uso; o curso
  /// novo entra na lista de cursos).
  Future<void> _installLibrary() async {
    final installed = await installPackageFromFile(
      context,
      _libraries,
      _coursesStore,
      pick: widget.pickLibraryFile,
    );
    if (installed == null || !mounted) return;
    if (installed is InstalledLibrary) _reloadCatalog();
    _refreshCourses();
  }

  /// Lê o progresso e a trilha da biblioteca do catálogo (e só ela).
  Future<void> _loadProgress() async {
    try {
      final catalog = await _catalog;
      // Uma ordem que a biblioteca nova não tem (o número, nos clássicos)
      // cai na padrão dela.
      if (!catalog.numbered && _sort.key == SortKey.number) {
        _sort = const SortState(key: SortKey.title);
      }
      final id = catalog.libraryId;
      if (id != null) {
        await _progress.load(id);
        await _trail.load([for (final p in catalog.pieces) p.id], id);
      }
    } on Object {
      // Catálogo com erro: a tela já mostra o erro.
    }
    if (mounted) setState(() => _progressLoaded = true);
  }

  Future<void> _open(Piece piece) async {
    if (_opening) return;
    _opening = true;
    try {
      final catalog = await _catalog;
      final loadScore = widget.loadScore ?? catalog.loadScore;
      final scoreXml = await loadScore(piece);
      final pieceSettings = await _pieceSettings.load(
        piece.libraryId,
        piece.id,
      );
      await _settingsLoaded;
      if (!mounted) return;
      unawaited(_progress.markOpened(piece.id));
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => widget.scoreBuilder(
            context,
            OpenedPiece(
              piece: piece,
              scoreXml: scoreXml,
              midiDeviceManager: _midi,
              onPracticeScore: (score) =>
                  unawaited(_progress.recordScore(piece.id, score)),
              appSettings: _settings,
              pieceSettings: pieceSettings,
              onPieceSettingsChanged: (changed) => unawaited(
                _pieceSettings.save(piece.libraryId, piece.id, changed),
              ),
              trailProgress: _trail,
              term: catalog.term,
              numbered: catalog.numbered,
            ),
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não deu para abrir "${piece.title}": $e')),
      );
    } finally {
      _opening = false;
      if (mounted) _followDevice();
    }
  }

  /// Som, teclado MIDI e cores — o que vale para todos os hinos. (O que é
  /// de um hino só é mexido com ele aberto.)
  Future<void> _openSettings() async {
    await _libraries.load();
    _shownLibrary ??= _librarySignature();
    final term = await _catalog.then(
      (c) => c.term,
      onError: (Object _) => LibraryTerm.hymn,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LibraryTermScope(
          term: term,
          child: GeneralSettingsScreen(
            settings: _settings,
            midiDeviceManager: _midi,
            libraryStore: _libraries,
            pickLibraryFile: widget.pickLibraryFile,
            courseStore: _coursesStore,
            onOpenDraft: draftPickerAvailable
                ? () {
                    Navigator.of(context).pop();
                    unawaited(_openDraft());
                  }
                : null,
          ),
        ),
      ),
    );
    // Ao fechar o painel, a lista acompanha a biblioteca que ficou em uso
    // (trocada, substituída, instalada ou removida).
    if (mounted && _shownLibrary != _librarySignature()) _reloadCatalog();
  }

  /// Qual biblioteca (e versão) a lista mostra: muda quando a em uso troca,
  /// é substituída ou some.
  String _librarySignature() =>
      '${_libraries.activeId}/${_libraries.active?.version}';
  String? _shownLibrary;

  void _reloadCatalog() {
    setState(() {
      _progressLoaded = false;
      _catalog = _loadCatalog();
    });
    unawaited(_loadProgress());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLibraryCardBg,
      // Fundo claro: ícones escuros na barra de status.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return SizedBox.expand(
      child: SafeArea(
        bottom: false,
        child: Center(
          // Numa janela larga (desktop) a lista não se esparrama: fica na
          // medida de leitura de um celular deitado.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FutureBuilder<PieceCatalog>(
                future: _catalog,
                builder: (context, snapshot) => ListenableBuilder(
                  listenable: Listenable.merge([_progress, _trail]),
                  builder: (context, _) => _content(snapshot),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AsyncSnapshot<PieceCatalog> snapshot) {
    final catalog = snapshot.data;
    final catalogError = snapshot.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(catalog),
        const SizedBox(height: 14),
        Expanded(
          child: FutureBuilder<List<LoadedCourse>>(
            future: _courses,
            builder: (context, coursesSnapshot) {
              final courses = coursesSnapshot.data ?? const <LoadedCourse>[];
              if (catalog != null && !catalog.hasLibrary) {
                return _noLibraryCard(courses);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (courses.isNotEmpty) ...[
                    _coursesRow(courses),
                    const SizedBox(height: 14),
                  ],
                  if (catalog == null)
                    Expanded(
                      child: Center(
                        child: catalogError
                            ? const Text(
                                'Não consegui abrir a biblioteca.\n'
                                'Instale-a de novo pelas configurações.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: kInkCaption),
                              )
                            : const CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _searchField(catalog.numbered),
                    const SizedBox(height: 14),
                    if (_continuing(catalog) case final piece?) ...[
                      _continueCard(piece, catalog.term),
                      const SizedBox(height: 14),
                    ] else if (_progressLoaded) ...[
                      // Primeiro uso: o mesmo lugar do "Continuar" diz por onde começar.
                      _startCard(catalog.term),
                      const SizedBox(height: 14),
                    ],
                    _sortChips(catalog.numbered),
                    const SizedBox(height: 4),
                    Expanded(child: _list(catalog)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Linha compacta "Cursos" entre o cabeçalho e a busca (D-LIC-ENTRADA):
  /// o curso em andamento (linha "Cursos · título · X de Y").
  Widget _coursesRow(List<LoadedCourse> courses) {
    final first = courses.first;
    final counts = _courseProgress[first.id].lessonCounts(first.course);
    return _CoursesRowCard(
      title: courses.length == 1
          ? first.course.title
          : '${courses.length} cursos',
      subtitle:
          'Cursos · ${counts.done} de ${counts.total} '
          '${counts.total == 1 ? 'lição' : 'lições'}',
      onTap: () => _openCourses(courses),
    );
  }

  /// Sem nenhuma biblioteca (primeiro uso, ou depois de remover a última):
  /// o cartão do curso inicial (I09, D-LIC-ENTRADA) acima do de instalar.
  /// Nenhuma palavra sobre onde baixar (D-BIB-DIST).
  Widget _noLibraryCard(List<LoadedCourse> courses) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (courses.isNotEmpty) ...[
              _InitialCourseCard(
                onStart: () {
                  final first = courses.first;
                  final progress = _courseProgress[first.id];
                  final next =
                      [
                        for (final lesson in first.course.lessons)
                          if (!progress.lessonDone(lesson)) lesson,
                      ].firstOrNull ??
                      first.course.lessons.first;
                  openLessonScreen(context, first, next, deps: _courseDeps());
                },
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderSoft),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Instale uma biblioteca de músicas',
                    textAlign: TextAlign.center,
                    style: serifDisplay(fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'O zywny não traz músicas. Elas chegam em bibliotecas: '
                    'arquivos .zywny que você abre aqui. Uma delas fica em uso '
                    'por vez, e você troca nas configurações.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: kInkCaption,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => unawaited(_installLibrary()),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Abrir arquivo…'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Piece? _continuing(PieceCatalog catalog) {
    final id = _progress.lastOpenedId;
    if (id == null) return null;
    for (final h in catalog.pieces) {
      if (h.id == id) return h;
    }
    return null;
  }

  Widget _header(PieceCatalog? catalog) {
    final title = switch (catalog) {
      final c? when c.hasLibrary => c.libraryName,
      _ => 'Músicas',
    };
    final count = catalog == null || !catalog.hasLibrary
        ? ''
        : catalog.term.count(catalog.pieces.length);
    return Row(
      children: [
        // Nome e contagem numa linha só: um nome comprido de biblioteca
        // corta a contagem primeiro, depois a si mesmo — nunca estoura.
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: serifDisplay(fontSize: 30)),
                if (count.isNotEmpty)
                  TextSpan(
                    text: '  $count',
                    style: const TextStyle(fontSize: 13, color: kInkCaption),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Configurações gerais',
          onPressed: () => unawaited(_openSettings()),
          color: kIconQuiet,
          icon: const Icon(Icons.settings_outlined),
        ),
        // Engrenagem e teclado juntos, no canto.
        MidiStatusPill(deviceManager: _midi),
      ],
    );
  }

  Widget _searchField(bool numbered) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: numbered
              ? 'Buscar número, título ou autor'
              : 'Buscar título ou autor',
          hintStyle: const TextStyle(color: kInkCaption),
          prefixIcon: const Icon(Icons.search, color: kInkCaption, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar a busca',
                  onPressed: _clearSearch,
                  iconSize: 18,
                  color: kInkCaption,
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: kSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: border(kBorder),
          enabledBorder: border(kBorder),
          focusedBorder: border(kAccent),
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Widget _continueCard(Piece piece, LibraryTerm term) {
    final progress = _progress[piece.id];
    final trail = _trail[piece.id];
    final started = trail.total > 0;
    // A etapa em que parou, numa linha própria; o resto, menor, embaixo.
    final resume = trail.resume;
    final stage = resume == null ? null : trailResumeText(resume);
    final details = [
      if (piece.number != null)
        '${term.singularCapitalized} ${piece.number}'
      else
        piece.composer,
      if (progress?.lastOpened case final at?) whenStudied(at, DateTime.now()),
      if (progress?.bestScore case final score?) 'melhor $score%',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CONTINUAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        color: kAccent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    if (stage != null)
                      Text(
                        stage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: kInk),
                      ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kInkCaption),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: 'Continuar estudo',
                child: Material(
                  color: kAccent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => unawaited(_open(piece)),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // O progresso do hino na base do cartão.
          if (started) ...[
            const SizedBox(height: 10),
            TrailProgressBar(
              done: trail.finalApproved ? trail.total : trail.done,
              skipped: trail.finalApproved ? 0 : trail.skipped,
              total: trail.total,
              height: 5,
            ),
          ],
        ],
      ),
    );
  }

  void _updateMoreChips(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 1;
    if (more == _moreChips) return;
    // As notificações chegam durante o layout: o redesenho espera o quadro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && more != _moreChips) setState(() => _moreChips = more);
    });
  }

  /// Cartão de primeiro uso (U16): no lugar do "Continuar" enquanto nenhum
  /// hino foi aberto. Não bloqueia nada e some sozinho no primeiro hino.
  Widget _startCard(LibraryTerm term) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'COMECE POR AQUI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Escolha ${term.um} ${term.singular} fácil e ligue o teclado ao '
            'celular.',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: _showEasiest,
                child: const Text('Ver os mais fáceis'),
              ),
              ListenableBuilder(
                listenable: _midi.connected,
                builder: (context, _) => _midi.connected.value != null
                    ? const Text(
                        'Teclado conectado ✓',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kGoodColor,
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () =>
                            unawaited(showMidiDevicePicker(context, _midi)),
                        child: const Text('Conectar teclado'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Ver os mais fáceis": ordena por dificuldade (crescente) e volta ao topo.
  void _showEasiest() {
    setState(() => _sort = const SortState(key: SortKey.difficulty));
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
  }

  Widget _sortChips(bool numbered) {
    final keys = [
      for (final k in SortKey.values)
        if (numbered || k != SortKey.number) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ORDENAR POR',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.75,
            color: kInkCaption,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              _updateMoreChips(n.metrics);
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _updateMoreChips(n.metrics);
                return false;
              },
              // Um esmaecido na borda direita enquanto houver pastilhas
              // fora da tela: "Recentes" e "Pontuação" têm pista.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  colors: [
                    Colors.black,
                    Colors.black,
                    _moreChips ? Colors.transparent : Colors.black,
                  ],
                  stops: const [0, 0.88, 1],
                ).createShader(rect),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: keys.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final key = keys[i];
                    return _SortChip(
                      label: '${labelFor(key)}${_sort.arrowFor(key)}',
                      selected: _sort.key == key,
                      onTap: () => setState(() => _sort = _sort.toggled(key)),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(PieceCatalog catalog) {
    final pieces = filterPieces(
      sortedPieces(catalog.pieces, _sort, _progress),
      _query,
    );
    if (pieces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _query.trim().isEmpty
                  ? '${catalog.term.nenhumCapitalized} '
                        '${catalog.term.singular} ${catalog.term.encontrado}'
                  : '${catalog.term.nenhumCapitalized} '
                        '${catalog.term.singular} com “${_query.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kInkCaption),
            ),
            if (_query.isNotEmpty)
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Limpar a busca'),
              ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    return ListView.builder(
      controller: _listScroll,
      // 600 linhas iguais: altura fixa deixa a rolagem e a barra exatas.
      itemExtent: 64,
      itemCount: pieces.length,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemBuilder: (context, i) {
        final piece = pieces[i];
        return _PieceRow(
          piece: piece,
          progress: _progress[piece.id],
          trail: _trail[piece.id],
          now: now,
          match: pieceMatch(piece, _query),
          numbered: catalog.numbered,
          onTap: () => unawaited(_open(piece)),
        );
      },
    );
  }
}

/// A lista de cursos viva (I04): abre o embutido e os instalados; instalar
/// outro atualiza a lista sem sair da tela. O estado mora aqui para a
/// `LibraryScreen` não recarregar o resto junto.
///
/// I12: o rascunho aparece primeiro, com o rótulo "rascunho", e some ao
/// fechar o app (o controlador morre com a `LibraryScreen`).
class _LiveCoursesScreen extends StatefulWidget {
  const _LiveCoursesScreen({
    required this.initial,
    required this.libraries,
    required this.courses,
    required this.progress,
    required this.deps,
    required this.pickPackage,
    required this.onLibraryInstalled,
    this.draftController,
  });

  /// O embutido (não muda enquanto a rota está aberta).
  final List<LoadedCourse> initial;
  final LibraryStore libraries;
  final CourseStore courses;
  final CourseProgressStore progress;
  final CourseScreenDeps deps;
  final Future<Uint8List?> Function() pickPackage;
  final VoidCallback onLibraryInstalled;
  final CourseDraftController? draftController;

  @override
  State<_LiveCoursesScreen> createState() => _LiveCoursesScreenState();
}

class _LiveCoursesScreenState extends State<_LiveCoursesScreen> {
  late Future<List<LoadedCourse>> _courses = _load();

  Future<List<LoadedCourse>> _load() async {
    try {
      await widget.courses.load();
      return [...widget.initial, ...await widget.courses.openAll()];
    } on Object {
      return widget.initial;
    }
  }

  Future<void> _install() async {
    final installed = await installPackageFromFile(
      context,
      widget.libraries,
      widget.courses,
      pick: widget.pickPackage,
    );
    if (installed == null || !mounted) return;
    if (installed is InstalledLibrary) widget.onLibraryInstalled();
    setState(() => _courses = _load());
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draftController;
    if (draft == null) {
      return FutureBuilder<List<LoadedCourse>>(
        future: _courses,
        builder: (context, snapshot) => CoursesScreen(
          courses: snapshot.data ?? widget.initial,
          progress: widget.progress,
          onOpen: (context, course) => openCourseScreen(
            context,
            course,
            progress: widget.progress,
            deps: widget.deps,
          ),
          onInstall: () => unawaited(_install()),
        ),
      );
    }
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final draftLoaded = draft.loaded;
        return FutureBuilder<List<LoadedCourse>>(
          future: _courses,
          builder: (context, snapshot) {
            final rest = snapshot.data ?? widget.initial;
            final courses = draftLoaded == null ? rest : [draftLoaded, ...rest];
            return CoursesScreen(
              courses: courses,
              // O progresso do rascunho é o da sessão; os demais, o disco.
              progress: _DraftAwareProgress(
                draftId: draftLoaded?.id,
                draftProgress: draft.progress,
                fallback: widget.progress,
              ),
              onOpen: (context, course) {
                if (draftLoaded != null && course.id == draftLoaded.id) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => CourseDraftScreen(
                        controller: draft,
                        deps: widget.deps,
                      ),
                    ),
                  );
                  return;
                }
                openCourseScreen(
                  context,
                  course,
                  progress: widget.progress,
                  deps: widget.deps,
                );
              },
              onInstall: () => unawaited(_install()),
            );
          },
        );
      },
    );
  }
}

/// O progresso da lista com rascunho: o id do rascunho sai da sessão, o
/// resto do disco (I12).
class _DraftAwareProgress extends CourseProgressStore {
  _DraftAwareProgress({
    required this.draftId,
    required this.draftProgress,
    required this.fallback,
  });

  final String? draftId;
  final MemoryCourseProgressStore draftProgress;
  final CourseProgressStore fallback;

  @override
  CourseProgress operator [](String courseId) {
    if (courseId == draftId) return draftProgress[courseId];
    return fallback[courseId];
  }
}

/// Linha "Cursos" da biblioteca: compacta, com o curso em andamento.
class _CoursesRowCard extends StatelessWidget {
  const _CoursesRowCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.school_outlined, color: kAccentDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: kInkCaption),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kInkCaption),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão do curso inicial na tela sem biblioteca: "Comece pelo curso
/// inicial" com o botão "Começar", que abre direto na primeira lição aberta.
class _InitialCourseCard extends StatelessWidget {
  const _InitialCourseCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Comece pelo curso inicial',
            textAlign: TextAlign.center,
            style: serifDisplay(fontSize: 22),
          ),
          const SizedBox(height: 10),
          const Text(
            'Aprenda a ler partitura do zero, no seu teclado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: kInkCaption, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Começar'),
          ),
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.progress,
    required this.trail,
    required this.now,
    required this.onTap,
    this.numbered = true,
    this.match,
  });

  /// A biblioteca é numerada: a coluna do número existe. Sem ela (B07) o
  /// subtítulo mostra compositor e número de catálogo.
  final bool numbered;

  /// Onde a busca casou neste hino (U14); `null` sem busca.
  final PieceMatch? match;

  final Piece piece;
  final PieceProgress? progress;

  /// Progresso da trilha (resumo pronto do JSON, sem plano — J09). Sem nada
  /// iniciado (`total == 0`), a linha fica como hoje.
  final TrailProgress trail;
  final DateTime now;
  final VoidCallback onTap;

  /// O começo da segunda linha: a armadura ("2 sustenidos"). A autoria só
  /// aparece quando a busca casou nela (letrista, compositor ou título
  /// original), para mostrar por que o hino entrou no resultado.
  TextSpan _lead() {
    const style = TextStyle(fontSize: 13, color: kInkCaption);
    final m = match;
    if (m != null && m.title.isEmpty) {
      final lyricist = piece.lyricist;
      if (m.composer.isNotEmpty) {
        return _highlighted(piece.composer, m.composer, style);
      }
      if (lyricist != null && m.lyricist.isNotEmpty) {
        return TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'letra: '),
            _highlighted(lyricist, m.lyricist, style),
          ],
        );
      }
      final original = piece.originalTitle;
      if (original != null && m.originalTitle.isNotEmpty) {
        return TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'original: '),
            _highlighted(original, m.originalTitle, style),
          ],
        );
      }
    }
    if (!numbered) {
      // Sem número, a linha diz quem compôs e o catálogo (Op. 100 nº 2).
      return TextSpan(
        text: [
          piece.composer,
          if (piece.originalTitle case final o? when o.isNotEmpty) o,
        ].join(' · '),
        style: style,
      );
    }
    return TextSpan(
      text: switch (piece.fifths) {
        final f? => keySignatureLabel(f),
        null => '',
      },
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = progress?.bestScore;
    final started = trail.total > 0;
    // O que vem depois da armadura (ou da autoria que casou na busca), sem
    // reticências: é o começo quem cede.
    final lead = _lead();
    final parts = [
      // A armadura, que nas numeradas abre a linha.
      if (!numbered)
        if (piece.fifths case final f?) keySignatureLabel(f),
      if (piece.level case final level?) 'nível $level de 5',
      if (progress?.lastOpened case final at?) whenStudied(at, now),
      if (score != null) 'melhor $score%',
    ];
    final rest = lead.toPlainText().isEmpty
        ? parts.join(' · ')
        : parts.map((part) => ' · $part').join();
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorderSoft)),
        ),
        child: Row(
          children: [
            // O número do hinário, na coluna da esquerda: é por ele que se
            // acha um hino. Algarismos de largura fixa para alinhar. Sem
            // numeração (clássicos), a coluna não existe.
            if (numbered) ...[
              SizedBox(
                width: 38,
                child: Text(
                  piece.number == null ? '' : '${piece.number}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kInkCaption,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else
              const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    _highlighted(
                      piece.title,
                      match?.title ?? const [],
                      const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  _SubtitleLine(lead: lead, rest: rest),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Só quem começou a trilha tem progresso à direita; sem ela, a
            // coluna fica vazia (nada de "—" em 600 linhas).
            if (started) _TrailCell(trail: trail),
          ],
        ),
      ),
    );
  }
}

/// [text] com os trechos [ranges] em negrito e na cor de destaque.
TextSpan _highlighted(
  String text,
  List<TextSpanRange> ranges,
  TextStyle style,
) {
  if (ranges.isEmpty) return TextSpan(text: text, style: style);
  final bold = style.copyWith(fontWeight: FontWeight.w800, color: kAccentDark);
  final spans = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    final start = r.start.clamp(0, text.length);
    final end = r.end.clamp(start, text.length);
    if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
    if (end > start) {
      spans.add(TextSpan(text: text.substring(start, end), style: bold));
    }
    at = end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: spans);
}

/// Segunda linha da lista: o começo (armadura, ou a autoria que casou na
/// busca) cede (reticências) para que "nível", "quando" e "melhor" apareçam
/// inteiros.
class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.lead, required this.rest});

  /// A armadura (ou o campo que casou na busca), já com os negritos.
  final TextSpan lead;
  final String rest;

  static const _style = TextStyle(fontSize: 13, color: kInkCaption);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: rest, style: _style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final leadMax = (box.maxWidth - painter.width).clamp(0.0, box.maxWidth);
        painter.dispose();
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: leadMax),
              child: Text.rich(
                lead,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (rest.isNotEmpty)
              Flexible(
                child: Text(
                  rest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A coluna da direita da linha: a barra do progresso da trilha e, embaixo,
/// "13/75" (e as puladas). Concluída: a barra cheia e o ✓.
class _TrailCell extends StatelessWidget {
  const _TrailCell({required this.trail});

  final TrailProgress trail;

  @override
  Widget build(BuildContext context) {
    final concluded = trail.finalApproved;
    return SizedBox(
      width: 84,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrailProgressBar(
                done: concluded ? trail.total : trail.done,
                skipped: concluded ? 0 : trail.skipped,
                total: trail.total,
                width: 48,
              ),
              if (concluded)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Trilha concluída',
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: kGoodColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${trail.done}/${trail.total}'
              '${trail.skipped > 0 ? ' · ${trail.skipped} pul.' : ''}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                color: kInkCaption,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kInk : kSurface,
      shape: StadiumBorder(side: BorderSide(color: selected ? kInk : kBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : kInk,
            ),
          ),
        ),
      ),
    );
  }
}
