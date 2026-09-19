// SPDX-License-Identifier: 0BSD
//
// #1375 — the Reset control, driven the way a visitor drives it.
//
// The session test proves the semantics; this proves the control is
// wired to them: a screen INSIDE the Demo scope reads the fixture, a tap
// on Reset replaces the scope, and the screen that comes back is reading
// the canonical dataset again without anyone telling it to refresh.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen inside the scope: it reads the repository the scope provides,
/// exactly as a real one does.
class _Levels extends ConsumerStatefulWidget {
  const _Levels();
  @override
  ConsumerState<_Levels> createState() => _LevelsState();
}

class _LevelsState extends ConsumerState<_Levels> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels =
        await ref.read(floorPlanRepositoryProvider).fetchLevels('ws-1');
    if (mounted) setState(() => _count = levels.length);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('levels: ${_count ?? '…'}')),
      );
}

void main() {
  testWidgets('Reset restores the dataset the visitor started from', (
    tester,
  ) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final canonical = root.read(demoSessionControllerProvider).fixture;
    expect(find.textContaining('levels: '), findsOneWidget);
    final before = (tester.widget<Text>(find.textContaining('levels: ')).data)!;

    // A visitor changes something.
    await canonical.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DemoControls.resetKey));
    await tester.pumpAndSettle();

    expect(root.read(demoSessionControllerProvider).generation, 1);
    expect(
      tester.widget<Text>(find.textContaining('levels: ')).data,
      before,
      reason: 'the rebuilt scope handed the screen a fresh fixture',
    );
  });

  testWidgets('View as switches the identity and rebuilds the subtree', (
    tester,
  ) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The owner'), findsOneWidget);

    // One tap per persona: owner → member, the ring the bar cycles.
    await tester.tap(find.byKey(DemoControls.viewAsKey));
    await tester.pumpAndSettle();

    final session = root.read(demoSessionControllerProvider);
    expect(session.persona, DemoPersona.member);
    expect(session.fixture.auth.currentUserId, DemoPersona.member.userId);
    expect(
      session.generation,
      0,
      reason: 'a viewpoint changed, not the dataset',
    );
    expect(find.text('A member'), findsOneWidget);
  });

  testWidgets('the bar says what this space is, for a screen reader too', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(
        child: DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: SizedBox())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('demonstration space')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
