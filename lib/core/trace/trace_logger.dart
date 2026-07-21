// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trace_logger.g.dart';

/// Severity of a [TraceEntry].
enum TraceLevel { debug, info, warn, error }

/// One diagnostic event captured by [TraceLogger] (#144).
class TraceEntry {
  const TraceEntry({
    required this.ts,
    required this.level,
    required this.area,
    required this.message,
    this.error,
    this.stack,
  });

  final DateTime ts;
  final TraceLevel level;
  final String area;
  final String message;
  final String? error;
  final String? stack;
}

/// Always-on, cheap error/warning trace with a bounded in-memory ring
/// buffer and lazy append-to-file persistence (#144).
///
/// File IO is strictly best-effort: any failure (missing directory,
/// full disk, sandbox denial) silently degrades the logger to memory-only.
/// Callers must never see an exception coming out of [log] or [clear].
class TraceLogger {
  TraceLogger({
    Future<Directory> Function()? directoryProvider,
    this.capacity = 500,
    this.maxFileBytes = 512 * 1024,
  }) : _directoryProvider = directoryProvider;

  /// Global fallback for call sites without a Riverpod ref (main-zone
  /// hooks, repositories). Set during bootstrap; defaults to a
  /// memory-only logger so early/test call sites always have a target.
  static TraceLogger instance = TraceLogger();

  /// File name inside the directory returned by the directory provider.
  static const fileName = 'deskilo-trace.log';

  final Future<Directory> Function()? _directoryProvider;
  final int capacity;
  final int maxFileBytes;

  final List<TraceEntry> _buffer = [];
  final _changes = StreamController<void>.broadcast();

  /// Serializes file appends/rotations/clears; also lets tests await IO.
  Future<void> _io = Future.value();

  /// Set once file IO has failed — the logger degrades to memory-only.
  bool _fileDisabled = false;

  /// Buffered entries, newest first (capped at [capacity]).
  List<TraceEntry> get entries => _buffer.reversed.toList(growable: false);

  /// Fires after every mutation (new entry or clear) — for the UI.
  Stream<void> get changes => _changes.stream;

  /// Completes when all file writes issued so far have settled.
  Future<void> flush() => _io;

  /// Records an entry. Never throws; file persistence is fire-and-forget.
  void log(
    TraceLevel level,
    String area,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = TraceEntry(
      ts: DateTime.now().toUtc(),
      level: level,
      area: area,
      message: message,
      error: error?.toString(),
      stack: stackTrace?.toString(),
    );
    _buffer.add(entry);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
    _changes.add(null);
    _enqueue(() => _append(entry));
  }

  void warn(String area, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(TraceLevel.warn, area, message, error: error, stackTrace: stackTrace);

  void error(String area, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(
        TraceLevel.error,
        area,
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// One line per entry:
  /// `2026-07-09T12:00:00.000Z ERROR money: message | error | stack`
  /// The stack keeps every frame but has its newlines escaped as `\n`
  /// so the log file stays strictly line-oriented.
  static String formatEntry(TraceEntry e) {
    final b = StringBuffer()
      ..write(e.ts.toIso8601String())
      ..write(' ')
      ..write(e.level.name.toUpperCase())
      ..write(' ')
      ..write(e.area)
      ..write(': ')
      ..write(e.message.replaceAll('\n', r'\n'));
    if (e.error != null) b.write(' | ${e.error!.replaceAll('\n', r'\n')}');
    if (e.stack != null) b.write(' | ${e.stack!.replaceAll('\n', r'\n')}');
    return b.toString();
  }

  /// Full log content for export: the persisted file when present,
  /// otherwise the formatted in-memory buffer (oldest first).
  Future<String> exportContent() async {
    await flush();
    if (!_fileDisabled && _directoryProvider != null) {
      try {
        final file = await _file();
        if (file.existsSync()) return file.readAsString();
      } catch (e, st) {
        _disableFile(e, st);
      }
    }
    return _buffer.map(formatEntry).map((l) => '$l\n').join();
  }

  /// Empties the ring buffer and deletes the persisted file.
  Future<void> clear() async {
    _buffer.clear();
    _changes.add(null);
    _enqueue(() async {
      if (_fileDisabled || _directoryProvider == null) return;
      final file = await _file();
      if (file.existsSync()) await file.delete();
    });
    await flush();
  }

  Future<File> _file() async =>
      File('${(await _directoryProvider!()).path}${Platform.pathSeparator}'
          '$fileName');

  void _enqueue(Future<void> Function() task) {
    _io = _io.then((_) async {
      if (_fileDisabled || _directoryProvider == null) return;
      try {
        await task();
      } catch (e, st) {
        _disableFile(e, st);
      }
    });
  }

  Future<void> _append(TraceEntry entry) async {
    if (_directoryProvider == null) return;
    final file = await _file();
    await file.writeAsString(
      '${formatEntry(entry)}\n',
      mode: FileMode.append,
      flush: true,
    );
    if (file.lengthSync() > maxFileBytes) await _rotate(file);
  }

  /// Size cap: rewrite the file keeping only the newest half of its lines.
  Future<void> _rotate(File file) async {
    final lines = file
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);
    final kept = lines.sublist(lines.length ~/ 2);
    await file.writeAsString(
      kept.map((l) => '$l\n').join(),
      flush: true,
    );
  }

  void _disableFile(Object e, StackTrace st) {
    // Deliberately memory-only from here on: trace persistence must never
    // take the app down or spam retries. The failure itself stays visible
    // in the buffer.
    if (_fileDisabled) return;
    _fileDisabled = true;
    _buffer.add(
      TraceEntry(
        ts: DateTime.now().toUtc(),
        level: TraceLevel.warn,
        area: 'trace',
        message: 'trace file persistence disabled',
        error: e.toString(),
        stack: st.toString(),
      ),
    );
    _changes.add(null);
  }
}

/// App-wide trace logger. Bootstrap replaces [TraceLogger.instance] with a
/// file-backed logger before `runApp`; this provider simply exposes it so
/// widgets and tests share one injection point.
@Riverpod(keepAlive: true)
TraceLogger traceLogger(Ref ref) => TraceLogger.instance;
