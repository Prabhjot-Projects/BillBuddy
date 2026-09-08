import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/receipt.dart';

/// Contract for persisting and retrieving receipts.
///
/// This lives in `processes/` even though its only current implementation
/// talks to SQLite (an external technology) — per ARCHITECTURE.md, the
/// *abstract contract* for a feature-specific concept belongs with the
/// feature (processes/receipt/), while the *concrete implementation*
/// that actually depends on the external tech lives in services/.
///
/// The concrete reason this needs to be an interface (not just a
/// concrete SqliteReceiptRepository used directly): cloud sync is an
/// explicit near-term goal per the project roadmap. When that ships,
/// there will realistically be a second implementation — either a
/// CloudReceiptRepository, or a decorator that wraps Sqlite +
/// Firebase together. Code that depends on ReceiptRepository today
/// won't need to change when that happens.
abstract class ReceiptRepository {
  /// Inserts a new receipt (and its items) as a draft.
  Future<Result<void>> saveDraft(Receipt receipt);

  /// Updates an existing receipt in place and marks it confirmed.
  /// This is what the review screen calls on "Save" — same id, new data.
  Future<Result<void>> confirm(Receipt receipt);

  /// Fetches a single receipt by id, including its items.
  Future<Result<Receipt?>> getById(String id);

  /// Fetches all confirmed receipts, most recent first.
  Future<Result<List<Receipt>>> getAllConfirmed();

  /// Fetches confirmed receipts scoped to a specific group's split
  /// history — used by group_detail_screen to show what's been split
  /// under that group, without the screen needing to filter
  /// getAllConfirmed() client-side.
  Future<Result<List<Receipt>>> getByGroupId(String groupId);

  /// Fetches all draft receipts — used for a "resume unfinished scans"
  /// feature and by the cleanup routine.
  Future<Result<List<Receipt>>> getAllDrafts();

  /// Deletes a receipt and its items (items cascade at the DB level).
  Future<Result<void>> delete(String id);

  /// Deletes draft receipts older than [olderThan]. Called once on app
  /// startup to enforce the 14-day draft TTL — abandoned scans that were
  /// never reviewed shouldn't accumulate forever.
  Future<Result<int>> deleteStaleDrafts(Duration olderThan);
}
