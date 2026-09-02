// SPDX-License-Identifier: 0BSD

// #828 — distributing ONE shared amount over the members: the key that
// weighs each member, and the split itself. Pure arithmetic; the booking
// of the resulting shares is the server's, through the validation
// framework.

/// How the amount is weighed between members.
enum RepartitionMethod {
  /// Everyone the same.
  equal,

  /// Pro rata of the subscription percentage.
  subscription,

  /// Pro rata of the days used over the period.
  usage,

  /// A key typed per member.
  custom;

  static RepartitionMethod fromWire(String? raw) =>
      RepartitionMethod.values.asNameMap()[raw ?? ''] ??
      RepartitionMethod.equal;
}

/// One member's weight going in, and their share coming out.
class RepartitionShare {
  const RepartitionShare({
    required this.memberId,
    required this.memberName,
    required this.weight,
    required this.amountCents,
  });

  final String memberId;
  final String memberName;
  final num weight;
  final int amountCents;

  Map<String, Object?> toJson() => {
        'member_id': memberId,
        'amount_cents': amountCents,
        'weight': weight,
      };
}

/// A member with the facts every method may weigh.
typedef RepartitionMember = ({
  String id,
  String name,
  int subscriptionPct,
  num usageDays,
  num customWeight,
});

/// The weight of [member] under [method]; zero leaves them out.
num repartitionWeight(RepartitionMember member, RepartitionMethod method) =>
    switch (method) {
      RepartitionMethod.equal => 1,
      RepartitionMethod.subscription => member.subscriptionPct,
      RepartitionMethod.usage => member.usageDays,
      RepartitionMethod.custom => member.customWeight,
    };

/// Splits [amountCents] over [members] by [method] so the shares add up
/// to the amount EXACTLY — the largest-remainder method: every member
/// gets the floor of their exact share, the cents left over go one each
/// to the largest fractional parts (ties by list order). A negative
/// amount (a reversal) splits the same way and comes back negative.
/// Members with a zero weight get no share and are left out.
List<RepartitionShare> distributeExpense({
  required int amountCents,
  required List<RepartitionMember> members,
  required RepartitionMethod method,
}) {
  final weighed = [
    for (final m in members)
      if (repartitionWeight(m, method) > 0)
        (member: m, weight: repartitionWeight(m, method)),
  ];
  if (weighed.isEmpty || amountCents == 0) return const [];
  final total = weighed.fold<num>(0, (s, w) => s + w.weight);
  final sign = amountCents < 0 ? -1 : 1;
  final abs = amountCents.abs();
  final exact = [for (final w in weighed) abs * w.weight / total];
  final floors = [for (final e in exact) e.floor()];
  var left = abs - floors.fold(0, (s, f) => s + f);
  final order = List.generate(weighed.length, (i) => i)
    ..sort((a, b) {
      final byFraction =
          (exact[b] - floors[b]).compareTo(exact[a] - floors[a]);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (final i in order) {
    if (left <= 0) break;
    floors[i]++;
    left--;
  }
  return [
    for (var i = 0; i < weighed.length; i++)
      RepartitionShare(
        memberId: weighed[i].member.id,
        memberName: weighed[i].member.name,
        weight: weighed[i].weight,
        amountCents: sign * floors[i],
      ),
  ];
}

/// A distribution as the server keeps it (0147): what was split, how,
/// onto which period, and where its decision stands.
class ExpenseRepartition {
  const ExpenseRepartition({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.method,
    required this.period,
    required this.shares,
    required this.status,
    required this.createdAt,
    this.appliedAt,
  });

  factory ExpenseRepartition.fromJson(Map<String, dynamic> json) =>
      ExpenseRepartition(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        method: RepartitionMethod.fromWire(json['method'] as String?),
        period: json['period'] as String? ?? '',
        shares: [
          for (final s in json['shares'] as List<dynamic>? ?? const [])
            RepartitionShare(
              memberId: (s as Map)['member_id'] as String,
              memberName: s['member_name'] as String? ?? '',
              weight: (s['weight'] as num?) ?? 0,
              amountCents: (s['amount_cents'] as num?)?.toInt() ?? 0,
            ),
        ],
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
        appliedAt: json['applied_at'] == null
            ? null
            : DateTime.parse(json['applied_at'] as String),
      );

  final String id;
  final String title;

  /// Negative = a reversal: the shares are credits, not charges.
  final int amountCents;
  final RepartitionMethod method;
  final String period;
  final List<RepartitionShare> shares;

  /// pending | confirmed | rejected | expired.
  final String status;
  final DateTime createdAt;
  final DateTime? appliedAt;

  bool get isReversal => amountCents < 0;
  bool get isPending => status == 'pending';
}
