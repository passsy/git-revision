import 'dart:async';
import 'dart:io';

Future<Null> main(List<String> args) async {
  await Process.start('dartfmt', ['-l 120', '-w', 'bin', 'lib', 'test', 'tool']).then((process) {
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);
  });
}
