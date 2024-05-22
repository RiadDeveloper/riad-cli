import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_console/dart_console.dart';
import 'package:get_it/get_it.dart';
import 'package:tint/tint.dart';

import 'package:Riad_cli/src/commands/build/build.dart';
import 'package:Riad_cli/src/commands/clean.dart';
import 'package:Riad_cli/src/commands/create/create.dart';
import 'package:Riad_cli/src/commands/deps/deps.dart';
import 'package:Riad_cli/src/commands/migrate/migrate.dart';
import 'package:Riad_cli/src/commands/upgrade/upgrade.dart';
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/version.dart';

class RiadCommandRunner extends CommandRunner<int> {
  RiadCommandRunner()
      : super('Riad',
            'Riad is a fast and feature rich extension builder for MIT App Inventor 2.') {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Turns on verbose logging.',
        callback: (ok) {
          GetIt.I<Logger>().debug = ok;
        },
      )
      ..addFlag(
        'color',
        abbr: 'c',
        defaultsTo: true,
        help:
            'Whether output should be colorized or not. Defaults to true in terminals that support ANSI colors.',
        callback: (ok) {
          final noColorEnv =
              int.tryParse(Platform.environment['NO_COLOR'] ?? '0');
          if (noColorEnv != null && noColorEnv == 1) {
            supportsAnsiColor = false;
          } else {
            supportsAnsiColor = ok;
          }
        },
      )
      ..addFlag(
        'version',
        abbr: 'V',
        negatable: false,
        help: 'Prints the current version name.',
        callback: (ok) {
          if (ok) {
            Console().writeLine('Running on version ${packageVersion.cyan()}');
            exit(0);
          }
        },
      )
      ..addFlag(
        'logo',
        abbr: 'l',
        defaultsTo: true,
        hide: true,
        callback: (ok) {
          if (ok) _printLogo();
        },
      );

    addCommand(BuildCommand());
    addCommand(CleanCommand());
    addCommand(CreateCommand());
    addCommand(DepsCommand());
    addCommand(MigrateCommand());
    addCommand(UpgradeCommand());
  }

  void _printLogo() {
    final logo = r'''
                    __
   _______  _______/ /_
  / ___/ / / / ___/ __ \
 / /  / /_/ (__  / / / /
/_/   \__,_/____/_/ /_/
''';
    Console().writeLine(logo.blue());
  }
}
