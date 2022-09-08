import 'dart:io';

import 'package:dart_compiler_prototype/dart_compiler_prototype.dart'
    as dart_compiler_prototype;
import 'package:path/path.dart' as path;

import 'project.dart';
import 'project_creator.dart';

const kMainDart = 'main.dart';
const dartBinPath = '/Users/moez/projects/yaama/flutter/bin/dart';
const dartPath = '/Users/moez/projects/yaama/flutter';

Future<void> main(List<String> arguments) async {
  const sampleCode = '''
  void main() {
    print("MOEZ !!!");
  }
  ''';
  await _buildProjectTemplates();
  final files = {kMainDart: sampleCode};
  final _projectTemplates = ProjectTemplates.projectTemplates;
  print('flutter path : $dartPath');

  final temp = await Directory.systemTemp.createTemp('papCompiler');
  await copyPath(_projectTemplates.dartPath, temp.path);
  await Directory(path.join(temp.path, 'lib')).create(recursive: true);

  final arguments = <String>[
    'compile',
    'js',
    '--suppress-hints',
    '--terse',
    '--packages=${path.join('.dart_tool', 'package_config.json')}',
    '--sound-null-safety',
    '--enable-asserts',
    '-o',
    '$kMainDart.js',
    path.join('lib', kMainDart),
  ];

  files.forEach((filename, content) async {
    await File(path.join(temp.path, 'lib', filename)).writeAsString(content);
  });

  final mainJs = File(path.join(temp.path, '$kMainDart.js'));

  final result =
      await Process.run(dartBinPath, arguments, workingDirectory: temp.path);

  print('its done !');
  print('result : ${result.toString()}');
  print('mainJs : ${await mainJs.readAsString()}');
}

Future<void> _buildProjectTemplates() async {
  final templatesPath = path.join(Directory.current.path, 'project_templates');
  final templatesDirectory = Directory(templatesPath);
  if (await templatesDirectory.exists()) {
    print('Removing ${templatesDirectory.path}');
    await templatesDirectory.delete(recursive: true);
  }

  final projectCreator = ProjectCreator(
    templatesPath,
    dartSdkPath: dartPath,
    flutterToolPath: '$dartPath/bin/flutter',
    dartLanguageVersion: '2.12.0',
    dependenciesFile: _pubDependenciesFile(channel: 'stable'),
  );
  await projectCreator.buildDartProjectTemplate(oldChannel: false);
  await projectCreator.buildFlutterProjectTemplate(
    firebaseStyle: FirebaseStyle.none,
    devMode: false,
    oldChannel: false,
  );
  await projectCreator.buildFlutterProjectTemplate(
    firebaseStyle: FirebaseStyle.flutterFire,
    devMode: false,
    oldChannel: false,
  );
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Symlinks are supported.
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
///
/// Returns a future that completes when complete.
Future<void> copyPath(String from, String to) async {
  if (_doNothing(from, to)) {
    return;
  }
  await Directory(to).create(recursive: true);
  await for (final file in Directory(from).list(recursive: true)) {
    final copyTo = path.join(to, path.relative(file.path, from: from));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await File(file.path).copy(copyTo);
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

bool _doNothing(String from, String to) {
  if (path.canonicalize(from) == path.canonicalize(to)) {
    return true;
  }
  if (path.isWithin(from, to)) {
    throw ArgumentError('Cannot copy from $from to $to');
  }
  return false;
}

/// Returns the File containing the pub dependencies and their version numbers.
///
/// The file is at `tool/pub_dependencies_{channel}.json`, for the Flutter
/// channels: stable, beta, dev, old.
File _pubDependenciesFile({required String channel}) {
  final versionsFileName = 'pub_dependencies_$channel.json';
  return File(path.join(Directory.current.path, 'tool', versionsFileName));
}
