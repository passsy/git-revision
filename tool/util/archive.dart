import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// Creates an [ArchiveFile] with the given [path] and [data].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile fileFromBytes(String path, List<int> data, {bool executable = false}) =>
    ArchiveFile(path, data.length, data)
      ..mode = executable ? 495 : 428
      ..lastModTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Creates a UTF-8-encoded [ArchiveFile] with the given [path] and [contents].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile fileFromString(String path, String contents, {bool executable = false}) =>
    fileFromBytes(path, utf8.encode(contents), executable: executable);

/// Creates an [ArchiveFile] at the archive path [target] from the local file at
/// [source].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile file(String target, String source, {bool executable = false}) =>
    fileFromBytes(target, File(source).readAsBytesSync(), executable: executable);
