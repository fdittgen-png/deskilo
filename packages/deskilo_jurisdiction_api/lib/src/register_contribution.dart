// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';
import 'generated_artifact.dart';

/// A party of an issued document, as the registers read it: neutral data, no
/// application type.
class RegisterParty {
  const RegisterParty({
    this.name = '',
    this.company = '',
    this.country = '',
    this.vatId = '',
    this.legalId = '',
    this.postalCode = '',
  });

  final String name;
  final String company;
  final String country;
  final String vatId;
  final String legalId;
  final String postalCode;
}

/// One rate of an issued document: its category, the rate and the amounts in
/// minor units.
class RegisterVatLine {
  const RegisterVatLine({
    required this.percent,
    required this.category,
    required this.grossCents,
    required this.netCents,
    required this.vatCents,
  });

  final double percent;
  final String category;
  final int grossCents;
  final int netCents;
  final int vatCents;
}

/// An issued document, as the registers read it. [voided] documents stay in
/// the list so the add-on decides what a register leaves out.
class RegisterDocument {
  RegisterDocument({
    required this.number,
    required this.issuedAt,
    required this.currency,
    required this.totalCents,
    required List<RegisterVatLine> vatTotals,
    this.title = '',
    this.memberName = '',
    this.replacesNumber = '',
    this.correctionReason = '',
    this.voided = false,
    this.buyerParty,
  }) : vatTotals = List.unmodifiable(vatTotals);

  final String number;
  final DateTime issuedAt;
  final String currency;
  final int totalCents;
  final List<RegisterVatLine> vatTotals;
  final String title;
  final String memberName;
  final String replacesNumber;
  final String correctionReason;
  final bool voided;
  final RegisterParty? buyerParty;

  /// A negative total is a credit note.
  bool get isCreditNote => totalCents < 0;

  /// The tax the document contains.
  int get vatCents => vatTotals.fold(0, (sum, t) => sum + t.vatCents);
}

/// The line a register's threshold row draws (`threshold` domain of the tax
/// reference), read by the host: the amount is data, never a literal here.
class RegisterThreshold {
  const RegisterThreshold({required this.cents, required this.currency});

  final int cents;
  final String currency;
}

/// What the host gives a register: the issued documents, who keeps the
/// register, the period `[from, to)` and the facts the host holds.
class RegisterContext {
  RegisterContext({
    required List<RegisterDocument> documents,
    required this.from,
    required this.to,
    this.sellerVatId = '',
    this.sellerName = '',
    this.activity = '',
    this.monthly = false,
    this.immediateSupply = false,
    this.threshold,
    Set<String> euMemberStates = const {},
    Map<String, String> euCodeAliases = const {},
  }) : documents = List.unmodifiable(documents),
       euMemberStates = Set.unmodifiable(euMemberStates),
       euCodeAliases = Map.unmodifiable(euCodeAliases);

  final List<RegisterDocument> documents;

  /// The period the register covers: `from` included, `to` excluded.
  final DateTime from;
  final DateTime to;

  /// Who keeps the register: the space's tax id and name.
  final String sellerVatId;
  final String sellerName;

  /// The activity code of the register's lines, when the country asks one.
  final String activity;

  /// Whether the space files monthly rather than quarterly.
  final bool monthly;

  /// Whether the space keeps its VAT books through the immediate-supply
  /// system, which exonerates it from some lists.
  final bool immediateSupply;

  /// The row `RegisterContribution.thresholdKey` names, in force on the last
  /// day of the period; null when the kind has no threshold or the reference
  /// holds no row.
  final RegisterThreshold? threshold;

  /// The member states of the EU and the alias codes (`EL` -> `GR`).
  final Set<String> euMemberStates;
  final Map<String, String> euCodeAliases;

  /// Whether [code] (trimmed, upper-cased, an alias resolved) is a member.
  bool isEu(String code) {
    final c = code.trim().toUpperCase();
    return euMemberStates.contains(euCodeAliases[c] ?? c);
  }
}

/// Why a register cannot be written.
enum RegisterProblem {
  /// The keeper's tax id is not one the register's channel accepts.
  vatNumber,

  /// A document holds an amount the register has no field for.
  unmappedAmount,

  /// The space keeps its books through the immediate-supply system and files
  /// no such list.
  exoneratedByImmediateSupply,
}

class RegisterRefusal implements Exception {
  const RegisterRefusal(this.problem);

  final RegisterProblem problem;

  @override
  String toString() => 'RegisterRefusal: ${problem.name}';
}

/// What a country's law asks as registers of issued invoices beside the
/// return. The country is the one in the capability id (`registers.ES`); the
/// kinds are the ids the host's register kind carries (`VatFilingContribution.
/// registers` lists the same ids for the declarations screen).
abstract class RegisterContribution {
  const RegisterContribution();

  CapabilityDescriptor get descriptor;

  /// The ids of the registers this add-on writes.
  Set<String> get kinds;

  /// The key of the `threshold` row a [kind] reads, or null when it has none.
  String? thresholdKey(String kind) => null;

  /// Whether [raw] has the shape of the activity code the register's lines ask
  /// ([RegisterContext.activity]); the host validates what a person types
  /// before it writes. Accepts anything by default.
  bool acceptsActivity(String raw) => true;

  /// The file of [kind] for [context], or null when the period holds nothing
  /// to write. Throws [RegisterRefusal] when it cannot be written.
  GeneratedArtifact? generate(String kind, RegisterContext context);
}
