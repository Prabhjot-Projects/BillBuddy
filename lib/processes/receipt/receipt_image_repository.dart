import 'package:billbuddy/core/utils/result.dart';

abstract class ReceiptImageRepository {
  Future<Result<void>> savePages({
    required String receiptId,
    required List<String> imagePaths,
  });

  Future<Result<List<String>>> getPages(String receiptId);

  Future<Result<void>> deletePages(String receiptId);
}
