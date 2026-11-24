// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — an error the trace records reaches the installation as a redacted
// report, within the installation's hourly budget and size cap, only while
// somebody is signed in, outside the Demo and with the Privacy switch on; a
// report that cannot go is dropped and never sent again, and a warning (this
// reporter's own included) is never sent.
import 'dart:convert';
import 'dart:math';

import 'package:deskilo/app/trace_reporting_wiring.dart';
import 'package:deskilo/core/app_info.dart';
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/data/server_error.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/trace/trace_report.dart';
import 'package:deskilo/core/trace/trace_report_device.dart';
import 'package:deskilo/core/trace/trace_reporter.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements TraceReportSink {
  final sent = <TraceReport>[];
  Error? fail;

  @override
  Future<TraceReportAnswer> submit(TraceReport report) async {
    if (fail case final f?) throw f;
    sent.add(report);
    return TraceReportAnswer.stored;
  }
}

class _Store implements TraceReportDeviceStore {
  _Store({this.on = true});
  bool on;

  @override
  Future<String> deviceId() async => 'device-0123456789';

  @override
  Future<bool> enabled() async => on;

  @override
  Future<void> setEnabled({required bool on}) async => this.on = on;
}

TraceEntry _entry(TraceLevel level, {Object? error, String? stack}) =>
    TraceEntry(
      ts: DateTime.utc(2026, 11, 24),
      level: level,
      area: 'money',
      message: 'invoice for ada@example.test not issued',
      error: error?.toString(),
      stack: stack,
      errorType: error?.runtimeType.toString(),
      errorCode: error == null ? null : serverErrorCode(error),
    );

TraceReport? _report(TraceEntry e, {int maxBytes = 16384}) => traceReportOf(
  e,
  deviceId: 'device-0123456789',
  appVersion: '2.2.0',
  schemaVersion: 953,
  platform: 'android',
  maxBytes: maxBytes,
);

void main() {
  group('the report', () {
    test('only an error is reported, by its kind and code, never its sentence', () {
      expect(_report(_entry(TraceLevel.warn, error: StateError('x'))), isNull);
      final r = _report(
        _entry(
          TraceLevel.error,
          error: const Refusal(
            code: DkCode.dkn01,
            message: 'ada@example.test may not',
          ),
          stack: '#0 issue (invoice.dart:12) for ada@example.test',
        ),
      )!;
      expect(r.failureType, 'money/Refusal');
      expect(r.failureCode, DkCode.dkn01);
      expect(r.stack, '#0 issue (invoice.dart:12) for <email>');
      expect(
        '${r.failureType}${r.failureCode}${r.stack}${r.appVersion}${r.platform}',
        isNot(contains('ada@')),
      );
    });

    test('the stack is cut so the whole report fits the size cap', () {
      final r = _report(
        _entry(TraceLevel.error, error: StateError('x'), stack: 'é' * 5000),
        maxBytes: 1024,
      )!;
      final bytes = utf8.encode(
        '${r.appVersion}${r.platform}${r.failureType}${r.failureCode ?? ''}${r.stack}',
      );
      expect(bytes.length, lessThanOrEqualTo(1024));
      expect(r.stack, isNotEmpty);
    });

    test('a device id has the shape the installation accepts', () {
      expect(
        traceReportDeviceIdOf(Random(1)),
        matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')),
      );
    });

    test('an answer is read from its wire word, an unknown one as unknown', () {
      expect(
        TraceReportAnswer.fromWire('rate_limited'),
        TraceReportAnswer.rateLimited,
      );
      expect(TraceReportAnswer.fromWire('later'), TraceReportAnswer.unknown);
    });
  });

  group('the reporter', () {
    late TraceLogger trace;
    late _Sink sink;
    late List<String> warned;
    var perHour = 2;
    var now = DateTime.utc(2026, 11, 24, 10);

    TraceReporter reporter() => TraceReporter(
      entries: trace.added,
      report: (e) async => _report(e),
      sink: sink,
      perHour: () => perHour,
      now: () => now,
      warn: (m, e, _) => warned.add(m),
    );

    setUp(() {
      trace = TraceLogger();
      sink = _Sink();
      warned = [];
      perHour = 2;
      now = DateTime.utc(2026, 11, 24, 10);
    });

    Future<void> settle(TraceReporter r) async {
      await Future<void>.delayed(Duration.zero);
      await r.idle;
    }

    test('sends errors within the hourly budget, never a warning', () async {
      final r = reporter();
      for (var i = 0; i < 3; i++) {
        trace.error('money', 'failed $i', error: StateError('x'));
        await settle(r);
      }
      trace.warn('money', 'slow', error: StateError('y'));
      await settle(r);
      expect(
        sink.sent,
        hasLength(2),
        reason: 'the third error of the hour is over budget',
      );
      now = now.add(const Duration(hours: 1));
      trace.error('money', 'later', error: StateError('z'));
      await settle(r);
      expect(
        sink.sent,
        hasLength(3),
        reason: 'a new hour has its budget again',
      );
      await r.dispose();
    });

    test('a budget of 0 sends nothing', () async {
      perHour = 0;
      final r = reporter();
      trace.error('money', 'failed', error: StateError('x'));
      await settle(r);
      expect(sink.sent, isEmpty);
      await r.dispose();
    });

    test(
      'a report that cannot go is dropped with a warning, never sent again',
      () async {
        sink.fail = StateError('offline');
        final r = reporter();
        trace.error('money', 'failed', error: StateError('x'));
        await settle(r);
        sink.fail = null;
        await settle(r);
        expect(sink.sent, isEmpty);
        expect(warned, ['an error report was not sent']);
        await r.dispose();
      },
    );
  });

  group('the wiring', () {
    ProviderContainer container(_Store store, _Sink sink, {bool demo = false}) {
      final c = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value('user-1')),
          traceReportDeviceStoreProvider.overrideWithValue(store),
          traceReportSinkProvider.overrideWithValue(sink),
          traceLoggerProvider.overrideWithValue(TraceLogger()),
          appVersionProvider.overrideWith((ref) async => '2.2.0'),
        ],
      );
      if (demo) c.read(demoEntryProvider.notifier).state = true;
      addTearDown(c.dispose);
      return c;
    }

    Future<void> ready(ProviderContainer c) async {
      // The reporter's provider keeps the session and the switch alive.
      c.listen(traceReportingProvider, (_, _) {});
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> fail(ProviderContainer c) async {
      c
          .read(traceLoggerProvider)
          .error('money', 'failed', error: StateError('x'));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'signed in with the switch on, an error reaches the installation',
      () async {
        final sink = _Sink();
        final c = container(_Store(), sink);
        await ready(c);
        await fail(c);
        expect(sink.sent.single.failureType, 'money/StateError');
        expect(sink.sent.single.deviceId, 'device-0123456789');
      },
    );

    test(
      'switched off, nothing leaves the device, and on again it does',
      () async {
        final sink = _Sink();
        final c = container(_Store(on: false), sink);
        await ready(c);
        await fail(c);
        expect(sink.sent, isEmpty);
        await c.read(traceReportsSwitchProvider.notifier).set(on: true);
        await ready(c);
        await fail(c);
        expect(sink.sent, hasLength(1));
      },
    );

    test('the Demo sends nothing', () async {
      final sink = _Sink();
      final c = container(_Store(), sink, demo: true);
      await ready(c);
      await fail(c);
      expect(sink.sent, isEmpty);
    });
  });
}
