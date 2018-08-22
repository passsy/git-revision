import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;

import 'util/process.dart';

Future<Null> main(List<String> args) => build();

Future build() async {
  await buildGeneratedSource();

  print("Building snapshot");
  // Ensure that the `build/` directory exists.
  await Directory('build').create(recursive: true);
  var outFile = File("build/git_revision.dart.snapshot");
  await sh("dart --snapshot=${outFile.path} bin/git_revision.dart");
  assert(outFile.existsSync());
  await sh("chmod 755 ${outFile.path}", quiet: true);
  print("\nSUCCESS\n");
  print("snapshot at ${outFile.absolute.path}");
}

Future buildGeneratedSource() async {
  print("Building generated source");
  final content = await File('pubspec.yaml').readAsString();
  final yaml = loadYaml(content) as Map;
  final version = yaml['version'] as String;

  final files = Directory("lib").listSync();
  final sourceFile = files.firstWhere((it) => path.basename(it.path) == 'cli_app.dart');
  final partFile = File(sourceFile.path.replaceAll(".dart", ".g.dart"));

  final source = DartFormatter().format('''
      // GENERATED CODE - DO NOT MODIFY BY HAND

      part of 'cli_app.dart';

      // **************************************************************************
      // BuildConfig
      // **************************************************************************

      const String versionName = '$version';
      ''');

  await partFile.writeAsString(source);

  print("wrote ${partFile.path}");
}
