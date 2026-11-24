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
import 'package:deskilo/core/failure/app_failure.dart';
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
    expect((sentNow as CommandDone<QuoteSent>).value.reference, 'QUO-0003');
    final after = await container.read(customerQuoteRepositoryProvider).quote(id, draft.id);
    expect(after.current!.totals!.totalCents, 78000);

    final amended = await commands.amend(id, sent.id);
    expect((amended as CommandDone<QuoteSaved>).value.revision, 2);
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

  test('the head\'s accepted quote is previewed and invoiced once; the same '
      'quote answers the same invoice whatever the request', () async {
    final id = (await container.read(currentWorkspaceProvider.future))!.id;
    final quotes = await container.read(customerQuotesProvider(id).future);
    final accepted = quotes.singleWhere((q) => q.status == QuoteStatus.accepted);
    expect(accepted.decision!.accepted, isTrue);
    final commands = container.read(customerQuoteCommandProvider);
    final today = DateTime(2026, 11, 21);
    final prep = await commands.prepareConversion(
      id,
      accepted.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 14)),
    );
    final preview = (prep as CommandDone<QuoteConversionPrep>).value;
    expect(preview.issuable, isTrue);
    expect(preview.contextChanged, isFalse);
    expect(preview.wouldBeTotalCents, preview.acceptedTotalCents);
    final first = await commands.convert(
      id,
      accepted.id,
      draftRevision: preview.draftRevision,
      requestId: 'request-one',
    );
    final other = await commands.convert(
      id,
      accepted.id,
      draftRevision: preview.draftRevision,
      requestId: 'request-two',
    );
    expect((first as CommandDone<QuoteConverted>).value.replayed, isFalse);
    expect((other as CommandDone<QuoteConverted>).value.invoiceId, first.value.invoiceId);
    expect(other.value.replayed, isTrue);
    final after = await container.read(customerQuoteRepositoryProvider).quote(id, accepted.id);
    expect(after.status, QuoteStatus.converted);
    expect(after.invoiceId, first.value.invoiceId);
  });
}
