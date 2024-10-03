// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'dart:ffi' show DynamicLibrary;
import 'dart:convert';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:xml/xml.dart';
import "package:system_info2/system_info2.dart";
import 'package:zywny/verovio.dart';
import 'package:zywny/sheet_abstractions.dart';

Future<void> checkInstallation() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory supportDir = await getApplicationSupportDirectory();
  debugPrint('support dir: ${supportDir.absolute.path}');

  String supportPath = supportDir.absolute.path;
  File checkInstallation = File(p.join(supportPath, 'check-installation'));
  if (!checkInstallation.existsSync()) {
    final bytes = await rootBundle.load('assets/assets.zip');

    Directory(supportPath).createSync(recursive: true);

    // Decode the Zip file
    final archive = ZipDecoder().decodeBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

    // Extract the contents of the Zip archive to disk.
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(supportPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(p.join(supportPath, filename)).createSync(recursive: true);
      }
    }

    checkInstallation
      ..createSync(recursive: true)
      ..writeAsStringSync('just-to-check-installation');
  }
}

Future<String> getVerovioLibraryPath() async {
  Directory supportDir = await getApplicationSupportDirectory();
  var libraryPath = p.join(supportDir.path, 'bin', 'libverovio.so');

  if (Platform.isAndroid) {
    debugPrint('is android');
    var processorArch = SysInfo.kernelArchitecture;
    if (ProcessorArchitecture.x86_64 == processorArch) {
      libraryPath =
          p.join(supportDir.path, 'bin', 'android', 'x86_64', 'libverovio.so');
    } else if (ProcessorArchitecture.x86 == processorArch) {
      libraryPath =
          p.join(supportDir.path, 'bin', 'android', 'x86', 'libverovio.so');
    } else if (ProcessorArchitecture.arm64 == processorArch) {
      libraryPath = p.join(
          supportDir.path, 'bin', 'android', 'arm64-v8a', 'libverovio.so');
    }
  }

  return libraryPath;
}

Future<List<String>> createSvgs(Size size) async {
  var watch = Stopwatch();
  watch.reset();
  watch.start();
  // Open the dynamic library
  Directory supportDir = await getApplicationSupportDirectory();

  var libraryPath = await getVerovioLibraryPath();
  var libFile = File(libraryPath);

  if (!libFile.existsSync()) {
    debugPrint('library file not found!');
    throw 'Sem Library';
  }

  final dylib = DynamicLibrary.open(libraryPath);

  final verovio =
      Verovio.withResourcePath(dylib, p.join(supportDir.path, 'data'));
  verovio.setOptions(jsonEncode({
    'footer': 'none',
    'header': 'none',
    'svgViewBox': false,
    'pageWidth': '${(size.width * 10).toInt()}',
    'pageHeight': '${(size.height * 10).toInt()}',
    'adjustPageHeight': true,
    'smuflTextFont': 'none',
    //'svgBoundingBoxes': true,
  }));

  print("preparing verovio: ${watch.elapsedMilliseconds}");
  watch.reset();

  File file =
  File(p.join(supportDir.path, 'music', 'Chopin_Raindrop_Prelude.mxml'));
  verovio.loadData(file.readAsStringSync());

  print("load data: ${watch.elapsedMilliseconds}");
  watch.reset();

  verovio.redoLayout('');

  print("layouting: ${watch.elapsedMilliseconds}");
  watch.reset();

  var timeMap = verovio.renderToTimemap('');


  File timeMapFile = File(
      p.join(supportDir.path, 'music', 'Chopin_-_Raindrop_Prelude.timemap.json'));
  timeMapFile.writeAsStringSync(timeMap);

  print("render timemap: ${watch.elapsedMilliseconds}");
  watch.reset();

  var data = jsonDecode(timeMap);
  var timeLength = data.length;
  var noteMap = NoteMap();
  for (var i = 0; i < timeLength; i++) {
    var hasOn = data[i]['on'];
    if (hasOn != null) {
      var onLength = data[i]['on'].length;
      if (onLength != null) {
        for (var j = 0; j < onLength; j++) {
          String onElement = data[i]['on'][j];
          var noteInfo = verovio.getMIDIValuesForElement(onElement);
          var note = Note.fromJson(onElement, jsonDecode(noteInfo));
          noteMap.addNote(note);
        }
      }
    }
  }

  print("get note info: ${watch.elapsedMilliseconds}");
  watch.reset();

  int totalPages = verovio.getPageCount();
  List<String> svgs = [];

  for (int page = 1; page <= totalPages; page++) {
    var svgGenerated = verovio.renderToSVG(page, true);
    final doc = XmlDocument.parse(svgGenerated);
    var viewBoxDef = '';
    for (final elem in doc.rootElement.descendantElements) {
      if (elem.name.toString() == 'svg' &&
          elem.getAttribute('viewBox') != null) {
        String? viewBoxDefTmp = elem.getAttribute('viewBox');
        if (viewBoxDefTmp != null) {
          viewBoxDef = viewBoxDefTmp;
        }
      }
    }
    doc.rootElement.setAttribute('viewBox', viewBoxDef);

    var rects = doc.findAllElements('rect');
    for(var rect in rects) {

      print('found rect: ${rect.toXmlString()}');

      // for(var attr in rect.attributes) {
      //     print('attr name: ${attr.name}, localName: ${attr.localName}, value: ${attr.value}');
      // }
      var wasModified = false;

      for(var attr in rect.attributes) {
        if (attr.name.toString() == 'fill' && attr.value == 'transparent') {
          print('found rect with fill: ${rect.toXmlString()}');
          attr.value = '#044B94';
          wasModified = true;
        }
      }
      if (wasModified) {
        rect.setAttribute('opacity', '0.3');
        print('new rect: ${rect.toXmlString()}');
      }
    }

    var newXmlString = doc.toXmlString();



    svgs.add(newXmlString);

    File svgFile = File(
        p.join(supportDir.path, 'music', 'Chopin_-_Raindrop_Prelude.$page.svg'));
    svgFile.writeAsStringSync(newXmlString);
  }

  print("render svgs: ${watch.elapsedMilliseconds}");

  return svgs;
}

class ScoreViewer extends StatefulWidget {
  final List<String> svgs;

  const ScoreViewer({super.key, required this.svgs});

  @override
  State<ScoreViewer> createState() => _ScoreViewerState();
}

class _ScoreViewerState extends State<ScoreViewer> {
  int index = 0;

  // Widget build(BuildContext context) {
  @override
  Widget build(BuildContext context) {
    var buttons = <Widget>[];
    if (index < (widget.svgs.length - 1)) {
      buttons.add(IconButton(
          onPressed: () => setState(() => index = index + 1),
          icon: const Icon(Icons.fast_forward)));
    } else {
      buttons.add(IconButton(
        onPressed: () => {},
        icon: const Icon(Icons.stop),
        color: Colors.transparent,
      ));
    }
    buttons.add(Container(height: 100));
    if (index > 0) {
      buttons.add(IconButton(
          onPressed: () => setState(() => index = index - 1),
          icon: const Icon(Icons.fast_rewind)));
    } else {
      buttons.add(IconButton(
        onPressed: () => {},
        icon: const Icon(Icons.stop),
        color: Colors.transparent,
      ));
    }

    return Scaffold(
      body: Row(
        children: <Widget>[
          // This is the main content.
          Expanded(
            child: ScalableImageWidget(
              si: ScalableImage.fromSvgString(widget.svgs[index]),
            ),
          ),

          const VerticalDivider(thickness: 1, width: 1),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buttons,
          ),
        ],
      ),
    );
  }
}

// "on": [
// "d1e116",
// "d1e134"
// ],
// "qstamp": 0,
// "tempo": "52,000000",
// "tstamp": 0
//

// "off": [
// "d1e274",
// "d1e294"
// ],
// "on": [
// "d1e313"
// ],
// "qstamp": 2.25,
// "tstamp": 2596

