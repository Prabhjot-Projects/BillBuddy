import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/friend.dart';

/// Contract for persisting and retrieving friends. Abstract for the same
/// reason ReceiptRepository is: cloud sync is a stated future goal, and
/// friends are exactly the kind of data that will need to sync across a
/// user's devices, so a second (cloud) implementation is a concrete near
/// -term expectation, not a hypothetical.
abstract class FriendRepository {
  Future<Result<void>> add(Friend friend);
  Future<Result<List<Friend>>> getAll();
  Future<Result<void>> delete(String id);
}
