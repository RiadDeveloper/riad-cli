import 'dart:io' show Process, ProcessException, systemEncoding;

import 'package:get_it/get_it.dart';
import 'package:Riad_cli/src/services/file_service.dart';
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/services/lib_service.dart';
import 'package:Riad_cli/src/utils/constants.dart';
import 'package:Riad_cli/src/version.dart';

class ProcessRunner {
  final _fs = GetIt.I<FileService>();
  final _lgr = GetIt.I<Logger>();
  final _libService = GetIt.I<LibService>();

  Future<void> runExecutable(String exe, List<String> args) async {
    final Process process;
    final ai2ProvidedDeps = await _libService.providedDependencies(null);
    try {
      process = await Process.start(exe, args, environment: {
        // These variables are used by the annotation processor
        'Riad_PROJECT_ROOT': _fs.cwd,
        'Riad_ANNOTATIONS_JAR': ai2ProvidedDeps
            .singleWhere((el) =>
                el.coordinate ==
                'io.github.shreyashsaitwal.Riad:annotations:$ai2AnnotationVersion')
            .classesJar,
        'Riad_RUNTIME_JAR': ai2ProvidedDeps
            .singleWhere((el) =>
                el.coordinate ==
                'io.github.shreyashsaitwal.Riad:runtime:$ai2RuntimeVersion')
            .classesJar,
        'Riad_VERSION': packageVersion,
      });
    } catch (e) {
      if (e.toString().contains('The system cannot find the file specified')) {
        _lgr.err(
            'Could not run `$exe`. Make sure it is installed and in PATH.');
      }
      rethrow;
    }

    process
      ..stdout.transform(systemEncoding.decoder).listen((chunk) {
        _lgr.parseAndLog(chunk);
      })
      ..stderr.transform(systemEncoding.decoder).listen((chunk) {
        _lgr.parseAndLog(chunk);
      });

    if (await process.exitCode != 0) {
      throw ProcessException(exe, args);
    }
  }
}
