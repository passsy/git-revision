import 'dart:async';
import 'dart:io';

Future<Null> main(List<String> args) async {
  Process p =
      await Process.start('dartfmt', ['--set-exit-if-changed', '--fix', '-l 120', '-w', 'bin', 'lib', 'test', 'tool'])
          .then((process) {
    stdout.writeln('Reformatting project with dartfmt');

    var out = process.stdout
        .map((it) => String.fromCharCodes(it))
        .where((it) => !it.contains("Unchanged"))
        .map((it) => it.replaceFirst('Formatting directory ', ''))
        .map((it) => it.codeUnits);

    stdout.addStream(out);
    stderr.addStream(process.stderr);

    return process;
  });

  exit(await p.exitCode);
}
