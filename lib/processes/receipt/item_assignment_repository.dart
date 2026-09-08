import 'package:billbuddy/core/utils/result.dart';

/// Manages which participants (Friend.id or meParticipantId) share each
/// receipt item. Kept as its own repository rather than folded into
/// ReceiptRepository because assignments are a distinct read/write
/// pattern — queried and rewritten independently of the receipt's own
/// scalar fields (merchant, total, etc.) — and mixing them would make
/// ReceiptRepository responsible for two different granularities of
/// data.
abstract class ItemAssignmentRepository {
  /// Replaces the full set of participants assigned to [receiptItemId]
  /// with [participantIds]. Like the item-upsert pattern elsewhere,
  /// this deletes and re-inserts rather than diffing — an item has at
  /// most a handful of participants, so the cost is negligible.
  Future<Result<void>> setAssignments({
    required String receiptItemId,
    required List<String> participantIds,
  });

  /// Returns a map of receiptItemId -> list of participant ids, for
  /// every item on [receiptId] in one call — the assignment screen
  /// needs all of a receipt's assignments at once to render its item
  /// list, and fetching them one item at a time would be a needless
  /// N+1 query pattern for a screen that's read constantly.
  Future<Result<Map<String, List<String>>>> getAssignmentsForReceipt(
    String receiptId,
  );

  /// Returns the ids of every receipt [participantId] appears on —
  /// either because they're assigned to at least one item, or because
  /// they're the payer. Used by friend_detail_screen to show a
  /// participant's split history without the caller needing to know
  /// the join between item_assignments and receipts.
  Future<Result<List<String>>> getReceiptIdsForParticipant(
    String participantId,
  );
}
