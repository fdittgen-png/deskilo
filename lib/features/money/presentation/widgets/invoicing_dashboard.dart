// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/dunning.dart';
import '../../domain/ledger_entry.dart';
import '../../providers/money_providers.dart';
import '../period_label.dart';
import 'open_invoice_card.dart';
import 'open_invoice_subtitle.dart';
import 'wizard_context.dart';


part 'invoicing_dashboard_part2.dart';
part 'invoicing_dashboard_part3.dart';
part 'invoicing_dashboard_part4.dart';
