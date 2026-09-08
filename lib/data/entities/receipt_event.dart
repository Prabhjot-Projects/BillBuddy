class ReceiptEvent {
  final int? id;
  final String receiptId;
  final String eventType;
  final String summary;
  final DateTime createdAt;

  const ReceiptEvent({
    this.id,
    required this.receiptId,
    required this.eventType,
    required this.summary,
    required this.createdAt,
  });
}
