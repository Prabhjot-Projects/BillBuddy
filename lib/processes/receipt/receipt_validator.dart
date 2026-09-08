/// Validates raw OCR text before it's sent to the AI parser.
///
/// Why this matters: Gemini calls cost money and take time. If the OCR
/// text is garbage (a photo of a wall, a receipt with no numbers on it,
/// three characters of noise), we want to reject it here — cheaply and
/// instantly — rather than burn an API call finding out the AI also
/// couldn't make sense of it.
///
/// This is intentionally a cheap heuristic, not a guarantee of a valid
/// receipt. The AI parser is still the source of truth for structure;
/// this just filters out the obviously-not-a-receipt case.
class ReceiptValidator {
  static const int _minimumLength = 10;

  bool formatValidator(String extractedData) {
    final trimmed = extractedData.trim();

    if (trimmed.isEmpty) return false;

    // Too short to plausibly be a receipt (a real receipt has a merchant
    // name, at least one item line, and a total — that's rarely under
    // 10 characters even in the worst OCR case).
    if (trimmed.length < _minimumLength) return false;

    // A receipt should contain at least one digit somewhere (a price,
    // a date, a quantity). Pure alphabetic noise is not a receipt.
    final hasDigit = RegExp(r'[0-9]').hasMatch(trimmed);
    if (!hasDigit) return false;

    return true;
  }
}
