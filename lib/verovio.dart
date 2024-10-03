import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ffi2;

/// Generate verovio ffi bindings
class Verovio {
  /// Holds the symbol lookup function.
  late ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;
  late ffi.Pointer<ffi.Void> _pointer;

  /// The symbols are looked up in [dynamicLibrary].
  Verovio(ffi.DynamicLibrary dynamicLibrary) {
    _lookup = dynamicLibrary.lookup;
    _pointer = _constructor();
  }

  Verovio.withResourcePath(
      ffi.DynamicLibrary dynamicLibrary, String resourcePath) {
    _lookup = dynamicLibrary.lookup;
    _pointer = _constructorResourcePath(resourcePath.toNativeUtf8());
  }

  late final _constructorPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Void> Function()>>(
          'vrvToolkit_constructor');
  late final _constructor =
      _constructorPtr.asFunction<ffi.Pointer<ffi.Void> Function()>();

  late final _constructorResourcePathPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Void> Function(
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_constructorResourcePath');
  late final _constructorResourcePath = _constructorResourcePathPtr
      .asFunction<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi2.Utf8>)>();

  void dispose() {
    return _destructor(_pointer);
  }

  late final _destructorPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
          'vrvToolkit_destructor');
  late final _destructor =
      _destructorPtr.asFunction<void Function(ffi.Pointer<ffi.Void>)>();

  bool edit(String editorAction) {
    return _edit(_pointer, editorAction.toNativeUtf8()) == 1;
  }

  late final _editPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_edit');
  late final _edit = _editPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String editInfo() {
    return _editInfo(_pointer).toDartString();
  }

  late final _editInfoPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_editInfo');
  late final _editInfo = _editInfoPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  String getAvailableOptions() {
    return _getAvailableOptions(_pointer).toDartString();
  }

  late final _getAvailableOptionsPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getAvailableOptions');
  late final _getAvailableOptions = _getAvailableOptionsPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  String getDefaultOptions() {
    return _getDefaultOptions(_pointer).toDartString();
  }

  late final _getDefaultOptionsPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getDefaultOptions');
  late final _getDefaultOptions = _getDefaultOptionsPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  String getDescriptiveFeatures(String options) {
    return _getDescriptiveFeatures(_pointer, options.toNativeUtf8())
        .toDartString();
  }

  late final _getDescriptiveFeaturesPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getDescriptiveFeatures');
  late final _getDescriptiveFeatures = _getDescriptiveFeaturesPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getElementAttr(String xmlId) {
    return _getElementAttr(_pointer, xmlId.toNativeUtf8()).toDartString();
  }

  late final _getElementAttrPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getElementAttr');
  late final _getElementAttr = _getElementAttrPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getElementsAtTime(int millisec) {
    return _getElementsAtTime(_pointer, millisec).toDartString();
  }

  late final _getElementsAtTimePtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>, ffi.Int)>>('vrvToolkit_getElementsAtTime');
  late final _getElementsAtTime = _getElementsAtTimePtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>, int)>();

  String getExpansionIdsForElement(String xmlId) {
    return _getExpansionIdsForElement(_pointer, xmlId.toNativeUtf8())
        .toDartString();
  }

  late final _getExpansionIdsForElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getExpansionIdsForElement');
  late final _getExpansionIdsForElement =
      _getExpansionIdsForElementPtr.asFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getHumdrum() {
    return _getHumdrum(_pointer).toDartString();
  }

  late final _getHumdrumPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getHumdrum');
  late final _getHumdrum = _getHumdrumPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  bool getHumdrumFile(String filename) {
    return _getHumdrumFile(_pointer, filename.toNativeUtf8()) == 1;
  }

  late final _getHumdrumFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getHumdrumFile');
  late final _getHumdrumFile = _getHumdrumFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getID() {
    return _getID(_pointer).toDartString();
  }

  late final _getIDPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getID');
  late final _getID = _getIDPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  String convertHumdrumToHumdrum(String humdrumData) {
    return _convertHumdrumToHumdrum(_pointer, humdrumData.toNativeUtf8())
        .toDartString();
  }

  late final _convertHumdrumToHumdrumPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_convertHumdrumToHumdrum');
  late final _convertHumdrumToHumdrum = _convertHumdrumToHumdrumPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String convertHumdrumToMIDI(String humdrumData) {
    return _convertHumdrumToMIDI(_pointer, humdrumData.toNativeUtf8())
        .toDartString();
  }

  late final _convertHumdrumToMIDIPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_convertHumdrumToMIDI');
  late final _convertHumdrumToMIDI = _convertHumdrumToMIDIPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String convertMEIToHumdrum(String meiData) {
    return _convertMEIToHumdrum(_pointer, meiData.toNativeUtf8())
        .toDartString();
  }

  late final _convertMEIToHumdrumPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_convertMEIToHumdrum');
  late final _convertMEIToHumdrum = _convertMEIToHumdrumPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getMEI(String options) {
    return _getMEI(_pointer, options.toNativeUtf8()).toDartString();
  }

  late final _getMEIPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getMEI');
  late final _getMEI = _getMEIPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getMIDIValuesForElement(String xmlId) {
    return _getMIDIValuesForElement(_pointer, xmlId.toNativeUtf8())
        .toDartString();
  }

  late final _getMIDIValuesForElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getMIDIValuesForElement');
  late final _getMIDIValuesForElement = _getMIDIValuesForElementPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getNotatedIdForElement(String xmlId) {
    return _getNotatedIdForElement(_pointer, xmlId.toNativeUtf8())
        .toDartString();
  }

  late final _getNotatedIdForElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getNotatedIdForElement');
  late final _getNotatedIdForElement = _getNotatedIdForElementPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getOptions() {
    return _getOptions(_pointer).toDartString();
  }

  late final _getOptionsPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getOptions');
  late final _getOptions = _getOptionsPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  String getOptionUsageString() {
    return _getOptionUsageString(_pointer).toDartString();
  }

  late final _getOptionUsageStringPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getOptionUsageString');
  late final _getOptionUsageString = _getOptionUsageStringPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  int getPageCount() {
    return _getPageCount(_pointer);
  }

  late final _getPageCountPtr =
      _lookup<ffi.NativeFunction<ffi.Int Function(ffi.Pointer<ffi.Void>)>>(
          'vrvToolkit_getPageCount');
  late final _getPageCount =
      _getPageCountPtr.asFunction<int Function(ffi.Pointer<ffi.Void>)>();

  int getPageWithElement(String xmlId) {
    return _getPageWithElement(_pointer, xmlId.toNativeUtf8());
  }

  late final _getPageWithElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getPageWithElement');
  late final _getPageWithElement = _getPageWithElementPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getResourcePath() {
    return _getResourcePath(_pointer).toDartString();
  }

  late final _getResourcePathPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getResourcePath');
  late final _getResourcePath = _getResourcePathPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  int getScale() {
    return _getScale(_pointer);
  }

  late final _getScalePtr =
      _lookup<ffi.NativeFunction<ffi.Int Function(ffi.Pointer<ffi.Void>)>>(
          'vrvToolkit_getScale');
  late final _getScale =
      _getScalePtr.asFunction<int Function(ffi.Pointer<ffi.Void>)>();

  double getTimeForElement(String xmlId) {
    return _getTimeForElement(_pointer, xmlId.toNativeUtf8());
  }

  late final _getTimeForElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Double Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getTimeForElement');
  late final _getTimeForElement = _getTimeForElementPtr.asFunction<
      double Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getTimesForElement(String xmlId) {
    return _getTimesForElement(_pointer, xmlId.toNativeUtf8()).toDartString();
  }

  late final _getTimesForElementPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_getTimesForElement');
  late final _getTimesForElement = _getTimesForElementPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String getVersion() {
    return _getVersion(_pointer).toDartString();
  }

  late final _getVersionPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_getVersion');
  late final _getVersion = _getVersionPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  bool loadData(String data) {
    return _loadData(_pointer, data.toNativeUtf8()) == 1;
  }

  late final _loadDataPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_loadData');
  late final _loadData = _loadDataPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool loadFile(String filename) {
    return _loadFile(_pointer, filename.toNativeUtf8()) == 1;
  }

  late final _loadFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_loadFile');
  late final _loadFile = _loadFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  void redoLayout(String options) {
    return _redoLayout(_pointer, options.toNativeUtf8());
  }

  late final _redoLayoutPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_redoLayout');
  late final _redoLayout = _redoLayoutPtr.asFunction<
      void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  void redoPagePitchPosLayout() {
    return _redoPagePitchPosLayout(_pointer);
  }

  late final _redoPagePitchPosLayoutPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
          'vrvToolkit_redoPagePitchPosLayout');
  late final _redoPagePitchPosLayout = _redoPagePitchPosLayoutPtr
      .asFunction<void Function(ffi.Pointer<ffi.Void>)>();

  String renderData(String data, String options) {
    return _renderData(_pointer, data.toNativeUtf8(), options.toNativeUtf8())
        .toDartString();
  }

  late final _renderDataPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderData');
  late final _renderData = _renderDataPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi2.Utf8>, ffi.Pointer<ffi2.Utf8>)>();

  String renderToExpansionMap() {
    return _renderToExpansionMap(_pointer).toDartString();
  }

  late final _renderToExpansionMapPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_renderToExpansionMap');
  late final _renderToExpansionMap = _renderToExpansionMapPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  bool renderToExpansionMapFile(String filename) {
    return _renderToExpansionMapFile(_pointer, filename.toNativeUtf8()) == 1;
  }

  late final _renderToExpansionMapFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderToExpansionMapFile');
  late final _renderToExpansionMapFile =
      _renderToExpansionMapFilePtr.asFunction<
          int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String renderToMIDI() {
    return _renderToMIDI(_pointer).toDartString();
  }

  late final _renderToMIDIPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_renderToMIDI');
  late final _renderToMIDI = _renderToMIDIPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  bool renderToMIDIFile(String filename) {
    return _renderToMIDIFile(_pointer, filename.toNativeUtf8()) == 1;
  }

  late final _renderToMIDIFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderToMIDIFile');
  late final _renderToMIDIFile = _renderToMIDIFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String renderToPAE() {
    return _renderToPAE(_pointer).toDartString();
  }

  late final _renderToPAEPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(
              ffi.Pointer<ffi.Void>)>>('vrvToolkit_renderToPAE');
  late final _renderToPAE = _renderToPAEPtr
      .asFunction<ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>)>();

  bool renderToPAEFile(String filename) {
    return _renderToPAEFile(_pointer, filename.toNativeUtf8()) == 1;
  }

  late final _renderToPAEFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderToPAEFile');
  late final _renderToPAEFile = _renderToPAEFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String renderToSVG(int pageNumber, bool xmlDeclaration) {
    return _renderToSVG(_pointer, pageNumber, xmlDeclaration ? 1 : 0)
        .toDartString();
  }

  late final _renderToSVGPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Int,
              ffi.Int)>>('vrvToolkit_renderToSVG');
  late final _renderToSVG = _renderToSVGPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>, int, int)>();

  bool renderToSVGFile(String filename, int pageNo) {
    return _renderToSVGFile(_pointer, filename.toNativeUtf8(), pageNo) == 1;
  }

  late final _renderToSVGFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>,
              ffi.Int)>>('vrvToolkit_renderToSVGFile');
  late final _renderToSVGFile = _renderToSVGFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>, int)>();

  String renderToTimemap(String options) {
    return _renderToTimemap(_pointer, options.toNativeUtf8()).toDartString();
  }

  late final _renderToTimemapPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderToTimemap');
  late final _renderToTimemap = _renderToTimemapPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool renderToTimemapFile(String filename, String options) {
    return _renderToTimemapFile(
            _pointer, filename.toNativeUtf8(), options.toNativeUtf8()) ==
        1;
  }

  late final _renderToTimemapFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_renderToTimemapFile');
  late final _renderToTimemapFile = _renderToTimemapFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>,
          ffi.Pointer<ffi2.Utf8>)>();

  void resetOptions() {
    return _resetOptions(_pointer);
  }

  late final _resetOptionsPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
          'vrvToolkit_resetOptions');
  late final _resetOptions =
      _resetOptionsPtr.asFunction<void Function(ffi.Pointer<ffi.Void>)>();

  void resetXmlIdSeed(int seed) {
    return _resetXmlIdSeed(_pointer, seed);
  }

  late final _resetXmlIdSeedPtr = _lookup<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Int)>>(
      'vrvToolkit_resetXmlIdSeed');
  late final _resetXmlIdSeed = _resetXmlIdSeedPtr
      .asFunction<void Function(ffi.Pointer<ffi.Void>, int)>();

  bool saveFile(String filename, String options) {
    return _saveFile(
            _pointer, filename.toNativeUtf8(), options.toNativeUtf8()) ==
        1;
  }

  late final _saveFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_saveFile');
  late final _saveFile = _saveFilePtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>,
          ffi.Pointer<ffi2.Utf8>)>();

  bool select(String selection) {
    return _select(_pointer, selection.toNativeUtf8()) == 1;
  }

  late final _selectPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_select');
  late final _select = _selectPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool setInputFrom(String inputFrom) {
    return _setInputFrom(_pointer, inputFrom.toNativeUtf8()) == 1;
  }

  late final _setInputFromPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_setInputFrom');
  late final _setInputFrom = _setInputFromPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool setOptions(String options) {
    return _setOptions(_pointer, options.toNativeUtf8()) == 1;
  }

  late final _setOptionsPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_setOptions');
  late final _setOptions = _setOptionsPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool setOutputTo(String outputTo) {
    return _setOutputTo(_pointer, outputTo.toNativeUtf8()) == 1;
  }

  late final _setOutputToPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_setOutputTo');
  late final _setOutputTo = _setOutputToPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool setResourcePath(String path) {
    return _setResourcePath(_pointer, path.toNativeUtf8()) == 1;
  }

  late final _setResourcePathPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_setResourcePath');
  late final _setResourcePath = _setResourcePathPtr.asFunction<
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  bool setScale(int scale) {
    return _setScale(_pointer, scale) == 1;
  }

  late final _setScalePtr = _lookup<
          ffi.NativeFunction<ffi.Int Function(ffi.Pointer<ffi.Void>, ffi.Int)>>(
      'vrvToolkit_setScale');
  late final _setScale =
      _setScalePtr.asFunction<int Function(ffi.Pointer<ffi.Void>, int)>();

  String validatePAE(String data) {
    return _validatePAE(_pointer, data.toNativeUtf8()).toDartString();
  }

  late final _validatePAEPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_validatePAE');
  late final _validatePAE = _validatePAEPtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();

  String validatePAEFile(String filename) {
    return _validatePAEFile(_pointer, filename.toNativeUtf8()).toDartString();
  }

  late final _validatePAEFilePtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi2.Utf8> Function(ffi.Pointer<ffi.Void>,
              ffi.Pointer<ffi2.Utf8>)>>('vrvToolkit_validatePAEFile');
  late final _validatePAEFile = _validatePAEFilePtr.asFunction<
      ffi.Pointer<ffi2.Utf8> Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi2.Utf8>)>();
}

/// //////////////////////////////////////////////////////////////////////////
