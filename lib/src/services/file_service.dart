import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/utils/file_extension.dart';

class FileService {
  final String cwd;
  late final Directory RiadHomeDir;

  final _lgr = GetIt.I.get<Logger>();

  FileService(this.cwd) {
    final Directory homeDir;
    final env = Platform.environment;

    if (env.containsKey('Riad_HOME')) {
      homeDir = env['Riad_HOME']!.asDir();
    } else if (env.containsKey('Riad_DATA_DIR')) {
      _lgr.warn('Riad_DATA_DIR env var is deprecated. Use Riad_HOME instead.');
      homeDir = env['Riad_DATA_DIR']!.asDir();
    } else {
      if (Platform.operatingSystem == 'windows') {
        homeDir = p.join(env['UserProfile']!, '.Riad').asDir();
      } else {
        homeDir = p.join(env['HOME']!, '.Riad').asDir();
      }
    }

    if (!homeDir.existsSync() || homeDir.listSync().isEmpty) {
      _lgr.err('Could not find Riad data directory at $homeDir.');
      exit(1);
    }

    RiadHomeDir = homeDir;
  }

  Directory get srcDir => p.join(cwd, 'src').asDir();
  Directory get localDepsDir => p.join(cwd, 'deps').asDir();
  Directory get dotRiadDir => p.join(cwd, '.Riad').asDir();

  Directory get buildDir => p.join(dotRiadDir.path, 'build').asDir(true);
  Directory get buildClassesDir => p.join(buildDir.path, 'classes').asDir(true);
  Directory get buildRawDir => p.join(buildDir.path, 'raw').asDir(true);
  Directory get buildFilesDir => p.join(buildDir.path, 'files').asDir(true);
  Directory get buildKaptDir => p.join(buildDir.path, 'kapt').asDir(true);
  Directory get buildAarsDir =>
      p.join(buildDir.path, 'extracted-aars').asDir(true);

  Directory get libsDir => p.join(RiadHomeDir.path, 'libs').asDir();

  File get configFile {
    if (p.join(cwd, 'Riad.yml').asFile().existsSync()) {
      return p.join(cwd, 'Riad.yml').asFile();
    } else {
      return p.join(cwd, 'Riad.yaml').asFile();
    }
  }

  File get javacArgsFile =>
      p.join(buildFilesDir.path, 'javac.args').asFile(true);
  File get kotlincArgsFile =>
      p.join(buildFilesDir.path, 'kotlinc.args').asFile(true);
}
