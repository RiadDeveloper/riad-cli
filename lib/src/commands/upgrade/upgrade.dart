import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/command_runner.dart';
import 'package:get_it/get_it.dart';
import 'package:github/github.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as p;

import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/utils/file_extension.dart';
import 'package:Riad_cli/src/services/file_service.dart';
import 'package:Riad_cli/src/version.dart';
import 'package:tint/tint.dart';

class UpgradeCommand extends Command<int> {
  final _fs = GetIt.I<FileService>();
  final _lgr = GetIt.I<Logger>();

  UpgradeCommand() {
    argParser
      ..addFlag('force',
          abbr: 'f',
          help: 'Upgrades Riad even if you\'re using the latest version.')
      ..addOption('access-token',
          abbr: 't',
          help: 'Your GitHub access token. Normally, you don\'t need this.');
  }

  @override
  String get description => 'Upgrades Riad to the latest available version.';

  @override
  String get name => 'upgrade';

  @override
  Future<int> run() async {
    _lgr.info('Checking for new version...');

    final gh = GitHub(
        auth: Authentication.withToken(argResults!['access-token'] as String?));
    final release = await gh.repositories
        .getLatestRelease(RepositorySlug.full('RiadDeveloper/Riad-cli'));

    final latestVersion = release.tagName;
    final force = (argResults!['force'] as bool);

    if (latestVersion == 'v$packageVersion') {
      if (!force) {
        _lgr.info(
            'You\'re already on the latest version of Riad. Use `--force` to upgrade anyway.');
        return 0;
      }
    } else {
      _lgr.info('A newer version is available: $latestVersion');
    }

    final archive =
        release.assets?.firstWhereOrNull((el) => el.name == archiveName());
    if (archive == null || archive.browserDownloadUrl == null) {
      _lgr
        ..err(
            'Could not find release asset ${archiveName()} at ${release.htmlUrl}')
        ..log('This is not supposed to happen. Please report this issue.');
      return 1;
    }

    _lgr.info('Downloading ${archiveName()}...');
    final archiveDist =
        p.join(_fs.RiadHomeDir.path, 'temp', archive.name).asFile();
    try {
      final response = await get(Uri.parse(archive.browserDownloadUrl!));
      if (response.statusCode != 200) {
        _lgr
          ..err('Something went wrong...')
          ..log('GET status code: ${response.statusCode}')
          ..log('GET body:\n${response.body}');
        return 1;
      }

      await archiveDist.create(recursive: true);
      await archiveDist.writeAsBytes(response.bodyBytes);
    } catch (e) {
      _lgr
        ..err('Something went wrong...')
        ..log(e.toString());
      return 1;
    }

    // TODO: We should delete the old files.

    _lgr.info('Extracting ${p.basename(archiveDist.path)}...');

    final inputStream = InputFileStream(archiveDist.path);
    final zipDecoder = ZipDecoder().decodeBuffer(inputStream);
    for (final file in zipDecoder.files) {
      if (file.isFile) {
        final String path;
        if (file.name.endsWith('Riad.exe')) {
          path = p.join(_fs.RiadHomeDir.path, '$name.new');
        } else {
          path = p.join(_fs.RiadHomeDir.path, name);
        }

        final outputStream = OutputFileStream(path);
        file.writeContent(outputStream);
        await outputStream.close();
      }
    }
    await inputStream.close();
    await archiveDist.delete(recursive: true);

    final exePath = Platform.resolvedExecutable;

    // On Windows, we can't replace the executable while it's running. So, we
    // move it to `$Riad_HOME/temp/Riad.{version}.exe` and then rename the new
    // exe, would have been downloaded in the bin directory with name `Riad.new.exe`,
    // to the old name.
    if (Platform.isWindows) {
      final newExe = p.join(p.dirname(exePath), 'Riad.exe.new').asFile();
      if (await newExe.exists()) {
        final tempDir = p.join(_fs.RiadHomeDir.path, 'temp').asDir(true);
        await exePath
            .asFile()
            .rename(p.join(tempDir.path, 'Riad.$packageVersion.exe'));
        await newExe.rename(exePath);
      }
    } else {
      await Process.run('chmod', ['+x', Platform.resolvedExecutable]);
    }

    // ignore: avoid_print
    print('''
${'Success'.green()}! Riad $latestVersion has been installed. 🎉

Now, run ${'`Riad deps sync --dev-deps`'.blue()} to re-sync updated dev-dependencies.

Check out the changelog for this release at: ${release.htmlUrl}
''');

    return 0;
  }

  String archiveName() {
    if (Platform.isWindows) {
      return 'Riad-x86_64-windows.zip';
    }

    if (Platform.isLinux) {
      return 'Riad-x86_64-linux.zip';
    }

    if (Platform.isMacOS) {
      final arch = Process.runSync('uname', ['-m'], runInShell: true);
      return 'Riad-${arch.stdout.toString().trim()}-apple-darwin.zip';
    }

    throw UnsupportedError('Unsupported platform');
  }
}
