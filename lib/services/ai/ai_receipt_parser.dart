import 'dart:async';
import 'dart:convert';

import '../../core/utils/result.dart';
import '../../data/entities/receipt.dart';
import 'receipt_parser.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:uuid/uuid.dart';

class AiReceiptParser implements ReceiptParser {
  // Generates ids client-side (rather than waiting for a DB autoincrement)
  // so a Receipt is a fully-formed, identifiable object the moment it's
  // parsed — before it's ever saved. This matters for the review screen:
  // the user can edit and even discard a receipt without it ever touching
  // the database, but it still needs a stable id to key widgets and state
  // by. It also sets us up for cloud sync later, where client-generated
  // UUIDs avoid id collisions between devices (a server autoincrement
  // can't be assigned until the server has seen the record).
  static const _uuid = Uuid();
  // gemini-3-flash-preview is the current Gemini 3 Flash preview model
  // exposed through Firebase AI Logic. Preview models can be renamed or
  // deprecated by Google with little notice — if this starts throwing
  // "model not found", check the Firebase AI Logic docs for the current
  // name before assuming the bug is in our code.
  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3-flash-preview',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'merchantName': Schema.string(nullable: true),
          'date': Schema.string(nullable: true),
          'subtotal': Schema.number(nullable: true),
          'tax': Schema.number(nullable: true),
          'total': Schema.number(nullable: true),
          'items': Schema.array(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'quantity': Schema.number(nullable: true),
                'price': Schema.number(nullable: true),
              },
            ),
          ),
        },
      ),
    ),
  );

  static const _requestTimeout = Duration(seconds: 20);

  @override
  Future<Result<Receipt>> parse(String rawText) async {
    final prompt =
        '''
Extract structured receipt data from this raw OCR text.
If a field is missing or unclear, return null for it.
Raw text: $rawText
''';

    GenerateContentResponse response;
    try {
      response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.networkError,
          message: 'The AI took too long to respond. Please try again.',
          cause: e,
        ),
      );
    } catch (e) {
      // Covers network failures, quota errors, safety-filter blocks
      // (Gemini can refuse to respond and return no candidates), and
      // any other SDK-level exception.
      return Result.failure(
        AppFailure(
          type: FailureType.aiParsingFailed,
          message: 'Could not reach the AI service to read this receipt.',
          cause: e,
        ),
      );
    }

    final jsonString = response.text;
    if (jsonString == null || jsonString.trim().isEmpty) {
      return Result.failure(
        const AppFailure(
          type: FailureType.aiResponseMalformed,
          message: 'The AI did not return any data for this receipt.',
        ),
      );
    }

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.aiResponseMalformed,
          message: 'The AI returned data in an unexpected format.',
          cause: e,
        ),
      );
    }

    try {
      final receipt = _mapToReceipt(data);

      // A receipt with no usable line items isn't actionable for the
      // split-calculation flow — there's nothing to assign to anyone.
      // Fail here so the UI can prompt a retake with a clear reason,
      // rather than dropping the user onto an empty review screen.
      if (receipt.items.isEmpty) {
        return Result.failure(
          const AppFailure(
            type: FailureType.aiResponseMalformed,
            message:
                'No items could be read from this receipt. Try retaking '
                'the photo with better lighting or a flatter angle.',
          ),
        );
      }

      return Result.success(receipt);
    } catch (e) {
      // Defensive catch-all for field-level surprises (e.g. items isn't
      // actually a List, or an item is missing 'name') that responseSchema
      // is supposed to prevent but a model can still occasionally violate.
      return Result.failure(
        AppFailure(
          type: FailureType.aiResponseMalformed,
          message: 'The receipt data was incomplete or malformed.',
          cause: e,
        ),
      );
    }
  }

  Receipt _mapToReceipt(Map<String, dynamic> data) {
    final receiptId = _uuid.v4();
    final rawItems = data['items'];
    final items = <ReceiptItem>[];

    // items must exist and be a list for this to be a usable receipt —
    // a receipt with no line items isn't something the split logic
    // downstream can do anything useful with.
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['name'];
        if (name is! String || name.trim().isEmpty) {
          // Skip malformed individual items rather than failing the
          // whole receipt — a receipt with 8 good items and 1 bad OCR
          // line is still mostly useful to the user.
          continue;
        }
        items.add(
          ReceiptItem(
            id: _uuid.v4(),
            receiptId: receiptId,
            name: name,
            quantity: (item['quantity'] as num?)?.toDouble(),
            price: (item['price'] as num?)?.toDouble(),
          ),
        );
      }
    }

    return Receipt(
      id: receiptId,
      merchantName: data['merchantName'] as String?,
      date: (data['date'] is String)
          ? DateTime.tryParse(data['date'] as String)
          : null,
      subtotal: (data['subtotal'] as num?)?.toDouble(),
      tax: (data['tax'] as num?)?.toDouble(),
      total: (data['total'] as num?)?.toDouble(),
      items: items,
    );
  }
}
