// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the basics step's preview: today's date, the time now and a
// sample amount, as a member reads them under the locale, currency and
// time zone on the form, through the app's own formatter. The member's own
// clock preference stays; only what the space decides changes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/currencies.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/time_zones.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';

/// The sample amount, in minor units: 1 234.50 in the space's currency.
const int _sampleMinor = 123450;

class SetupBasicsPreview extends ConsumerWidget {
  const SetupBasicsPreview({
    super.key,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.language,
  });

  final String countryCode;
  final String currencyCode;
  final String timezone;

  /// The workspace's language; '' falls back to the app's.
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider).now();
    final languageCode = language.isEmpty
        ? Localizations.localeOf(context).languageCode
        : language;
    final format = ref
        .watch(appFormatProvider)
        .copyWith(
          locale: defaultFormatLocale(languageCode, countryCode),
          currencyCode: Currencies.selectable.contains(currencyCode)
              ? currencyCode
              : null,
        );
    final known = TimeZones.isKnown(timezone);
    // The wall clock of the zone on the form, not of the installed one.
    final wall = known
        ? tz.TZDateTime.from(now, tz.getLocation(timezone))
        : now;
    final naive = DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    );
    final time = format.wallTime(naive);
    return Column(
      key: const ValueKey('setup-basics-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sample(
          id: 'date',
          label: l10n.setupBasicsPreviewDate,
          value: DateFormat.yMMMMEEEEd(format.locale).format(naive),
        ),
        _Sample(
          id: 'time',
          label: l10n.setupBasicsPreviewTime,
          value: known
              ? l10n.setupBasicsPreviewTimeIn(
                  time,
                  TimeZones.offsetLabel(timezone, now),
                )
              : time,
        ),
        _Sample(
          id: 'money',
          label: l10n.setupBasicsPreviewMoney,
          value: format.money(_sampleMinor),
        ),
      ],
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      value,
      key: ValueKey('setup-basics-preview-$id'),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}
