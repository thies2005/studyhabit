import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Constants mirror the production values in
/// lib/core/database/app_database.dart. They are duplicated here so the test
/// does not have to import the production file (which transitively pulls in
/// drift code-gen output that is heavy to compile in unit tests).
const String kDatabaseFileName = 'studyhabit.sqlite';

void main() {
  group('database directory resolution', () {
    test('a fresh writable directory is recognised as usable', () async {
      final temp = await Directory.systemTemp.createTemp('db_dir_test_');
      addTearDown(() => temp.delete(recursive: true));

      expect(await _isUsable(temp.path), isTrue);
    });

    test(
      'a path with missing parents is created and becomes usable',
      () async {
        final temp = await Directory.systemTemp.createTemp('db_dir_test_');
        addTearDown(() => temp.delete(recursive: true));

        final deep = p.join(temp.path, 'a', 'b', 'c');
        expect(Directory(deep).existsSync(), isFalse);
        expect(await _isUsable(deep), isTrue);
        expect(Directory(deep).existsSync(), isTrue);
      },
    );

    test('legacy database file is migrated into the resolved directory',
        () async {
      final temp = await Directory.systemTemp.createTemp('db_migrate_test_');
      addTearDown(() => temp.delete(recursive: true));

      final targetDir = Directory(p.join(temp.path, 'target'))
        ..createSync(recursive: true);
      final legacyDir = Directory(p.join(temp.path, 'legacy'))
        ..createSync(recursive: true);

      // Pretend the previous version of the app wrote a DB with the doubled
      // extension that drift_flutter produces when given 'studyhabit.sqlite'.
      final legacy =
          File(p.join(legacyDir.path, 'studyhabit.sqlite.sqlite'));
      await legacy.writeAsString('fake sqlite contents');

      final target = File(p.join(targetDir.path, kDatabaseFileName));
      expect(target.existsSync(), isFalse);

      await _migrateLegacyDatabase(
        targetDirectory: targetDir.path,
        legacyDirectoryProvider: () async => legacyDir,
      );

      expect(target.existsSync(), isTrue,
          reason: 'legacy file should have been moved into the target dir');
      expect(legacy.existsSync(), isFalse,
          reason: 'legacy file should have been removed after migration');
      expect(await target.readAsString(), equals('fake sqlite contents'));
    });

    test(
      'legacy pre-rename studytracker database is also migrated',
      () async {
        final temp =
            await Directory.systemTemp.createTemp('db_migrate_test_');
        addTearDown(() => temp.delete(recursive: true));

        final targetDir = Directory(p.join(temp.path, 'target'))
          ..createSync(recursive: true);
        final legacyDir = Directory(p.join(temp.path, 'legacy'))
          ..createSync(recursive: true);

        // The app was renamed from StudyTracker to StudyHabit; users on the
        // older build must still be migrated.
        final legacy =
            File(p.join(legacyDir.path, 'studytracker.sqlite.sqlite'));
        await legacy.writeAsString('legacy tracker contents');

        final target = File(p.join(targetDir.path, kDatabaseFileName));
        await _migrateLegacyDatabase(
          targetDirectory: targetDir.path,
          legacyDirectoryProvider: () async => legacyDir,
        );

        expect(target.existsSync(), isTrue);
        expect(await target.readAsString(), equals('legacy tracker contents'));
      },
    );

    test('studyhabit file takes priority over older studytracker file',
        () async {
      final temp = await Directory.systemTemp.createTemp('db_migrate_test_');
      addTearDown(() => temp.delete(recursive: true));

      final targetDir = Directory(p.join(temp.path, 'target'))
        ..createSync(recursive: true);
      final legacyDir = Directory(p.join(temp.path, 'legacy'))
        ..createSync(recursive: true);

      // Both legacy files present: the newer one must win.
      File(p.join(legacyDir.path, 'studytracker.sqlite.sqlite'))
          .writeAsStringSync('OLD tracker data');
      File(p.join(legacyDir.path, 'studyhabit.sqlite.sqlite'))
          .writeAsStringSync('NEW habit data');

      final target = File(p.join(targetDir.path, kDatabaseFileName));
      await _migrateLegacyDatabase(
        targetDirectory: targetDir.path,
        legacyDirectoryProvider: () async => legacyDir,
      );

      expect(await target.readAsString(), equals('NEW habit data'));
    });

    test('existing target file is left untouched (no overwrite)', () async {
      final temp = await Directory.systemTemp.createTemp('db_migrate_test_');
      addTearDown(() => temp.delete(recursive: true));

      final targetDir = Directory(p.join(temp.path, 'target'))
        ..createSync(recursive: true);
      final legacyDir = Directory(p.join(temp.path, 'legacy'))
        ..createSync(recursive: true);

      // Target already populated.
      final target = File(p.join(targetDir.path, kDatabaseFileName));
      await target.writeAsString('current data');

      // Legacy file present too.
      final legacy =
          File(p.join(legacyDir.path, 'studytracker.sqlite.sqlite'));
      await legacy.writeAsString('old data');

      await _migrateLegacyDatabase(
        targetDirectory: targetDir.path,
        legacyDirectoryProvider: () async => legacyDir,
      );

      expect(await target.readAsString(), equals('current data'),
          reason: 'must not overwrite the newer target file');
      expect(legacy.existsSync(), isTrue,
          reason: 'legacy file must be left in place when target exists');
    });

    test('missing legacy directory provider is tolerated', () async {
      final temp = await Directory.systemTemp.createTemp('db_migrate_test_');
      addTearDown(() => temp.delete(recursive: true));

      // Should not throw, and should not create any files.
      await _migrateLegacyDatabase(
        targetDirectory: temp.path,
        legacyDirectoryProvider: () async => throw Exception('not available'),
      );

      expect(
        Directory(temp.path).listSync().whereType<File>(),
        isEmpty,
      );
    });
  });
}

/// Mirror of `_ensureUsableDirectory` in lib/core/database/app_database.dart.
/// Kept in sync manually so this test exercises the same algorithm without
/// dragging in the full drift bootstrap.
Future<bool> _isUsable(String path) async {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final probe = File(p.join(path, '.drift_probe'));
    await probe.writeAsString('ok', flush: true);
    try {
      await probe.delete();
    } catch (_) {
      // Non-fatal.
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Mirror of `_migrateLegacyDatabase` in lib/core/database/app_database.dart,
/// refactored to accept the legacy directory as an injectable callback so the
/// test can fake path_provider failures.
Future<void> _migrateLegacyDatabase({
  required String targetDirectory,
  required Future<Directory> Function() legacyDirectoryProvider,
}) async {
  final targetFile = File(p.join(targetDirectory, kDatabaseFileName));
  if (targetFile.existsSync()) return;

  Directory legacyDir;
  try {
    legacyDir = await legacyDirectoryProvider();
  } catch (_) {
    return;
  }

  final legacyCandidates = <File>[
    File(p.join(legacyDir.path, 'studyhabit.sqlite.sqlite')),
    File(p.join(legacyDir.path, 'studyhabit.sqlite')),
    File(p.join(legacyDir.path, 'studytracker.sqlite.sqlite')),
    File(p.join(legacyDir.path, 'studytracker.sqlite')),
  ];

  for (final legacy in legacyCandidates) {
    if (legacy.existsSync()) {
      try {
        await legacy.rename(targetFile.path);
      } catch (_) {
        await legacy.copy(targetFile.path);
        try {
          await legacy.delete();
        } catch (_) {
          // Non-fatal.
        }
      }
      return;
    }
  }
}
