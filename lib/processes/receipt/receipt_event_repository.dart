import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';

abstract class ReceiptEventRepository {
  Future<Result<ReceiptEvent>> add(ReceiptEvent event);
  Future<Result<List<ReceiptEvent>>> getAll();
}
