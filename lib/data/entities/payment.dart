class Payment {
  final int? id;
  final String receiptId;
  final String fromParticipantId;
  final String toParticipantId;
  final int amountCents;
  final DateTime paidAt;
  final String? note;

  const Payment({
    this.id,
    required this.receiptId,
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amountCents,
    required this.paidAt,
    this.note,
  });
}
