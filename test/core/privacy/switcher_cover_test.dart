// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C1 -- the app-switcher cover, proved at the channel boundary.
//
// The invariants: only `protected` and `frameEpoch` cross the channel; a
// new display frame (another workspace, another account) takes the next
// epoch; an unsettled frame is never acknowledged; an acknowledgement for
// a frame that was replaced while it drew is never sent; every return to
// the foreground acknowledges the CURRENT frame. The native halves (the
// iPhone scene cover, Android's recents policy and pause cover) cannot run
// in a unit test; they are device evidence (XPRIV-iOS, XPRIV-Android).
import 'dart:async';

import 'package:deskilo/core/privacy/switcher_cover.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(SwitcherCover.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  List<String> trace() => [
    for (final c in calls)
      '${c.method}:${(c.arguments as Map).entries.map((e) => '${e.key}=${e.value}').join(',')}',
  ];

  const p1 = DisplayFrame(personal: 'p-1', role: DisplaySourceRole.personal);
  const wA = DisplayFrame(
    personal: 'p-1',
    role: DisplaySourceRole.workspace,
    target: 'home|ws-a',
  );
  const wB = DisplayFrame(
    personal: 'p-1',
    role: DisplaySourceRole.workspace,
    target: 'conn|ws-b',
  );

  group('SwitcherCover', () {
    test('sends only the protection and the epoch, and the same context '
        'once', () async {
      final cover = SwitcherCover(web: false);
      await cover.setProtectedContext(protected: true, frameEpoch: 1);
      await cover.setProtectedContext(protected: true, frameEpoch: 1);
      await cover.foregroundReady(1);
      expect(trace(), [
        'setProtectedContext:protected=true,frameEpoch=1',
        'foregroundReady:frameEpoch=1',
      ]);
    });

    test('the inert and the web cover reach no platform', () async {
      for (final cover in [SwitcherCover.inert(), SwitcherCover(web: true)]) {
        await cover.setProtectedContext(protected: true, frameEpoch: 1);
        await cover.foregroundReady(1);
      }
      expect(calls, isEmpty);
    });

    test('a runner without the channel is not an error of the app', () async {
      messenger.setMockMethodCallHandler(channel, null);
      final cover = SwitcherCover(web: false);
      await expectLater(
        cover.setProtectedContext(protected: true, frameEpoch: 1),
        completes,
      );
    });
  });

  group('DisplayFrameClock', () {
    test('the same frame keeps its epoch; any other frame, a return '
        'included, takes the next', () {
      final clock = DisplayFrameClock();
      expect(clock.epochFor(p1), 1);
      expect(clock.epochFor(p1), 1);
      expect(clock.epochFor(wA), 2);
      expect(clock.epochFor(wB), 3);
      expect(clock.epochFor(wA), 4, reason: 'monotonic, never reused');
    });

    test('unknown and signed-in frames are protected; signed out is not', () {
      expect(const DisplayFrame.unknown().protected, isTrue);
      expect(p1.protected, isTrue);
      expect(wA.protected, isTrue);
      expect(
        const DisplayFrame(
          personal: null,
          role: DisplaySourceRole.personal,
          signedOut: true,
        ).protected,
        isFalse,
      );
    });
  });

  group('SwitcherCoverController', () {
    late List<Completer<void>> frames;
    late SwitcherCoverController controller;

    setUp(() {
      frames = [];
      controller = SwitcherCoverController(
        SwitcherCover(web: false),
        afterFrame: () {
          final drawn = Completer<void>();
          frames.add(drawn);
          return drawn.future;
        },
      );
    });

    /// Draws every pending frame, including those a drawn frame asked for.
    Future<void> draw() async {
      await pumpEventQueue();
      while (frames.any((f) => !f.isCompleted)) {
        for (final f in frames) {
          if (!f.isCompleted) f.complete();
        }
        await pumpEventQueue();
      }
    }

    test(
      'a settled frame is announced, then acknowledged once drawn',
      () async {
        unawaited(controller.show(p1));
        await pumpEventQueue();
        expect(trace(), ['setProtectedContext:protected=true,frameEpoch=1']);
        await draw();
        expect(trace().last, 'foregroundReady:frameEpoch=1');
      },
    );

    test('a workspace switch advances the frame epoch and the replaced '
        'frame is never acknowledged (XPRIV-epoch)', () async {
      unawaited(controller.show(wA));
      await pumpEventQueue();
      unawaited(controller.show(wB));
      await draw();
      expect(trace(), [
        'setProtectedContext:protected=true,frameEpoch=1',
        'setProtectedContext:protected=true,frameEpoch=2',
        'foregroundReady:frameEpoch=2',
      ], reason: 'W-A finished drawing after W-B replaced it: no stale ack');
    });

    test('an account switch fences the old frame the same way', () async {
      unawaited(controller.show(p1));
      await pumpEventQueue();
      unawaited(
        controller.show(
          const DisplayFrame(personal: 'p-2', role: DisplaySourceRole.personal),
        ),
      );
      await draw();
      expect(trace().where((t) => t.startsWith('foregroundReady')), [
        'foregroundReady:frameEpoch=2',
      ]);
    });

    test('a frame still loading is announced but never acknowledged', () async {
      unawaited(controller.show(const DisplayFrame.unknown()));
      unawaited(
        controller.show(
          const DisplayFrame(
            personal: 'p-1',
            role: DisplaySourceRole.workspace,
            target: 'home|ws-a',
            settled: false,
          ),
        ),
      );
      await draw();
      await controller.resumed();
      expect(trace().where((t) => t.startsWith('foregroundReady')), isEmpty);
      expect(trace(), [
        'setProtectedContext:protected=true,frameEpoch=1',
        'setProtectedContext:protected=true,frameEpoch=2',
      ]);
    });

    test('every return to the foreground acknowledges the current frame, '
        'and an unchanged frame is not announced again', () async {
      unawaited(controller.show(wA));
      await draw();
      unawaited(controller.show(wA));
      await draw();
      unawaited(controller.resumed());
      await draw();
      expect(trace(), [
        'setProtectedContext:protected=true,frameEpoch=1',
        'foregroundReady:frameEpoch=1',
        'foregroundReady:frameEpoch=1',
        'foregroundReady:frameEpoch=1',
      ]);
    });

    test('signing out lifts the protection', () async {
      unawaited(controller.show(p1));
      await draw();
      unawaited(
        controller.show(
          const DisplayFrame(
            personal: null,
            role: DisplaySourceRole.personal,
            signedOut: true,
          ),
        ),
      );
      await draw();
      expect(
        trace(),
        contains('setProtectedContext:protected=false,frameEpoch=2'),
      );
    });
  });
}
