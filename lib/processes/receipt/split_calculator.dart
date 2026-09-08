import 'package:billbuddy/data/entities/receipt.dart';

/// One participant's computed share of a split receipt.
class SplitShare {
  final String participantId;
  final double itemSubtotal;
  final double taxShare;

  const SplitShare({
    required this.participantId,
    required this.itemSubtotal,
    required this.taxShare,
  });

  double get total => itemSubtotal + taxShare;

  int get totalCents => (itemSubtotal * 100).round() + (taxShare * 100).round();
}

/// The full result of splitting a receipt: what each participant owes,
/// and (for convenience on the summary screen) which participant is the
/// payer, since the UI needs to show everyone else's amount as "owes
/// [payer]" rather than just a bare number.
class SplitResult {
  final String payerId;
  final List<SplitShare> shares;

  const SplitResult({required this.payerId, required this.shares});

  /// Every participant except the payer — this is the list the summary
  /// screen actually displays as "X owes the payer $Y", since the payer
  /// doesn't owe themselves anything.
  List<SplitShare> get owedToPayer =>
      shares.where((s) => s.participantId != payerId).toList();
}

/// Pure computation: given a receipt (with assigned items) and a map of
/// itemId -> participant ids sharing that item, computes what each
/// participant owes.
///
/// This lives in `processes/` with zero imports beyond the Receipt
/// entity itself — no database, no Firebase, nothing external — because
/// per ARCHITECTURE.md, code with zero external-technology dependency
/// that combines/judges our own data belongs here, not in `services/`.
/// Being pure like this also makes it trivially unit-testable: no
/// mocking a database or a network call is needed to verify the math.
class SplitCalculator {
  /// [assignments] maps receiptItemId -> list of participant ids sharing
  /// that item. An item missing from this map, or mapped to an empty
  /// list, is treated as unassigned and excluded from the split — the
  /// caller (the assignment screen) is responsible for blocking
  /// navigation to the summary screen until every item has at least one
  /// participant, so reaching this calculator with a gap is a bug
  /// upstream, not something this method should silently paper over by
  /// guessing an owner.
  static SplitResult calculate({
    required Receipt receipt,
    required Map<String, List<String>> assignments,
    required String payerId,
  }) {
    final itemSubtotalCents = <String, int>{};

    for (final item in receipt.items) {
      final participants = assignments[item.id];
      if (participants == null || participants.isEmpty) continue;

      final itemTotalCents = _toCents((item.price ?? 0) * (item.quantity ?? 1));
      final allocatedCents = _allocateCents(
        itemTotalCents,
        participants.length,
      );

      for (var index = 0; index < participants.length; index++) {
        itemSubtotalCents.update(
          participants[index],
          (existing) => existing + allocatedCents[index],
          ifAbsent: () => allocatedCents[index],
        );
      }
    }

    // Tax is split evenly across everyone who appears in ANY item
    // assignment — "everyone involved in the receipt," per the product
    // decision to keep tax splitting flat rather than proportional.
    final involvedParticipants = itemSubtotalCents.keys.toList();
    final taxCents = _toCents(receipt.tax ?? 0);
    final taxShares = _allocateCents(taxCents, involvedParticipants.length);

    final shares = involvedParticipants.asMap().entries.map((entry) {
      final index = entry.key;
      final participantId = entry.value;
      return SplitShare(
        participantId: participantId,
        itemSubtotal: itemSubtotalCents[participantId]! / 100,
        taxShare: taxShares[index] / 100,
      );
    }).toList();

    return SplitResult(payerId: payerId, shares: shares);
  }

  /// Converts a parsed decimal amount to cents once, before any division.
  /// [double.round] gives deterministic half-up cent rounding for values
  /// represented by the parser or edited by the user.
  static int _toCents(double amount) => (amount * 100).round();

  /// Splits cents deterministically. Earlier participants receive the
  /// remainder cents, ensuring the allocated amount always sums exactly.
  static List<int> _allocateCents(int totalCents, int recipientCount) {
    if (recipientCount == 0) return const [];

    final base = totalCents ~/ recipientCount;
    final remainder = totalCents % recipientCount;
    return List<int>.generate(
      recipientCount,
      (index) => base + (index < remainder ? 1 : 0),
    );
  }

  /// True only when every item on the receipt has at least one
  /// participant assigned. The assignment screen uses this to decide
  /// whether "View Split Summary" is enabled — reaching the summary
  /// screen with unassigned items would silently exclude those items'
  /// cost from everyone's total, which is a correctness bug, not a
  /// cosmetic one (someone would be underpaying without realizing it).
  static bool isFullyAssigned({
    required Receipt receipt,
    required Map<String, List<String>> assignments,
  }) {
    for (final item in receipt.items) {
      final participants = assignments[item.id];
      if (participants == null || participants.isEmpty) return false;
    }
    return true;
  }
}
