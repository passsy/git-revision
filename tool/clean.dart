import 'dart:async';
import 'dart:io';

Future<Null> main(List<String> args) => clean();

Future clean() async {
  final out = Directory("out");
  if (out.existsSync()) out.deleteSync(recursive: true);

  final dart_tool = Directory(".dart_tool");
  if (dart_tool.existsSync()) dart_tool.deleteSync(recursive: true);
}
