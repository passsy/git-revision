import 'dart:async';
import 'dart:io';
import 'util/process.dart';

Future<Null> main(List<String> args) async {
  await sh("pub run build_runner build --delete-conflicting-outputs");
  final outDir = Directory("out");
  if (!outDir.existsSync()) outDir.createSync();
  await sh("dart --snapshot=out/git-revision bin/git_revision.dart");

  var outFile = File("out/git-revision");
  print("created ${outFile.absolute.path}");
}
