import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:collection/collection.dart';

import 'package:Riad_cli/src/commands/build/utils.dart';
import 'package:Riad_cli/src/config/config.dart';
import 'package:Riad_cli/src/resolver/artifact.dart';
import 'package:Riad_cli/src/services/file_service.dart';
import 'package:Riad_cli/src/services/logger.dart';
import 'package:Riad_cli/src/utils/constants.dart';
import 'package:Riad_cli/src/utils/file_extension.dart';
import 'package:tint/tint.dart';

const RiadApCoord =
    'io.github.RiadDeveloper.Riad:processor:$annotationProcVersion';
const r8Coord = 'com.android.tools:r8:3.3.28';
const pgCoord = 'com.guardsquare:proguard-base:7.2.2';
const desugarCoord = 'io.github.RiadDeveloper:desugar:1.0.0';

const manifMergerAndDeps = <String>[
  'com.android.tools.build:manifest-merger:30.0.0',
  'org.w3c:dom:2.3.0-jaxb-1.0.6',
  'xml-apis:xml-apis:1.4.01',
];

const kotlinGroupId = 'org.jetbrains.kotlin';

class LibService {
  static final _fs = GetIt.I<FileService>();
  static final _lgr = GetIt.I<Logger>();

  LibService._() {
    Hive
      ..registerAdapter(ArtifactAdapter())
      ..registerAdapter(ScopeAdapter());

    // Don't init Hive in .Riad dir if we're not in a Riad project
    if (_fs.configFile.existsSync()) {
      Hive.init(_fs.dotRiadDir.path);
    }
  }

  late final LazyBox<Artifact> ai2ProvidedDepsBox;
  late final LazyBox<Artifact> buildLibsBox;
  late final LazyBox<Artifact>? extensionDepsBox;

  static Future<LibService> instantiate() async {
    final instance = LibService._();
    instance.ai2ProvidedDepsBox = await Hive.openLazyBox<Artifact>(
      providedDepsBoxName,
      path: p.join(_fs.RiadHomeDir.path, 'cache'),
    );
    instance.buildLibsBox = await Hive.openLazyBox<Artifact>(
      buildLibsBoxName,
      path: p.join(_fs.RiadHomeDir.path, 'cache'),
    );

    if (await _fs.configFile.exists()) {
      instance.extensionDepsBox = await Hive.openLazyBox<Artifact>(
        extensionDepsBoxName,
        path: _fs.dotRiadDir.path,
      );
    } else {
      instance.extensionDepsBox = null;
    }
    return instance;
  }

  /// Returns a list of all the artifacts and their dependencies in a box.
  Future<List<Artifact>> _retrieveArtifactsFromBox(
      LazyBox<Artifact> cacheBox) async {
    final artifacts = await Future.wait([
      for (final key in cacheBox.keys) cacheBox.get(key),
    ]);
    return artifacts.whereNotNull().toList();
  }

  Future<List<Artifact>> providedDependencies(Config? config) async {
    final local = [
      'android-$androidPlatformSdkVersion.jar',
      'google-webrtc-1.0.19742.jar',
      'kawa-1.11-modified.jar',
      'mp-android-chart-3.1.0.jar',
      'osmdroid-5.6.6.jar',
      'physicaloid-library.jar',
    ].map((el) => Artifact(
          coordinate: el,
          scope: Scope.provided,
          artifactFile: p.join(_fs.libsDir.path, el),
          packaging: 'jar',
          dependencies: [],
          sourcesJar: null,
        ));

    if (config == null) {
      return [
        ...await _retrieveArtifactsFromBox(ai2ProvidedDepsBox),
        ...local,
      ];
    }

    final allExtRemoteDeps = await _retrieveArtifactsFromBox(extensionDepsBox!);
    final extProvidedDeps = config.providedDependencies
        .map((el) =>
            allExtRemoteDeps.firstWhereOrNull((dep) => dep.coordinate == el))
        .whereNotNull();
    final extLocalProvided = config.providedDependencies
        .where((el) => el.endsWith('.jar') || el.endsWith('.aar'))
        .map((el) {
      return Artifact(
        scope: Scope.provided,
        coordinate: el,
        artifactFile: p.join(_fs.localDepsDir.path, el),
        packaging: p.extension(el).substring(1),
        dependencies: [],
        sourcesJar: null,
      );
    });

    return [
      ...await _retrieveArtifactsFromBox(ai2ProvidedDepsBox),
      ...extProvidedDeps,
      ...extLocalProvided,
      ...local,
    ];
  }

  List<Artifact> _requiredDeps(
      Iterable<Artifact> allDeps, Iterable<Artifact> directDeps) {
    final res = <Artifact>{};
    for (final dep in directDeps) {
      final depArtifacts = dep.dependencies
          .map((el) => allDeps.firstWhereOrNull((a) => a.coordinate == el))
          .whereNotNull();
      res
        ..add(dep)
        ..addAll(_requiredDeps(allDeps, depArtifacts));
    }
    return res.toList();
  }

  Future<List<Artifact>> extensionDependencies(
    Config config, {
    bool includeAi2ProvidedDeps = false,
    bool includeProjectProvidedDeps = false,
    bool includeLocal = true,
  }) async {
    final allExtRemoteDeps = await _retrieveArtifactsFromBox(extensionDepsBox!);

    final projectDeps = config.dependencies
        .map((el) =>
            allExtRemoteDeps.firstWhereOrNull((dep) => dep.coordinate == el))
        .whereNotNull();
    final requiredDeps = _requiredDeps(allExtRemoteDeps, projectDeps);

    final projectProvidedDeps = config.providedDependencies
        .map((el) =>
            allExtRemoteDeps.firstWhereOrNull((dep) => dep.coordinate == el))
        .whereNotNull();
    final requiredProjectProvidedDeps =
        _requiredDeps(allExtRemoteDeps, projectProvidedDeps);

    final localDeps = config.dependencies
        .where((el) => el.endsWith('.jar') || el.endsWith('.aar'))
        .map((el) {
      return Artifact(
        scope: Scope.compile,
        coordinate: el,
        artifactFile: p.join(_fs.localDepsDir.path, el),
        packaging: p.extension(el).substring(1),
        dependencies: [],
        sourcesJar: null,
      );
    });
    await BuildUtils.extractAars(localDeps
        .where((el) => el.packaging == 'aar')
        .map((el) => el.artifactFile));

    return [
      ...requiredDeps,
      if (includeLocal) ...localDeps,
      if (includeAi2ProvidedDeps) ...await providedDependencies(config),
      if (includeProjectProvidedDeps) ...requiredProjectProvidedDeps,
    ];
  }

  Future<List<Artifact>> buildLibArtifacts() async =>
      (await _retrieveArtifactsFromBox(buildLibsBox)).toList();

  Future<Artifact> _findArtifact(LazyBox<Artifact> box, String coord) async {
    final artifact = await box.get(coord);
    if (artifact == null || !await artifact.artifactFile.asFile().exists()) {
      _lgr
        ..err('Unable to find a required library in cache: $coord')
        ..log('Try running `Riad deps sync`', 'help  '.green());
      throw Exception();
    }
    return artifact;
  }

  Future<String> processorJar() async =>
      (await _findArtifact(buildLibsBox, RiadApCoord)).classesJar;

  Future<String> r8Jar() async =>
      (await _findArtifact(buildLibsBox, r8Coord)).classesJar;

  Future<Set<String>> pgJars() async =>
      (await _findArtifact(buildLibsBox, pgCoord))
          .classpathJars(await buildLibArtifacts());

  Future<String> desugarJar() async =>
      (await _findArtifact(buildLibsBox, desugarCoord)).classesJar;

  Future<Set<String>> manifMergerJars() async => [
        for (final lib in manifMergerAndDeps)
          (await _findArtifact(buildLibsBox, lib))
              .classpathJars(await buildLibArtifacts())
      ].flattened.toSet();

  Future<Set<String>> kotlincJars(String ktVersion) async =>
      (await _findArtifact(
        buildLibsBox,
        '$kotlinGroupId:kotlin-compiler-embeddable:$ktVersion',
      ))
          .classpathJars(await buildLibArtifacts());

  Future<Set<String>> kaptJars(String ktVersion) async => (await _findArtifact(
        buildLibsBox,
        '$kotlinGroupId:kotlin-annotation-processing-embeddable:$ktVersion',
      ))
          .classpathJars(await buildLibArtifacts());
}
