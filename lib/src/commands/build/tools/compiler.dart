import 'dart:io' show File;

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:get_it/get_it.dart';

import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/utils/file_extension.dart';
import 'package:Riad_cli/src/utils/process_runner.dart';
import 'package:Riad_cli/src/services/file_service.dart';
import 'package:Riad_cli/src/services/lib_service.dart';
import 'package:Riad_cli/src/commands/build/utils.dart';

const helpersTimestampKey = 'helper-enums';

class Compiler {
  static final _fs = GetIt.I<FileService>();
  static final _libService = GetIt.I<LibService>();
  static final _lgr = GetIt.I<Logger>();

  static final _processRunner = ProcessRunner();

  static Future<void> _compileHelpers(
    Set<String> classpathJars,
    LazyBox<DateTime> timestampBox, {
    String? ktVersion,
    bool java8 = false,
  }) async {
    // Only the files that reside directly under the "com.sth.helpers" package
    // are considered as helpers. We could probably lift this restriction in
    // future, but because this how AI2 does it, we'll stick to it for now.
    final helperFiles = _fs.srcDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((el) => el.path.split(p.separator).contains('helpers'));

    final helpersModTime = await timestampBox.get(helpersTimestampKey);
    final helpersModified = helpersModTime == null
        ? true
        : helperFiles
            .any((el) => el.lastModifiedSync().isAfter(helpersModTime));
    if (helperFiles.isEmpty || !helpersModified) {
      return;
    }

    _lgr.info('Pre-compiling helper enums...');
    final hasKtFiles = helperFiles.any((el) => p.extension(el.path) == '.kt');

    final List<String> args;
    if (hasKtFiles) {
      args = await _kotlincArgs(
        helperFiles.first.parent.path,
        classpathJars,
        ktVersion!,
        files: helperFiles.map((e) => e.path).toSet(),
        withProc: false,
      );
    } else {
      args = await _javacArgs(
        helperFiles.map((e) => e.path).toSet(),
        classpathJars,
        java8,
        withProc: false,
      );
    }

    final compilationStartedOn = DateTime.now();
    try {
      await _processRunner.runExecutable(BuildUtils.javaExe(!hasKtFiles), args);
    } catch (e) {
      rethrow;
    }

    await _cleanUpOldClassFiles(compilationStartedOn, keepHelpers: true);
    await timestampBox.put(helpersTimestampKey, DateTime.now());
  }

  static Future<void> _cleanUpOldClassFiles(DateTime compilationStartedOn,
      {bool keepHelpers = false}) async {
    final files = _fs.buildClassesDir
        .listSync(recursive: true)
        .where((el) => p.extension(el.path) == '.class' && !keepHelpers
            ? !el.path.split(p.separator).contains('helpers')
            : true)
        .whereType<File>();

    for (final file in files) {
      if ((await file.lastModified()).isBefore(compilationStartedOn)) {
        await file.delete();
      }
    }
  }

  static Future<void> compileJavaFiles(
    Set<String> classpathJars,
    bool supportJava8,
    LazyBox<DateTime> timestampBox,
  ) async {
    final javaFiles = _fs.srcDir
        .listSync(recursive: true)
        .where((el) => el is File && p.extension(el.path) == '.java')
        .map((el) => el.path)
        .toSet();

    final DateTime compilationStartedOn;
    try {
      await _compileHelpers(classpathJars, timestampBox, java8: supportJava8);
      final args = _javacArgs(javaFiles, classpathJars, supportJava8);
      compilationStartedOn = DateTime.now();
      await _processRunner.runExecutable(BuildUtils.javaExe(true), await args);
    } catch (e) {
      rethrow;
    }
    await _cleanUpOldClassFiles(compilationStartedOn);
  }

  static Future<List<String>> _javacArgs(
    Set<String> files,
    Set<String> classpathJars,
    bool supportJava8, {
    bool withProc = true,
  }) async {
    final classpath = classpathJars.join(BuildUtils.cpSeparator);
    final procClasspath = await _libService.processorJar();
    final args = <String>[
      ...['-source', supportJava8 ? '1.8' : '1.7'],
      ...['-target', supportJava8 ? '1.8' : '1.7'],
      ...['-encoding', 'UTF8'],
      ...['-d', '"${_fs.buildClassesDir.path}"'],
      ...['-cp', '"$classpath"'],
      if (withProc) ...['-processorpath', '"$procClasspath"'],
      ...files.map((el) => '"$el"'),
    ].map((el) => el.replaceAll('\\', '/')).join('\n');
    await _fs.javacArgsFile.writeAsString(args);
    return ['@${_fs.javacArgsFile.path}'];
  }

  static Future<void> compileKtFiles(
    Set<String> classpathJars,
    String kotlinVersion,
    LazyBox<DateTime> timestampBox,
  ) async {
    final DateTime compilationStartedOn;
    try {
      await _compileHelpers(classpathJars, timestampBox,
          ktVersion: kotlinVersion);
      final kotlincArgs =
          await _kotlincArgs(_fs.srcDir.path, classpathJars, kotlinVersion);
      compilationStartedOn = DateTime.now();
      await _processRunner.runExecutable(BuildUtils.javaExe(), kotlincArgs);
    } catch (e) {
      rethrow;
    }
    await _cleanUpOldClassFiles(compilationStartedOn);
  }

  static Future<List<String>> _kotlincArgs(
    String srcDir,
    Set<String> classpathJars,
    String kotlinVersion, {
    bool withProc = true,
    Set<String>? files,
  }) async {
    // Here, we are copying the kotlin-annotation-processing-embeddable jar
    // in the it's own directory but with name: kotlin-annotation-processing.jar
    // This is a bug in kapt, and for more details:
    // https://youtrack.jetbrains.com/issue/KTIJ-22605/kotlin-annotation-processing-embeddable-isnt-actually-embeddable
    final kaptJar = (await _libService.kaptJars(kotlinVersion)).first;
    final duplicateKaptJar =
        p.join(p.dirname(kaptJar), 'kotlin-annotation-processing.jar');
    await kaptJar.asFile().copy(duplicateKaptJar);

    final toolsJar =
        p.join(await BuildUtils.javaHomeDir(), 'lib', 'tools.jar').asFile();

    final classpath = [
      ...(await _libService.kotlincJars(kotlinVersion)),
      if (withProc) ...(await _libService.kaptJars(kotlinVersion)),
      if (withProc && await toolsJar.exists()) toolsJar.path,
    ].join(BuildUtils.cpSeparator);

    final procClasspath = await _libService.processorJar();

    final kotlincArgs = <String>[
      ...['-cp', classpathJars.join(BuildUtils.cpSeparator)],
      if (withProc) ...[
        // KaptCli args
        '-Kapt-classes=${_fs.buildKaptDir.path}',
        '-Kapt-sources=${_fs.buildKaptDir.path}',
        '-Kapt-stubs=${_fs.buildKaptDir.path}',
        '-Kapt-classpath=$procClasspath',
        '-Kapt-mode=compile',
        '-Kapt-strip-metadata=true',
        '-Kapt-use-light-analysis=true',
      ],
      '-no-stdlib',
      ...['-d', _fs.buildClassesDir.path],
      if (files != null) ...files else srcDir,
    ].map((el) => el.replaceAll('\\', '/')).join('\n');

    final argsFile = _fs.kotlincArgsFile;
    await argsFile.writeAsString(kotlincArgs);
    return <String>[
      // This -cp flag belongs to the java cmdline tool, required to run the
      // below KaptCli class
      ...['-cp', classpath],
      if (withProc)
        'org.jetbrains.kotlin.kapt.cli.KaptCli'
      else
        'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
      '@${argsFile.path}',
    ].map((el) => el.replaceAll('\\', '/')).toList();
  }
}
