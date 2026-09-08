import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/payment.dart';

abstract class PaymentRepository {
  Future<Result<Payment>> add(Payment payment);
  Future<Result<List<Payment>>> getForReceipt(String receiptId);
}
