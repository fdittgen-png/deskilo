// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the Demo's customer quotes, through its own composition: the
// head lists a sent quote (EUR 144.00, one reference taken) and a draft that has
// no number and no amounts; sending the draft takes the next reference of the
// series and freezes its amounts; an amendment is another revision; another
// space starts with none.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/money/application/customer_quote_commands.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/providers/customer_quote_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: demoOverrides(DemoFixture.build()))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('the head lists a sent quote and a draft; sending the draft takes the '
      'next reference and freezes its amounts; an amendment is a revision',
      () async {
    final id = (await container.read(currentWorkspaceProvider.future))!.id;
    final quotes = await container.read(customerQuotesProvider(id).future);
    final sent = quotes.singleWhere((q) => q.status == QuoteStatus.sent);
    final draft = quotes.singleWhere((q) => q.status == QuoteStatus.draft);
    expect(sent.reference, 'QUO-0001');
    // 1.5 h at 80.00 net with the Demo seller's 20 % VAT
    expect(sent.current!.totals!.totalCents, 14400);
    expect(draft.reference, isNull);
    expect(draft.draft!.totals, isNull);

    final commands = container.read(customerQuoteCommandProvider);
    final sentNow = await commands.send(
      id,
      draft.id,
      revision: draft.draft!.revision,
      version: draft.draft!.draftVersion,
    );
    expect((sentNow as QuoteDone<QuoteSent>).value.reference, 'QUO-0002');
    final after = await container.read(customerQuoteRepositoryProvider).quote(id, draft.id);
    expect(after.current!.totals!.totalCents, 78000);

    final amended = await commands.amend(id, sent.id);
    expect((amended as QuoteDone<QuoteSaved>).value.revision, 2);
    final again = await container.read(customerQuoteRepositoryProvider).quote(id, sent.id);
    expect(again.revisions.length, 2);
    // the first revision is untouched and still frozen
    expect(again.revisions.first.totals!.totalCents, 14400);
  });

  test('another space starts with none: each space reads its own quotes',
      () async {
    await container.read(currentWorkspaceProvider.future);
    container.read(activeWorkspaceIdProvider.notifier).activate(demoSecondSpaceId);
    final other = await container.read(currentWorkspaceProvider.future);
    expect(other?.id, demoSecondSpaceId);
    expect(await container.read(customerQuotesProvider(other!.id).future), isEmpty);
  });
}
