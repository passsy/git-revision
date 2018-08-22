// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import 'utils.dart';

Future main(List<String> args) async {
  // Ensure that the `build/` directory exists.
  await Directory('build').create(recursive: true);

  print("Building snapshot");
  Dart.run('bin/git_revision.dart', vmArgs: ['--snapshot=build/git_revision.dart.snapshot']);
  await _package();
}

/// Whether we're using a 64-bit Dart SDK.
bool get _is64Bit => Platform.version.contains("x64");

Future _package() async {
  var client = http.Client();
  final platforms = ["linux", "macos", "windows"];
  final architectures = ["ia32", "x64"];
  final combinations = platforms.expand((os) => architectures.map((arch) => [os, arch]));

  final Version dartVersion = Version.parse(Platform.version.split(" ").first);
  String channel = dartVersion.isPreRelease ? "dev" : "stable";
  await Future.wait(
      combinations.map((config) => _buildPackage(client, config[0], config[1], dartVersion.toString(), channel)));
  client.close();
}

enum Architecture { x64, ia32 }

/// Builds a standalone git_revision package for the given [os] and architecture.
///
/// The [client] is used to download the corresponding Dart SDK.
Future _buildPackage(http.Client client, String os, String architecture, String dartVersion, String channel) async {
  // TODO: Compile a single executable that embeds the Dart VM and the snapshot
  // when dart-lang/sdk#27596 is fixed.
  final url = "https://storage.googleapis.com/dart-archive/channels/$channel/"
      "release/$dartVersion/sdk/dartsdk-$os-$architecture-release.zip";
  log("Downloading $url...");
  final response = await client.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw "Failed to download package: ${response.statusCode} ${response.reasonPhrase}.";
  }
  final dartSdk = ZipDecoder().decodeBytes(response.bodyBytes);

  final archive = Archive();

  // add dart executable
  if (os == 'windows') {
    final dart = dartSdk.firstWhere((file) => file.name.endsWith("/bin/dart.exe")).content as List<int>;
    archive.addFile(fileFromBytes("git-revision/src/dart.exe", dart, executable: true));
  } else {
    final dart = dartSdk.firstWhere((file) => file.name.endsWith("/bin/dart")).content as List<int>;
    archive.addFile(fileFromBytes("git-revision/src/dart", dart, executable: true));
  }

  // and the dart license
  archive.addFile(fileFromBytes(
      "git-revision/src/DART_LICENSE", dartSdk.firstWhere((file) => file.name.endsWith("/LICENSE")).content));

  // add snapshot
  // TODO: Use an app snapshots when https://github.com/dart-lang/sdk/issues/28617 is fixed.
  archive.addFile(file("git-revision/src/git_revision.dart.snapshot", "build/git_revision.dart.snapshot"));
  // and the project license
  archive.addFile(file("git-revision/src/LICENSE", "LICENSE"));

  // add executable
  archive.addFile(file("git-revision/git-revision", "package/git-revision.sh", executable: true));
  archive.addFile(file("git-revision/git-revision.bat", "package/git-revision.bat", executable: true));

  final prefix = 'build/git_revision-$version-$os-$architecture';
  if (os == 'windows') {
    final output = "$prefix.zip";
    log("Creating $output...");
    File(output).writeAsBytesSync(ZipEncoder().encode(archive));
  } else {
    final output = "$prefix.tar.gz";
    log("Creating $output...");
    File(output).writeAsBytesSync(GZipEncoder().encode(TarEncoder().encode(archive)));
  }
}
