// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: the shared form holds a large lazy gallery, filters and its final action.
import 'package:deskilo/core/ui/wizard_scaffold.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large filter labels leave lazy results and the footer reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var finished = false;
    String? selected;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2), viewInsets: const EdgeInsets.only(bottom: 100)),
        child: child!),
      home: WizardScaffold(title: 'Create', scrollForm: true,
        formMaxWidth: double.infinity,
        steps: const [(name: 'templates', label: 'Templates')], index: 0,
        onFinish: () => finished = true,
        body: SizedBox(height: 360, child: TemplateGallery(
          sections: [TemplateGallerySection(title: 'Templates', templates: [
            for (var i = 0; i < 100; i++) WorkspaceTemplate(
              id: '$i', key: '$i', name: 'Template $i',
              tags: ['A long filter label $i']),
          ])], onSelected: (id) => selected = id,
        )),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(TemplateCard).evaluate().length, greaterThan(0));
    expect(find.byType(TemplateCard).evaluate().length, lessThan(100));
    final search = find.byKey(const ValueKey('template-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Template 50');
    await tester.pump(TemplateGallery.debounce);
    final tag = find.byKey(const ValueKey('template-tag-A long filter label 50'));
    await tester.ensureVisible(tag);
    await tester.tap(tag);
    await tester.pump();
    expect(tester.widget<FilterChip>(tag).selected, isTrue);
    expect(find.byType(TemplateCard), findsOneWidget);
    await tester.ensureVisible(find.descendant(of: find.byType(TemplateCard), matching: find.text('Template 50')));
    await tester.tap(find.descendant(of: find.byType(TemplateCard), matching: find.text('Template 50')));
    expect(selected, '50');
    final finish = find.byKey(const ValueKey('wizard-finish'));
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
