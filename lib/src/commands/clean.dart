import 'package:args/command_runner.dart';
import 'package:get_it/get_it.dart';
import 'package:interact/interact.dart';
import 'package:path/path.dart' as p;
import 'package:tint/tint.dart';

import 'package:Riad_cli/src/services/file_service.dart';
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/utils/file_extension.dart';

class CleanCommand extends Command<int> {
  final _fs = GetIt.I<FileService>();
  final _lgr = GetIt.I<Logger>();

  @override
  String get description => 'Deletes old build files and caches.';

  @override
  String get name => 'clean';

  @override
  Future<int> run() async {
    if (!await _isRiadProject()) {
      _lgr.err('Not a Riad project.');
      return 1;
    }

    final spinner = Spinner(
        icon: '\n✓ '.green(),
        rightPrompt: (done) => done
            ? '${'Success!'.green()} Deleted build files and caches'
            : 'Cleaning...').interact();
    for (final file in _fs.dotRiadDir.listSync()) {
      await file.delete(recursive: true);
    }

    spinner.done();
    return 0;
  }

  Future<bool> _isRiadProject() async {
    final config = _fs.configFile;
    final androidManifest =
        p.join(_fs.srcDir.path, 'AndroidManifest.xml').asFile();
    return await config.exists() &&
        await _fs.srcDir.exists() &&
        await androidManifest.exists() &&
        await _fs.dotRiadDir.exists();
  }
}
