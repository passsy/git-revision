import 'dart:async';
import 'dart:io';
import 'util/process.dart';

Future<Null> main(List<String> args) async {
  await sh("pub run build_runner clean");
  Directory("out").deleteSync(recursive: true);
  Directory(".dart_tool").deleteSync(recursive: true);
}
