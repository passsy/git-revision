import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) => reformat();

Future<void> reformat() async {
  final Process p =
      await Process.start('dartfmt', ['--set-exit-if-changed', '--fix', '-l 120', '-w', 'bin', 'lib', 'test', 'tool'])
          .then((process) {
    stdout.writeln('Reformatting project with dartfmt');

    final out = process.stdout
        .map((it) => String.fromCharCodes(it))
        .where((it) => !it.contains("Unchanged"))
        .map((it) => it.replaceFirst('Formatting directory ', ''))
        .map((it) => it.codeUnits);

    stdout.addStream(out);
    stderr.addStream(process.stderr);

    return process;
  });

  final code = await p.exitCode;
  if (code != 0) {
    exit(code);
  }
}
