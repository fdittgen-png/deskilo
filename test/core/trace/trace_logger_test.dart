// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('deskilo-trace-test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  TraceLogger fileLogger({int maxFileBytes = 512 * 1024}) => TraceLogger(
        directoryProvider: () async => tempDir,
        maxFileBytes: maxFileBytes,
      );

  File traceFile() =>
      File('${tempDir.path}${Platform.pathSeparator}${TraceLogger.fileName}');

  test('the ring buffer caps at 500 entries, newest first', () async {
    final logger = TraceLogger();
    for (var i = 0; i < 520; i++) {
      logger.log(TraceLevel.info, 'test', 'message $i');
    }
    expect(logger.entries, hasLength(500));
    expect(logger.entries.first.message, 'message 519');
    expect(logger.entries.last.message, 'message 20');
    await logger.flush();
  });

  test('entries format one-per-line with timestamp, LEVEL and area', () {
    final entry = TraceEntry(
      ts: DateTime.utc(2026, 7, 9, 12),
      level: TraceLevel.error,
      area: 'money',
      message: 'bill export failed',
    );
    expect(
      TraceLogger.formatEntry(entry),
      '2026-07-09T12:00:00.000Z ERROR money: bill export failed',
    );
  });

  test('error and stack trace are captured and kept newline-free in the '
      'formatted line', () {
    final logger = TraceLogger();
    logger.error(
      'events',
      'respond failed',
      error: StateError('boom'),
      stackTrace: StackTrace.fromString('#0 first\n#1 second\n#2 third'),
    );
    final entry = logger.entries.single;
    expect(entry.error, 'Bad state: boom');
    expect(entry.stack, contains('#1 second'));

    final line = TraceLogger.formatEntry(entry);
    expect(line, contains('ERROR events: respond failed'));
    expect(line, contains('Bad state: boom'));
    expect(line, contains(r'#0 first\n#1 second'));
    expect(line.contains('\n'), isFalse);
  });

  test('entries persist to <support>/deskilo-trace.log, one per line',
      () async {
    final logger = fileLogger();
    logger.warn('push', 'endpoint expired');
    logger.error('money', 'record payment failed');
    await logger.flush();

    final lines = traceFile().readAsLinesSync();
    expect(lines, hasLength(2));
    expect(lines[0], contains('WARN push: endpoint expired'));
    expect(lines[1], contains('ERROR money: record payment failed'));
  });

  test('the file rotates at the size cap, keeping the newest half',
      () async {
    final logger = fileLogger(maxFileBytes: 200);
    for (var i = 0; i < 8; i++) {
      logger.log(TraceLevel.info, 'test', 'rotation probe message $i');
    }
    await logger.flush();

    final file = traceFile();
    expect(file.lengthSync(), lessThanOrEqualTo(200 + 100));
    final lines = file.readAsLinesSync();
    expect(lines.length, lessThan(8));
    expect(lines.last, contains('rotation probe message 7'));
    expect(
      lines.any((l) => l.contains('rotation probe message 0')),
      isFalse,
      reason: 'the oldest line must be rotated away',
    );
  });

  test('exportContent returns the persisted file when present', () async {
    final logger = fileLogger();
    logger.error('flutter', 'render overflow');
    await logger.flush();

    final content = await logger.exportContent();
    expect(content, traceFile().readAsStringSync());
    expect(content, contains('ERROR flutter: render overflow'));
  });

  test('exportContent falls back to the buffer without a file', () async {
    final logger = TraceLogger();
    logger.warn('boot', 'slow start');
    expect(await logger.exportContent(), contains('WARN boot: slow start'));
  });

  test('clear empties both the buffer and the file', () async {
    final logger = fileLogger();
    logger.error('money', 'oops');
    await logger.flush();
    expect(traceFile().existsSync(), isTrue);

    await logger.clear();
    expect(logger.entries, isEmpty);
    expect(traceFile().existsSync(), isFalse);
    expect(await logger.exportContent(), isEmpty);
  });

  test('file IO failure never reaches callers — the logger degrades to '
      'memory-only', () async {
    final logger = TraceLogger(
      directoryProvider: () async => throw const FileSystemException('denied'),
    );
    logger.error('money', 'first');
    await logger.flush();
    logger.error('money', 'second');
    await logger.flush();

    final messages = logger.entries.map((e) => e.message).toList();
    expect(messages, contains('first'));
    expect(messages, contains('second'));
    expect(await logger.exportContent(), contains('ERROR money: second'));
  });

  test('the changes stream fires on log and on clear', () async {
    final logger = TraceLogger();
    var fired = 0;
    final sub = logger.changes.listen((_) => fired++);
    logger.log(TraceLevel.debug, 'test', 'ping');
    await logger.clear();
    await Future<void>.delayed(Duration.zero);
    expect(fired, greaterThanOrEqualTo(2));
    await sub.cancel();
  });
}
