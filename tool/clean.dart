import 'dart:io';

void main(List<String> args) => clean();

void clean() {
  cleanupDir("build");
  cleanupDir(".dart_tool");
}

void cleanupDir(String path) {
  final directory = Directory(path);
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}
