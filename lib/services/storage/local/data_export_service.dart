import 'dart:convert';
import 'dart:io';

import 'package:billbuddy/core/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class DataExportService {
  final DatabaseService _databaseService;

  DataExportService(this._databaseService);

  Future<Result<String>> exportJson() async {
    try {
      final database = _databaseService.instance;
      final data = <String, dynamic>{
        'formatVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'tables': <String, dynamic>{},
      };
      final tables = data['tables'] as Map<String, dynamic>;
      for (final table in const [
        'receipts',
        'receipt_items',
        'receipt_images',
        'item_assignments',
        'friends',
        'groups',
        'group_members',
        'payments',
        'receipt_events',
      ]) {
        tables[table] = await database.query(table);
      }

      final documents = await getApplicationDocumentsDirectory();
      final exportDirectory = Directory(p.join(documents.path, 'exports'));
      await exportDirectory.create(recursive: true);
      final file = File(
        p.join(
          exportDirectory.path,
          'billbuddy_export_${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      return Result.success(file.path);
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not export your BillBuddy data.',
          cause: error,
        ),
      );
    }
  }
}
