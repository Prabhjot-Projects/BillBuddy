import '../../core/utils/result.dart';
import '../../data/entities/receipt.dart';

abstract class ReceiptParser {
  Future<Result<Receipt>> parse(String rawText);
}
