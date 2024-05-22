import 'package:args/command_runner.dart';
import 'package:get_it/get_it.dart';
import 'package:Riad_cli/src/command_runner.dart';
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/services/service_locator.dart';

Future<void> main(List<String> args) async {
  ServiceLocator.setupServiceLocator();
  await GetIt.I.allReady();
  try {
    await RiadCommandRunner().run(args);
  } on UsageException catch (e) {
    GetIt.I<Logger>().err(e.message);
  }
}
